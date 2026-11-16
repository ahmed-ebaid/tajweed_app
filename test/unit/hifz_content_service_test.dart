import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/l10n/memorization_localizations.dart';
import 'package:tajweed_practice/core/services/hifz_content_service.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';
import 'package:tajweed_practice/core/services/quran_offline_sync_service.dart';
import 'package:tajweed_practice/core/services/speech_comparison_service.dart';

Map<String, dynamic> _verse(int surah, int ayah, {bool lines = true}) => {
  'verse_key': '$surah:$ayah',
  'page_number': 604,
  'text_uthmani': 'قل هو الله أحد',
  'text_imlaei': 'قل هو الله أحد',
  'juz_number': 30,
  'hizb_number': 60,
  'words': [
    for (final text in ['قل', 'هو', 'الله', 'أحد'])
      {
        'char_type_name': 'word',
        'text_uthmani': text,
        if (lines) 'line_number': ayah,
      },
    if (lines) {'char_type_name': 'end', 'line_number': ayah},
  ],
};

class _Cache extends QuranOfflineSyncService {
  List<Map<String, dynamic>> page = [];
  List<Map<String, dynamic>> surah = [];

  @override
  Future<List<Map<String, dynamic>>> getCachedVersesForPage(
    int pageNumber,
  ) async => page;

  @override
  Future<List<Map<String, dynamic>>?> getCachedSurah(int surahNumber) async =>
      surah;
}

class _Api extends QuranApiService {
  List<Map<String, dynamic>> chapters = [];
  List<Map<String, dynamic>> page = [];
  List<Map<String, dynamic>> surah = [];
  int pageCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchSurahList({
    String langCode = 'en',
  }) async => chapters;

  @override
  Future<List<Map<String, dynamic>>> fetchVersesByPage({
    required int pageNumber,
    required String langCode,
  }) async {
    pageCalls++;
    return page;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchVerses({
    required int surahNumber,
    required String langCode,
    int reciterId = 1,
    int? page,
  }) async => surah;
}

void main() {
  test('limited sandbox chapters are debug-only and never cached', () async {
    final settings = await Hive.openBox('settings', bytes: Uint8List(0));
    try {
      final api = _Api()
        ..chapters = [
          {'id': 1, 'verses_count': 7},
          {'id': 2, 'verses_count': 286},
        ];
      final service = HifzContentService(api: api, offline: _Cache());
      if (HifzContentService.prelivePreviewEnabled) {
        expect(await service.chapters(), api.chapters);
        expect(settings.get('reader_surah_list_ar'), isNull);
        api.chapters = [
          {'id': 1, 'verses_count': 7},
          {'id': 1, 'verses_count': 7},
        ];
        await expectLater(service.chapters(), throwsStateError);
        api.chapters = [];
        await expectLater(service.chapters(), throwsStateError);
      } else {
        await expectLater(service.chapters(), throwsStateError);
      }
    } finally {
      await settings.close();
    }
  });

  test('all eight languages contain every Hifz label', () {
    final keys = hifzTranslations['en']!.keys.toSet();
    expect(hifzTranslations.keys.toSet(), {
      'en',
      'ar',
      'ur',
      'tr',
      'fr',
      'id',
      'de',
      'es',
    });
    for (final translations in hifzTranslations.values) {
      expect(translations.keys.toSet(), keys);
      expect(
        translations.values.every((text) => text.trim().isNotEmpty),
        isTrue,
      );
    }
  });
  final chapters = [
    {'id': 112, 'verses_count': 4},
    {'id': 113, 'verses_count': 5},
    {'id': 114, 'verses_count': 6},
  ];
  List<Map<String, dynamic>> completePage() => [
    for (final chapter in chapters)
      for (var ayah = 1; ayah <= chapter['verses_count']!; ayah++)
        _verse(chapter['id']!, ayah),
  ];

  test(
    'shared page includes all three surahs, line ends, Juz and Hizb',
    () async {
      final cache = _Cache()..page = completePage();
      final api = _Api();
      final service = HifzContentService(
        api: api,
        offline: cache,
        isOffline: () async => true,
      );
      final page = await service.loadPage(604, chapters);
      expect(page.length, 15);
      expect(page.map((ayah) => ayah.surahNumber).toSet(), {112, 113, 114});
      expect(page.every((ayah) => ayah.endLineNumber != null), isTrue);
      expect(
        page.every(
          (ayah) => ayah.words.every((word) => word.lineNumber != null),
        ),
        isTrue,
      );
      expect(
        page.every((ayah) => ayah.juzNumber == 30 && ayah.hizbNumber == 60),
        isTrue,
      );
      expect(api.pageCalls, 0);
    },
  );

  test(
    'offline rejects neighboring-surah omissions, duplicates and missing lines',
    () async {
      for (final invalid in [
        completePage()
            .where((verse) => (verse['verse_key'] as String).startsWith('112:'))
            .toList(),
        [for (var i = 0; i < 15; i++) _verse(112, 1)],
        [
          for (final verse in completePage()) {...verse, 'words': []},
        ],
      ]) {
        final service = HifzContentService(
          api: _Api(),
          offline: _Cache()..page = invalid,
          isOffline: () async => true,
        );
        await expectLater(service.loadPage(604, chapters), throwsStateError);
      }
    },
  );

  test(
    'online replaces incomplete page, never silently renders a fragment',
    () async {
      final api = _Api()..page = completePage();
      final service = HifzContentService(
        api: api,
        offline: _Cache()..page = [_verse(112, 1)],
        isOffline: () async => false,
      );
      expect((await service.loadPage(604, chapters)).length, 15);
      expect(api.pageCalls, 1);
      api.page = [_verse(112, 1)];
      await expectLater(service.loadPage(604, chapters), throwsStateError);
    },
  );

  test(
    'surah loader rejects partial offline and accepts full refreshed text',
    () async {
      final cache = _Cache()..surah = [_verse(112, 1)];
      final api = _Api()
        ..surah = [for (var ayah = 1; ayah <= 4; ayah++) _verse(112, ayah)];
      await expectLater(
        HifzContentService(
          api: api,
          offline: cache,
          isOffline: () async => true,
        ).loadSurah(surahNumber: 112, expectedCount: 4, reciterId: 1),
        throwsStateError,
      );
      final surah = await HifzContentService(
        api: api,
        offline: cache,
        isOffline: () async => false,
      ).loadSurah(surahNumber: 112, expectedCount: 4, reciterId: 1);
      expect(surah.map((ayah) => ayah.ayahNumber), [1, 2, 3, 4]);
    },
  );

  final comparison = SpeechComparisonService();
  const verses = ['قل هو الله أحد', 'الله الصمد', 'لم يلد ولم يولد'];
  test(
    'continuous final text confirms consecutive ayahs, keeping partial tail',
    () {
      final check = comparison.checkSequence(
        expectedAyahs: verses,
        spokenText: '${verses[0]} ${verses[1]} لم يلد',
      );
      expect(check.completedAyahs, 2);
      expect(check.remainingText, 'لم يلد');
      expect(check.mismatch, isFalse);
      final resumed = comparison.checkSequence(
        expectedAyahs: [verses[2]],
        spokenText: '${check.remainingText} ولم يولد',
      );
      expect(resumed.completedAyahs, 1);
    },
  );

  test('wrong, skipped, reordered and extra words never finish the surah', () {
    for (final text in [
      'قل هو الله الصمد',
      '${verses[0]} ${verses[2]}',
      '${verses[1]} ${verses[0]}',
      '${verses.join(' ')} زيادة',
    ]) {
      final check = comparison.checkSequence(
        expectedAyahs: verses,
        spokenText: text,
      );
      expect(check.completedAyahs, lessThan(3));
      expect(check.mismatch, isTrue);
    }
    expect(
      comparison
          .checkSequence(expectedAyahs: [''], spokenText: '')
          .completedAyahs,
      0,
    );
    expect(
      comparison
          .checkSequence(expectedAyahs: verses, spokenText: '')
          .completedAyahs,
      0,
    );
  });
}
