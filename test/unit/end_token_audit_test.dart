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

bool _isShiftedEndTokenCase(Map<String, dynamic> verse) {
  final words = verse['words'];
  if (words is! List) return false;

  Map<String, dynamic>? endToken;
  for (final token in words) {
    if (token is! Map) continue;
    final map = _asStringDynamicMap(token);
    if ((map['char_type_name'] as String?) == 'end') {
      endToken = map;
    }
  }
  if (endToken == null) return false;

  final endText =
      (endToken['text'] as String? ?? endToken['text_uthmani'] as String? ?? '')
          .trim();
  final endTajweed = (endToken['text_uthmani_tajweed'] as String? ?? '').trim();
  return endText.isNotEmpty && endTajweed.isNotEmpty && endText != endTajweed;
}

void main() {
  test('audits all ayahs for shifted end-token tajweed anomalies', () {
    final jsonPath = Platform.environment['QURAN_WORDS_JSON_PATH'];
    if (jsonPath == null || jsonPath.isEmpty) {
      print(
        'Skipping audit: set QURAN_WORDS_JSON_PATH to a full 6236-ayah words dump JSON.',
      );
      return;
    }

    final verses = _loadVersesFromJson(jsonPath);
    expect(verses.length, 6236,
        reason: 'Audit input should contain all 6236 ayahs.');

    final flagged = <String>[];
    for (final verse in verses) {
      if (!_isShiftedEndTokenCase(verse)) continue;
      final verseKey = verse['verse_key']?.toString() ?? 'unknown';
      flagged.add(verseKey);
    }

    flagged.sort((a, b) {
      final ap = a.split(':');
      final bp = b.split(':');
      final as = int.tryParse(ap.first) ?? 0;
      final bs = int.tryParse(bp.first) ?? 0;
      if (as != bs) return as.compareTo(bs);
      final aa = ap.length > 1 ? int.tryParse(ap[1]) ?? 0 : 0;
      final ba = bp.length > 1 ? int.tryParse(bp[1]) ?? 0 : 0;
      return aa.compareTo(ba);
    });

    print('Shifted end-token ayahs count: ${flagged.length}');
    for (final key in flagged) {
      print('SHIFTED_END_TOKEN $key');
    }
  });

  test('optional cpfair tuple cross-check for provided ayahs', () {
    final wordsPath = Platform.environment['QURAN_WORDS_JSON_PATH'];
    final spansPath = Platform.environment['CPFAIR_SPANS_JSON_PATH'];
    if (wordsPath == null ||
        wordsPath.isEmpty ||
        spansPath == null ||
        spansPath.isEmpty) {
      print(
        'Skipping cpfair check: set QURAN_WORDS_JSON_PATH and CPFAIR_SPANS_JSON_PATH.',
      );
      return;
    }

    final verses = _loadVersesFromJson(wordsPath);
    final spansFile = File(spansPath);
    if (!spansFile.existsSync()) {
      throw StateError('CPFAIR_SPANS_JSON_PATH not found: $spansPath');
    }

    final expectedByVerse = Map<String, dynamic>.from(
      jsonDecode(spansFile.readAsStringSync()) as Map,
    );

    final versesByKey = <String, Map<String, dynamic>>{};
    for (final verse in verses) {
      final key = verse['verse_key']?.toString() ?? '';
      if (key.isEmpty) continue;
      versesByKey[key] = verse;
    }

    for (final entry in expectedByVerse.entries) {
      final verseKey = entry.key;
      final verse = versesByKey[verseKey];
      if (verse == null) continue;

      final ayah = AyahMapper.fromApi(verse);
      final expectedWords = entry.value;
      if (expectedWords is! List) continue;

      expect(ayah.words.length, expectedWords.length,
          reason:
              'Word count mismatch for $verseKey against cpfair spans map.');

      for (int wi = 0;
          wi < ayah.words.length && wi < expectedWords.length;
          wi++) {
        final expected = expectedWords[wi];
        if (expected is! Map) continue;

        final expectedSpans = expected['spans'];
        if (expectedSpans is List) {
          final actual = ayah.words[wi].spans
              .map((s) => '${s.start}:${s.end}:${s.rule.name}')
              .toList();
          final wanted = expectedSpans.whereType<Map>().map((s) {
            final start = s['start'];
            final end = s['end'];
            final rule = s['rule'];
            return '$start:$end:$rule';
          }).toList();
          expect(
            actual,
            wanted,
            reason: 'Span mismatch for $verseKey word ${wi + 1}.',
          );
          continue;
        }

        final expectedSpanCount = (expected['span_count'] as int?) ?? 0;
        expect(ayah.words[wi].spans.length, expectedSpanCount,
            reason: 'Span count mismatch for $verseKey word ${wi + 1}.');
      }
    }
  });
}
