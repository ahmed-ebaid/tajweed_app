import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';
import 'package:tajweed_practice/core/services/quran_offline_sync_service.dart';

class _FakeQuranApiService extends QuranApiService {
  int versesCalls = 0;
  int tajweedCalls = 0;
  final Set<int> failAtSurahs;

  _FakeQuranApiService({this.failAtSurahs = const {}});

  @override
  Future<List<Map<String, dynamic>>> fetchVerses({
    required int surahNumber,
    required String langCode,
    int reciterId = 1,
    int? page,
  }) async {
    versesCalls++;
    if (failAtSurahs.contains(surahNumber)) {
      throw Exception('forced failure at surah $surahNumber');
    }

    // Return one page only so sync loop stops quickly (<50).
    return [
      {
        'verse_key': '$surahNumber:1',
        'page_number': surahNumber,
        'text_uthmani': 'رَبِّ',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'رَبِّ',
          },
        ],
      },
    ];
  }

  @override
  Future<Map<String, String>> fetchTajweedText(
      {required int chapterNumber}) async {
    tajweedCalls++;
    return {'$chapterNumber:1': '<tajweed class="ghunnah">رَبِّ</tajweed>'};
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quran_sync_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('verse_cache');
  });

  tearDown(() async {
    await Hive.box('settings').clear();
    await Hive.box('verse_cache').clear();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('syncAll caches every surah and reports completed status', () async {
    final fakeApi = _FakeQuranApiService();
    final service = QuranOfflineSyncService(api: fakeApi);
    final progress = <int>[];

    await service.syncAll(onProgress: (done, total) => progress.add(done));

    final status = await service.getStatus();
    expect(status.inProgress, isFalse);
    expect(status.completed, isTrue);
    expect(status.syncedSurahs, QuranOfflineSyncService.totalSurahs);
    expect(status.lastCompletedAt, isNotNull);
    expect(status.lastError, isNull);
    expect(progress.length, QuranOfflineSyncService.totalSurahs);
    expect(progress.first, 1);
    expect(progress.last, QuranOfflineSyncService.totalSurahs);

    final surah1 = await service.getCachedSurah(1);
    final tajweed1 = await service.getCachedTajweedMap(1);
    expect(surah1, isNotNull);
    expect(surah1!.first['verse_key'], '1:1');
    expect(tajweed1['1:1'], contains('tajweed'));

    // One verses and one tajweed call per surah in this fake.
    expect(fakeApi.versesCalls, QuranOfflineSyncService.totalSurahs);
    expect(fakeApi.tajweedCalls, QuranOfflineSyncService.totalSurahs);
  });

  test('ensureBackgroundSync does nothing when already completed', () async {
    final firstApi = _FakeQuranApiService();
    final service = QuranOfflineSyncService(api: firstApi);

    await service.syncAll();
    expect(firstApi.versesCalls, QuranOfflineSyncService.totalSurahs);

    final secondApi = _FakeQuranApiService();
    final secondService = QuranOfflineSyncService(api: secondApi);
    await secondService.ensureBackgroundSync();

    expect(secondApi.versesCalls, 0);
    expect(secondApi.tajweedCalls, 0);
  });

  test('syncAll persists lastError and resets inProgress on failure', () async {
    final fakeApi = _FakeQuranApiService(failAtSurahs: {3});
    final service = QuranOfflineSyncService(api: fakeApi);

    await expectLater(service.syncAll(), throwsException);

    final status = await service.getStatus();
    expect(status.inProgress, isFalse);
    expect(status.completed, isFalse);
    expect(status.lastError, isNotNull);
    expect(status.lastError, contains('forced failure at surah 3'));

    final cached1 = await service.getCachedSurah(1);
    final cached2 = await service.getCachedSurah(2);
    final cached3 = await service.getCachedSurah(3);
    expect(cached1, isNotNull);
    expect(cached2, isNotNull);
    expect(cached3, isNull);
  });

  test('forceResync clears old data then re-downloads all surahs', () async {
    final fakeApi = _FakeQuranApiService();
    final service = QuranOfflineSyncService(api: fakeApi);

    await service.syncAll();
    final statusAfterFirstSync = await service.getStatus();
    expect(statusAfterFirstSync.completed, isTrue);

    final initialCalls = fakeApi.versesCalls;
    await service.forceResync();

    final statusAfterResync = await service.getStatus();
    expect(statusAfterResync.completed, isTrue);
    expect(fakeApi.versesCalls,
        initialCalls + QuranOfflineSyncService.totalSurahs);

    final surah114 = await service.getCachedSurah(114);
    expect(surah114, isNotNull);
    expect(surah114!.first['verse_key'], '114:1');
  });

  test('clearQuranCache removes all cached surahs and sync metadata', () async {
    final fakeApi = _FakeQuranApiService();
    final service = QuranOfflineSyncService(api: fakeApi);

    await service.syncAll();
    expect(await service.isFullySynced(), isTrue);

    await service.clearQuranCache();

    final status = await service.getStatus();
    expect(status.completed, isFalse);
    expect(status.syncedSurahs, 0);
    expect(status.lastCompletedAt, isNull);
    expect(status.lastError, isNull);

    expect(await service.getCachedSurah(1), isNull);
    expect(await service.getCachedTajweedMap(1), isEmpty);
  });

  test('status does not count surah as synced when tajweed map is missing',
      () async {
    final service = QuranOfflineSyncService(api: _FakeQuranApiService());
    final cacheBox = Hive.box('verse_cache');

    await cacheBox.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'page_number': 1,
        'text_uthmani': 'رَبِّ',
      }
    ]);

    final status = await service.getStatus();
    expect(status.syncedSurahs, 0);
    expect(status.completed, isFalse);
  });

  test('status counts surah only when verses and tajweed map both exist',
      () async {
    final service = QuranOfflineSyncService(api: _FakeQuranApiService());
    final cacheBox = Hive.box('verse_cache');

    await cacheBox.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'page_number': 1,
        'text_uthmani': 'رَبِّ',
      }
    ]);
    await cacheBox.put('quran_tajweed_surah_1',
        {'1:1': '<tajweed class="ghunnah">رَبِّ</tajweed>'});

    final status = await service.getStatus();
    expect(status.syncedSurahs, 1);
    expect(status.completed, isFalse);
  });

  test('ensureBackgroundSync recovers from stale inProgress after restart',
      () async {
    final service = QuranOfflineSyncService(api: _FakeQuranApiService());
    final settings = Hive.box('settings');

    await settings.put('quran_sync_in_progress', true);
    await service.ensureBackgroundSync();

    final status = await service.getStatus();
    expect(status.inProgress, isFalse);
    expect(status.completed, isTrue);
    expect(status.syncedSurahs, QuranOfflineSyncService.totalSurahs);
  });

  test('outdated schema cache remains readable before refresh completes',
      () async {
    final service = QuranOfflineSyncService(api: _FakeQuranApiService());
    final settings = Hive.box('settings');
    final cache = Hive.box('verse_cache');

    await settings.put('quran_sync_version', 1);
    await cache.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'page_number': 1,
        'text_uthmani': 'رَبِّ',
      }
    ]);
    await cache.put('quran_tajweed_surah_1',
        {'1:1': '<tajweed class="ghunnah">رَبِّ</tajweed>'});

    final verses = await service.getCachedSurah(1);
    final tajweedMap = await service.getCachedTajweedMap(1);
    expect(verses, isNotNull);
    expect(tajweedMap, isNotEmpty);
  });

  test('outdated schema refresh does not wipe existing cache on failure',
      () async {
    final service = QuranOfflineSyncService(
      api: _FakeQuranApiService(failAtSurahs: {3}),
    );
    final settings = Hive.box('settings');
    final cache = Hive.box('verse_cache');

    await settings.put('quran_sync_version', 1);
    await cache.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'page_number': 1,
        'text_uthmani': 'رَبِّ',
      }
    ]);
    await cache.put('quran_tajweed_surah_1',
        {'1:1': '<tajweed class="ghunnah">رَبِّ</tajweed>'});

    await expectLater(service.syncAll(), throwsException);

    final stillCached = await service.getCachedSurah(1);
    final stillTajweed = await service.getCachedTajweedMap(1);
    expect(stillCached, isNotNull);
    expect(stillCached!.isNotEmpty, isTrue);
    expect(stillTajweed, isNotEmpty);
  });

  test('ensureBackgroundSync migrates old cached text normalization', () async {
    final service = QuranOfflineSyncService(api: _FakeQuranApiService());
    final settings = Hive.box('settings');
    final cache = Hive.box('verse_cache');

    await settings.put('quran_sync_version', 1);
    await cache.put('quran_ar_surah_7', [
      {
        'verse_key': '7:122',
        'page_number': 165,
        'text_uthmani': 'رَبِّ',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'رَبِّ',
          }
        ],
      }
    ]);
    await cache.put('quran_tajweed_surah_7',
        {'7:122': '<tajweed class="ghunnah">رَبِّ</tajweed>'});

    await service.ensureBackgroundSync();

    final migrated = await service.getCachedSurah(7);
    expect(migrated, isNotNull);
    final text = migrated!.first['text_uthmani'] as String;
    final words = migrated.first['words'] as List<dynamic>;
    final wordText = (words.first as Map)['text_uthmani'] as String;

    expect(text.contains('\u0651\u0650'), isFalse);
    expect(text.contains('\u0650\u0651'), isTrue);
    expect(wordText.contains('\u0651\u0650'), isFalse);
    expect(wordText.contains('\u0650\u0651'), isTrue);
  });

  test('getFirstCachedSurahNumber returns earliest fully cached surah',
      () async {
    final service = QuranOfflineSyncService(api: _FakeQuranApiService());
    final cache = Hive.box('verse_cache');

    await cache.put('quran_ar_surah_3', [
      {
        'verse_key': '3:1',
        'page_number': 50,
        'text_uthmani': 'الم',
      }
    ]);
    await cache.put('quran_tajweed_surah_3', {'3:1': 'x'});

    await cache.put('quran_ar_surah_2', [
      {
        'verse_key': '2:1',
        'page_number': 2,
        'text_uthmani': 'الم',
      }
    ]);
    await cache.put('quran_tajweed_surah_2', {'2:1': 'x'});

    final first = await service.getFirstCachedSurahNumber();
    expect(first, 2);
  });

  test('reads legacy reader cache key format for offline surah', () async {
    final service = QuranOfflineSyncService(api: _FakeQuranApiService());
    final cache = Hive.box('verse_cache');

    await cache.put('7_ar', [
      {
        'verse_key': '7:122',
        'page_number': 165,
        'text_uthmani': 'رَبِّ',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'رَبِّ',
          }
        ],
      }
    ]);

    final surah = await service.getCachedSurah(7);
    expect(surah, isNotNull);
    expect(surah!.first['verse_key'], '7:122');

    // Ensure migration into current key happened for future reads.
    final migrated = cache.get('quran_ar_surah_7');
    expect(migrated, isA<List>());
  });

  test('legacy cache contributes to first cached surah fallback', () async {
    final service = QuranOfflineSyncService(api: _FakeQuranApiService());
    final cache = Hive.box('verse_cache');

    await cache.put('5_en', [
      {
        'verse_key': '5:1',
        'page_number': 106,
        'text_uthmani': 'يَـٰٓأَيُّهَا',
      }
    ]);

    final first = await service.getFirstCachedSurahNumber();
    expect(first, 5);
  });
}
