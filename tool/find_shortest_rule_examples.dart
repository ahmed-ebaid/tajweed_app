import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

Future<void> main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.quran.com/api/v4',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  final shortestByRule = <String, _ExampleHit>{};

  for (var surah = 1; surah <= 114; surah++) {
    final response = await dio.get(
      '/quran/verses/uthmani_tajweed',
      queryParameters: {'chapter_number': surah},
    );
    final verses = (response.data['verses'] as List<dynamic>? ?? const [])
        .cast<Map<dynamic, dynamic>>();

    for (final rawVerse in verses) {
      final verse = Map<String, dynamic>.from(rawVerse);
      final verseKey = (verse['verse_key'] as String? ?? '').trim();
      final html = (verse['text_uthmani_tajweed'] as String? ?? '').trim();
      if (verseKey.isEmpty || html.isEmpty) continue;

      final parts = verseKey.split(':');
      if (parts.length != 2) continue;
      final surahNumber = int.tryParse(parts[0]);
      final ayahNumber = int.tryParse(parts[1]);
      if (surahNumber == null || ayahNumber == null) continue;

      final rules = _extractRules(html);
      if (rules.isEmpty) continue;

      final arabic = _stripMarkup(html);
      final score = _scoreAyah(arabic);
      final wordCount = _wordCount(arabic);

      for (final rule in rules) {
        final current = shortestByRule[rule];
        if (current == null || score < current.score) {
          shortestByRule[rule] = _ExampleHit(
            surah: surahNumber,
            ayah: ayahNumber,
            score: score,
            wordCount: wordCount,
            arabic: arabic,
          );
        }
      }
    }
  }

  for (final rule in _ruleOrder) {
    final hit = shortestByRule[rule];
    final currentCode = _currentCodes[rule] ?? 'none';
    if (hit == null) {
      print('$rule: no match found (current $currentCode)');
      continue;
    }

    final newCode =
        '${hit.surah.toString().padLeft(3, '0')}${hit.ayah.toString().padLeft(3, '0')}';
    print(
      '$rule: $newCode words=${hit.wordCount} score=${hit.score} current=$currentCode text=${jsonEncode(hit.arabic)}',
    );
  }
}

const Map<String, String> _currentCodes = {
  'ghunnah': '002006',
  'qalqalah': '019061',
  'maddTabeei': '001002',
  'maddMuttasil': '110001',
  'maddMunfasil': '002004',
  'maddLazimKalimiMuthaqqal': '001007',
  'maddLazimKalimiMukhaffaf': '010051',
  'maddLazimHarfiMuthaqqal': '002001',
  'maddLazimHarfiMukhaffaf': '036001',
  'idghamWithGhunnah': '002008',
  'idghamWithoutGhunnah': '002005',
  'idghamShafawi': '002010',
  'idghamMutajanisayn': '011042',
  'ikhfa': '002010',
  'ikhfaShafawi': '105004',
  'iqlab': '002033',
  'izhar': '004011',
  'shaddah': '001001',
  'waqf': '002002',
  'sajdah': '007206',
  'hamzatWasl': '001001',
  'laamShamsiyah': '001003',
  'silent': '002002',
};

const List<String> _ruleOrder = [
  'ghunnah',
  'qalqalah',
  'maddTabeei',
  'maddMuttasil',
  'maddMunfasil',
  'idghamWithGhunnah',
  'idghamWithoutGhunnah',
  'ikhfa',
  'iqlab',
  'izhar',
  'shaddah',
  'waqf',
  'sajdah',
  'maddLazimKalimiMuthaqqal',
  'maddLazimKalimiMukhaffaf',
  'maddLazimHarfiMuthaqqal',
  'maddLazimHarfiMukhaffaf',
  'idghamShafawi',
  'idghamMutajanisayn',
  'ikhfaShafawi',
  'hamzatWasl',
  'laamShamsiyah',
  'silent',
];

const Map<String, Set<String>> _classNamesByRule = {
  'ghunnah': {'ghunnah'},
  'qalqalah': {'qalqalah', 'qalaqah'},
  'maddTabeei': {'madd_normal', 'madda_normal', 'madda_permissible'},
  'maddMuttasil': {
    'madd_muttasil',
    'madd_mottasel',
    'madda_obligatory',
    'madda_obligatory_mottasel',
    'madda_obligatory_muttasil',
    'madda_obligatory_muttasel',
  },
  'maddMunfasil': {
    'madda_obligatory_monfasel',
    'madda_obligatory_monfasil',
    'madd_munfasil',
  },
  'idghamWithGhunnah': {'idgham_ghunnah', 'idghaam_w_ghunnah'},
  'idghamWithoutGhunnah': {
    'idgham_no_ghunnah',
    'idgham_wo_ghunnah',
    'idghaam_wo_ghunnah',
  },
  'ikhfa': {'ikhfa', 'ikhafa'},
  'iqlab': {'iqlab'},
  'izhar': {'izhar', 'idhaar'},
  'shaddah': {'shaddah'},
  'waqf': {'waqf'},
  'sajdah': {'sajdah', 'sajdah_sign'},
  'maddLazimKalimiMuthaqqal': {'madda_necessary'},
  'maddLazimKalimiMukhaffaf': {'madda_necessary'},
  'maddLazimHarfiMuthaqqal': {'madda_necessary'},
  'maddLazimHarfiMukhaffaf': {'madda_necessary'},
  'idghamShafawi': {'idgham_shafawi'},
  'idghamMutajanisayn': {'idgham_mutajanisayn'},
  'ikhfaShafawi': {'ikhfa_shafawi', 'ikhafa_shafawi'},
  'hamzatWasl': {'ham_wasl'},
  'laamShamsiyah': {'laam_shamsiyah'},
  'silent': {'slnt'},
};

Set<String> _extractRules(String html) {
  final rules = <String>{};
  final matches = RegExp(r'<(?:rule|tajweed)\s+class="?([\w-]+)"?>')
      .allMatches(html);

  for (final match in matches) {
    final className = (match.group(1) ?? '').trim();
    if (className.isEmpty) continue;

    for (final entry in _classNamesByRule.entries) {
      if (entry.value.contains(className)) {
        rules.add(entry.key);
      }
    }
  }

  if (html.contains('\u06E9')) {
    rules.add('sajdah');
  }

  return rules;
}

String _stripMarkup(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _wordCount(String arabic) {
  if (arabic.isEmpty) return 0;
  return arabic.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
}

int _scoreAyah(String arabic) {
  final normalized = arabic.replaceAll(RegExp(r'\s+'), ' ').trim();
  return _wordCount(normalized) * 1000 + normalized.runes.length;
}

class _ExampleHit {
  final int surah;
  final int ayah;
  final int score;
  final int wordCount;
  final String arabic;

  const _ExampleHit({
    required this.surah,
    required this.ayah,
    required this.score,
    required this.wordCount,
    required this.arabic,
  });
}