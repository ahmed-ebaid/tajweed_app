import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

Map<String, dynamic> _asStringDynamicMap(dynamic input) {
  return Map<String, dynamic>.from(input as Map);
}

List<Map<String, dynamic>> _loadVersesFromJson(String jsonPath) {
  final file = File(jsonPath);
  if (!file.existsSync()) {
    throw StateError('Quran words JSON not found: $jsonPath');
  }

  final root = jsonDecode(file.readAsStringSync());
  final verses = <Map<String, dynamic>>[];

  if (root is List) {
    for (final item in root) {
      if (item is Map) verses.add(_asStringDynamicMap(item));
    }
    return verses;
  }

  if (root is Map) {
    final dynamicVerses = root['verses'];
    if (dynamicVerses is List) {
      for (final item in dynamicVerses) {
        if (item is Map) verses.add(_asStringDynamicMap(item));
      }
      return verses;
    }

    // Supports per-surah dump shape: { "1": [ ...verses ], "2": [ ... ] }
    for (final entry in root.entries) {
      final value = entry.value;
      if (value is! List) continue;
      for (final item in value) {
        if (item is Map) verses.add(_asStringDynamicMap(item));
      }
    }
  }

  return verses;
}

/// A run must start with something that occupies horizontal space. Nonspacing
/// marks and zero-width format characters give the shaper no advance, so what
/// follows lands on top of the preceding letter.
/// A *body* run must start with something that occupies space. Nonspacing
/// combining marks and zero-width format characters give the shaper no advance,
/// so a body run opening with one has been torn out of its grapheme cluster.
///
/// Marker runs are exempt and checked separately by
/// [_waqfMarkerRunIsIsolatedSign]: a waqf sign is *meant* to be a bare
/// nonspacing mark, because it is positioned by the font relative to the
/// preceding letter and Skia keeps it in that letter's shaping run.
bool _bodyRunLacksVisibleBase(String text) {
  if (text.isEmpty) return false;
  final cp = text.codeUnitAt(0);
  if (cp == 0x200B || (cp >= 0x200C && cp <= 0x200F) || cp == 0xFEFF) {
    return true;
  }
  return (cp >= 0x0610 && cp <= 0x061A) ||
      (cp >= 0x064B && cp <= 0x065F) ||
      (cp >= 0x06D6 && cp <= 0x06DC) ||
      (cp >= 0x06DF && cp <= 0x06E8) ||
      (cp >= 0x06EA && cp <= 0x06ED);
}

const Set<int> _waqfRunes = {
  0x06D6,
  0x06D7,
  0x06D8,
  0x06D9,
  0x06DA,
  0x06DB,
  0x06DC,
};


/// Collects body runs that open without a visible base *and* are not the
/// harmless trailing-mark case.
///
/// 19 corpus words (e.g. 33:38 لَهُۖۥ, 2:245 وَيَبۡصُۜطُ) carry combining marks
/// *after* the waqf sign. Splitting the sign out leaves those marks opening a
/// body run. `test/unit/waqf_render_geometry_test.dart` renders those words with and
/// without the split and finds no glyph moves — the runs share a typeface, so
/// Skia keeps them in one shaping run and the marks still attach. A body run
/// that opens with a mark right after a waqf marker run is therefore expected.
List<String> _strandedBodyRuns(
  List<({String text, TajweedRule? markerRule, bool isMarker})> runs,
) {
  final offenders = <String>[];
  var afterWaqfMarker = false;
  for (final run in runs) {
    final isWaqfMarker = run.isMarker && run.markerRule == TajweedRule.waqf;
    if (!run.isMarker && !afterWaqfMarker && _bodyRunLacksVisibleBase(run.text)) {
      offenders.add(run.text);
    }
    afterWaqfMarker = isWaqfMarker;
  }
  return offenders;
}

/// A waqf marker run must be exactly the sign — no separator carried along.
///
/// A leading space would give the nonspacing mark its own base and push the
/// sign clear of the word instead of stacking it over the harakah.
bool _waqfMarkerRunIsIsolatedSign(String text) =>
    text.length == 1 && _waqfRunes.contains(text.codeUnitAt(0));

class _Drop {
  final String verseKey;
  final String word;
  final String ruleClass;

  const _Drop(this.verseKey, this.word, this.ruleClass);
}

void main() {
  // Guards against tajweed rules being silently discarded during parsing.
  //
  // `_parseRuleTagTajweed` locates each `<rule>` tag's text inside the word's
  // normalized display string. When that search fails the rule is skipped and
  // the letters render uncoloured with no error — exactly how the missing madd
  // munfasil on إِنَّآ (18:29) went unnoticed. Nothing but a full-corpus sweep
  // catches the next instance, since the failure depends on the specific
  // combining marks surrounding a rule.
  test('no ayah drops an annotated tajweed rule', () {
    final jsonPath = Platform.environment['QURAN_WORDS_JSON_PATH'];
    if (jsonPath == null || jsonPath.isEmpty) {
      print(
        'Skipping audit: set QURAN_WORDS_JSON_PATH to a full 6236-ayah words '
        'dump JSON (generate with tool/fetch_quran_words_dump.dart).',
      );
      return;
    }

    final verses = _loadVersesFromJson(jsonPath);
    expect(
      verses.length,
      6236,
      reason: 'Audit input should contain all 6236 ayahs.',
    );

    final drops = <_Drop>[];
    for (final verse in verses) {
      final verseKey = verse['verse_key']?.toString() ?? 'unknown';
      final words = verse['words'];
      if (words is! List) continue;

      for (final token in words) {
        if (token is! Map) continue;
        final word = _asStringDynamicMap(token);
        if ((word['char_type_name'] as String?) != 'word') continue;

        for (final ruleClass in AyahMapper.unmatchedRuleClasses(word)) {
          drops.add(
            _Drop(
              verseKey,
              (word['text_uthmani'] as String? ?? '').trim(),
              ruleClass,
            ),
          );
        }
      }
    }

    if (drops.isEmpty) return;

    final byClass = <String, List<_Drop>>{};
    for (final drop in drops) {
      byClass.putIfAbsent(drop.ruleClass, () => []).add(drop);
    }

    final summary = StringBuffer()
      ..writeln('${drops.length} rule tag(s) dropped across the corpus:');
    final classes = byClass.keys.toList()..sort();
    for (final ruleClass in classes) {
      final entries = byClass[ruleClass]!;
      summary.writeln('  $ruleClass — ${entries.length} occurrence(s)');
      for (final entry in entries.take(5)) {
        summary.writeln('    ${entry.verseKey}  ${entry.word}');
      }
      if (entries.length > 5) {
        summary.writeln('    … ${entries.length - 5} more');
      }
    }

    fail(summary.toString());
  });

  // Guards against waqf signs losing their base glyph.
  //
  // Quran.com's tajweed HTML separates a waqf sign from the preceding word with
  // a zero-width non-joiner where `text_uthmani` uses a space. ZWNJ is
  // GCB=Extend, so letter + harakah + ZWNJ + waqf collapse into one grapheme
  // cluster; splitting the sign into its own styled run then leaves a nonspacing
  // mark with no advance width and it is painted over the letter's harakah.
  test('every waqf sign gets an isolated coloured run with an intact base', () {
    final jsonPath = Platform.environment['QURAN_WORDS_JSON_PATH'];
    if (jsonPath == null || jsonPath.isEmpty) {
      print(
        'Skipping audit: set QURAN_WORDS_JSON_PATH to a full 6236-ayah words '
        'dump JSON (generate with tool/fetch_quran_words_dump.dart).',
      );
      return;
    }

    final verses = _loadVersesFromJson(jsonPath);
    final offenders = <String>[];
    final unisolated = <String>[];
    var wordsWithWaqf = 0;
    var colouredWaqfRuns = 0;

    for (final verse in verses) {
      final verseKey = verse['verse_key']?.toString() ?? 'unknown';
      final ayah = AyahMapper.fromApi(verse);

      for (final word in ayah.words) {
        final waqfCount = word.arabic.runes
            .where((rune) => _waqfRunes.contains(rune))
            .length;
        if (waqfCount > 0) wordsWithWaqf++;

        final runs = TajweedText.splitIntoStyledRuns(word.arabic);
        var seenWaqfRuns = 0;
        for (final run in runs) {
          if (run.isMarker &&
              run.text.runes.any((rune) => _waqfRunes.contains(rune))) {
            seenWaqfRuns++;
            colouredWaqfRuns++;
            if (!_waqfMarkerRunIsIsolatedSign(run.text) &&
                unisolated.length < 10) {
              unisolated.add('$verseKey  ${word.arabic}  run="${run.text}"');
            }
          }
        }
        for (final stranded in _strandedBodyRuns(runs)) {
          if (offenders.length < 10) {
            offenders.add('$verseKey  ${word.arabic}  run="$stranded"');
          }
        }

        // Every waqf sign must reach the palette; none may be silently
        // absorbed into a body run and lose its colour.
        expect(
          seenWaqfRuns,
          waqfCount,
          reason: '$verseKey ${word.arabic}: waqf sign lost its marker run.',
        );
      }
    }

    expect(
      wordsWithWaqf,
      greaterThan(3000),
      reason: 'Audit input should exercise the waqf path broadly.',
    );
    expect(
      colouredWaqfRuns,
      greaterThan(3000),
      reason: 'Audit should observe waqf signs actually getting a marker run.',
    );
    expect(
      unisolated,
      isEmpty,
      reason:
          'A waqf marker run must contain only the sign. A carried separator '
          'gives the nonspacing mark its own base and pushes the sign clear '
          'of the word instead of stacking it above the harakah:\n'
          '${unisolated.join('\n')}',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'These body runs open with a nonspacing or zero-width character, so '
          'they have been torn out of their grapheme cluster and the mark is '
          'drawn over the preceding harakah:\n${offenders.join('\n')}',
    );
  });
}
