import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

const _baseUrl = 'https://api.quran.com/api/v4';

void _printUsage() {
  print('Usage:');
  print(
      '  dart run tool/fetch_quran_words_dump.dart --output <quran_words_full_6236.json>');
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    if (i + 1 >= args.length) {
      throw ArgumentError('Missing value for argument $arg');
    }
    map[arg] = args[i + 1];
    i++;
  }
  return map;
}

Future<List<Map<String, dynamic>>> _fetchSurahVerses(
  Dio dio,
  int surah,
) async {
  final all = <Map<String, dynamic>>[];
  var page = 1;

  while (true) {
    final response = await dio.get(
      '/verses/by_chapter/$surah',
      queryParameters: {
        'language': 'en',
        'words': true,
        'fields': 'verse_key,page_number,text_uthmani',
        'word_fields':
            'char_type_name,text,text_uthmani,text_uthmani_tajweed,tajweed',
        'per_page': 50,
        'page': page,
      },
    );

    final verses = (response.data['verses'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();

    if (verses.isEmpty) break;

    for (final verse in verses) {
      // Keep only fields needed for audit and future troubleshooting.
      final words = (verse['words'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((w) => {
                'char_type_name': w['char_type_name'],
                'text': w['text'],
                'text_uthmani': w['text_uthmani'],
                'text_uthmani_tajweed': w['text_uthmani_tajweed'],
                'tajweed': w['tajweed'],
              })
          .toList();

      all.add({
        'verse_key': verse['verse_key'],
        'page_number': verse['page_number'],
        'text_uthmani': verse['text_uthmani'],
        'words': words,
      });
    }

    if (verses.length < 50) break;
    page++;
  }

  return all;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(0);
  }

  final parsed = _parseArgs(args);
  final outputPath = parsed['--output'];
  if (outputPath == null || outputPath.isEmpty) {
    stderr.writeln('Error: --output is required.');
    _printUsage();
    exit(2);
  }

  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
  ));

  final allVerses = <Map<String, dynamic>>[];

  for (int surah = 1; surah <= 114; surah++) {
    final verses = await _fetchSurahVerses(dio, surah);
    allVerses.addAll(verses);
    print(
        'Fetched surah $surah: ${verses.length} ayahs (total ${allVerses.length})');
  }

  allVerses.sort((a, b) {
    final aKey = (a['verse_key'] as String? ?? '0:0').split(':');
    final bKey = (b['verse_key'] as String? ?? '0:0').split(':');
    final aSurah = int.tryParse(aKey.first) ?? 0;
    final bSurah = int.tryParse(bKey.first) ?? 0;
    if (aSurah != bSurah) return aSurah.compareTo(bSurah);
    final aAyah = aKey.length > 1 ? int.tryParse(aKey[1]) ?? 0 : 0;
    final bAyah = bKey.length > 1 ? int.tryParse(bKey[1]) ?? 0 : 0;
    return aAyah.compareTo(bAyah);
  });

  final outFile = File(outputPath);
  outFile.createSync(recursive: true);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({'verses': allVerses}),
  );

  print('Wrote ${allVerses.length} ayahs to ${outFile.path}');
  if (allVerses.length != 6236) {
    stderr.writeln('Warning: expected 6236 ayahs, got ${allVerses.length}.');
    exit(1);
  }
}
