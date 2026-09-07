import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';

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
}
