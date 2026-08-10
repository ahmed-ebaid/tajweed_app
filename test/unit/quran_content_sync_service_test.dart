import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';
import 'package:tajweed_practice/core/services/quran_content_sync_service.dart';

class _FakeContentApi extends QuranApiService {
  final List<Object> pages;
  final Map<String, QuranContentSnapshot> snapshots;
  final List<String?> requestedTokens = [];
  int pageIndex = 0;

  _FakeContentApi({
    required this.pages,
    this.snapshots = const {},
  });

  @override
  Future<QuranContentSyncPage> fetchContentSyncPage({
    required String resources,
    String? syncToken,
    String? nextPageUrl,
  }) async {
    requestedTokens.add(syncToken);
    final response = pages[pageIndex++];
    if (response is DioException) throw response;
    return response as QuranContentSyncPage;
  }

  @override
  Future<QuranContentSnapshot> fetchContentSnapshot({
    required String resourceGroup,
    required int resourceId,
  }) async {
    final snapshot = snapshots['$resourceGroup:$resourceId'];
    if (snapshot == null) {
      throw StateError('forced snapshot failure');
    }
    return snapshot;
  }
}

class _BlockingContentApi extends QuranApiService {
  final snapshotCompleter = Completer<QuranContentSnapshot>();
  int snapshotCalls = 0;
  int pageCalls = 0;

  @override
  Future<QuranContentSnapshot> fetchContentSnapshot({
    required String resourceGroup,
    required int resourceId,
  }) {
    snapshotCalls++;
    return snapshotCompleter.future;
  }

  @override
  Future<QuranContentSyncPage> fetchContentSyncPage({
    required String resources,
    String? syncToken,
    String? nextPageUrl,
  }) async {
    pageCalls++;
    return const QuranContentSyncPage(
      hasMore: false,
      nextPageUrl: null,
      nextSyncToken: 'token-1',
      mutations: [],
    );
  }
}

void main() {
  late Directory tempDir;
  late Box cache;
  late Box settings;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('content_sync_test_');
    Hive.init(tempDir.path);
    settings = await Hive.openBox('settings');
    cache = await Hive.openBox('verse_cache');
    await Hive.openBox('audio_cache');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('bootstrap snapshot atomically replaces cached translation rows',
      () async {
    await cache.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'translations': [
          {'id': 1, 'resource_id': 85, 'text': 'Old translation'},
        ],
      },
    ]);
    final api = _FakeContentApi(
      pages: const [
        QuranContentSyncPage(
          hasMore: false,
          nextPageUrl: null,
          nextSyncToken: 'token-1',
          mutations: [
            QuranContentMutation(
              type: 'RESOURCE_INVALIDATE',
              resourceGroup: 'translations',
              resourceId: 85,
              recordKey: null,
              data: null,
            ),
          ],
        ),
      ],
      snapshots: const {
        'translations:85': QuranContentSnapshot(
          resourceGroup: 'translations',
          resourceId: 85,
          records: [
            {
              'id': 401704,
              'verse_key': '1:1',
              'text': 'Current translation',
            },
          ],
        ),
      },
    );

    await QuranContentSyncService(
      api: api,
      cacheBox: cache,
      audioBox: Hive.box('audio_cache'),
      settingsBox: settings,
      clearReciter: (_) async {},
    ).syncIfDue();

    final verses = (cache.get('quran_ar_surah_1') as List).cast<Map>();
    final translations = (verses.single['translations'] as List).cast<Map>();
    expect(translations.single['text'], 'Current translation');
    expect(settings.get('qf_content_sync_token'), 'token-1');
  });

  test('pagination persists only the final sync token', () async {
    await cache.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'translations': [
          {'id': 401704, 'resource_id': 85, 'text': 'Current'},
        ],
      },
    ]);
    final api = _FakeContentApi(
      pages: const [
        QuranContentSyncPage(
          hasMore: true,
          nextPageUrl: 'https://apis.quran.foundation/api/v4/resources/sync'
              '?cursor=next',
          nextSyncToken: 'intermediate-token',
          mutations: [],
        ),
        QuranContentSyncPage(
          hasMore: false,
          nextPageUrl: null,
          nextSyncToken: 'final-token',
          mutations: [],
        ),
      ],
      snapshots: const {
        'translations:85': QuranContentSnapshot(
          resourceGroup: 'translations',
          resourceId: 85,
          records: [
            {
              'id': 401704,
              'verse_key': '1:1',
              'text': 'Current',
            },
          ],
        ),
      },
    );

    await QuranContentSyncService(
      api: api,
      cacheBox: cache,
      audioBox: Hive.box('audio_cache'),
      settingsBox: settings,
      clearReciter: (_) async {},
    ).syncIfDue();

    expect(settings.get('qf_content_sync_token'), 'final-token');
    expect(api.pageIndex, 2);
  });

  test('row deletion removes the record from the reader cache', () async {
    await cache.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'translations': [
          {'id': 401704, 'resource_id': 85, 'text': 'Current'},
        ],
      },
    ]);
    await cache.put('qf_resource_translations_85', [
      {
        'id': 401704,
        'verse_key': '1:1',
        'resource_id': 85,
        'text': 'Current',
      },
    ]);
    await settings.putAll({
      'qf_content_sync_resource_filter': 'translations:85',
      'qf_content_sync_token': 'token-1',
    });
    final api = _FakeContentApi(
      pages: const [
        QuranContentSyncPage(
          hasMore: false,
          nextPageUrl: null,
          nextSyncToken: 'token-2',
          mutations: [
            QuranContentMutation(
              type: 'ROW_DELETE',
              resourceGroup: 'translations',
              resourceId: 85,
              recordKey: '401704',
              data: null,
            ),
          ],
        ),
      ],
      snapshots: const {
        'translations:85': QuranContentSnapshot(
          resourceGroup: 'translations',
          resourceId: 85,
          records: [
            {
              'id': 401704,
              'verse_key': '1:1',
              'text': 'Current',
            },
          ],
        ),
      },
    );

    await QuranContentSyncService(
      api: api,
      cacheBox: cache,
      audioBox: Hive.box('audio_cache'),
      settingsBox: settings,
      clearReciter: (_) async {},
    ).syncIfDue();

    final verses = (cache.get('quran_ar_surah_1') as List).cast<Map>();
    expect(verses.single['translations'], isEmpty);
  });

  test('410 response discards the old token and bootstraps once', () async {
    await cache.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'translations': [
          {'id': 401704, 'resource_id': 85, 'text': 'Current'},
        ],
      },
    ]);
    await settings.putAll({
      'qf_content_sync_resource_filter': 'translations:85',
      'qf_content_sync_token': 'expired-token',
    });
    final request = RequestOptions(path: '/resources/sync');
    final api = _FakeContentApi(
      pages: [
        DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 410,
            data: {'error': 'resync_required'},
          ),
        ),
        const QuranContentSyncPage(
          hasMore: false,
          nextPageUrl: null,
          nextSyncToken: 'replacement-token',
          mutations: [],
        ),
      ],
      snapshots: const {
        'translations:85': QuranContentSnapshot(
          resourceGroup: 'translations',
          resourceId: 85,
          records: [
            {
              'id': 401704,
              'verse_key': '1:1',
              'text': 'Current',
            },
          ],
        ),
      },
    );

    await QuranContentSyncService(
      api: api,
      cacheBox: cache,
      audioBox: Hive.box('audio_cache'),
      settingsBox: settings,
      clearReciter: (_) async {},
    ).syncIfDue();

    expect(api.requestedTokens, ['expired-token', null]);
    expect(
      settings.get('qf_content_sync_token'),
      'replacement-token',
    );
  });

  test('failed snapshot keeps the previous cache and sync token', () async {
    await cache.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'translations': [
          {'id': 401704, 'resource_id': 85, 'text': 'Still valid'},
        ],
      },
    ]);
    await settings.putAll({
      'qf_content_sync_resource_filter': 'translations:85',
      'qf_content_sync_token': 'token-1',
    });
    final api = _FakeContentApi(
      pages: const [
        QuranContentSyncPage(
          hasMore: false,
          nextPageUrl: null,
          nextSyncToken: 'token-2',
          mutations: [
            QuranContentMutation(
              type: 'RESOURCE_INVALIDATE',
              resourceGroup: 'translations',
              resourceId: 85,
              recordKey: null,
              data: null,
            ),
          ],
        ),
      ],
    );
    final service = QuranContentSyncService(
      api: api,
      cacheBox: cache,
      audioBox: Hive.box('audio_cache'),
      settingsBox: settings,
      clearReciter: (_) async {},
      backoffForAttempt: (_) => Duration.zero,
    );

    await expectLater(service.syncIfDue(), throwsStateError);

    final verses = (cache.get('quran_ar_surah_1') as List).cast<Map>();
    final translations = (verses.single['translations'] as List).cast<Map>();
    expect(translations.single['text'], 'Still valid');
    expect(settings.get('qf_content_sync_token'), 'token-1');
    expect(settings.get('qf_content_sync_failure_count'), 1);
  });

  test('recitation invalidation replaces URLs and clears stale audio',
      () async {
    await cache.put('qf_recitation_1_surah_1', {'1:1': 'old.mp3'});
    await cache.put('qf_resource_recitations_1', [
      {'id': 1, 'verse_key': '1:1', 'url': 'old.mp3'},
    ]);
    var clearedReciter = 0;
    final api = _FakeContentApi(
      pages: const [
        QuranContentSyncPage(
          hasMore: false,
          nextPageUrl: null,
          nextSyncToken: 'token-1',
          mutations: [
            QuranContentMutation(
              type: 'RESOURCE_INVALIDATE',
              resourceGroup: 'recitations',
              resourceId: 1,
              recordKey: null,
              data: null,
            ),
          ],
        ),
      ],
      snapshots: const {
        'recitations:1': QuranContentSnapshot(
          resourceGroup: 'recitations',
          resourceId: 1,
          records: [
            {'id': 2, 'verse_key': '1:1', 'url': 'new.mp3'},
          ],
        ),
      },
    );

    await QuranContentSyncService(
      api: api,
      cacheBox: cache,
      audioBox: Hive.box('audio_cache'),
      settingsBox: settings,
      clearReciter: (id) async => clearedReciter = id,
    ).syncIfDue();

    expect(cache.get('qf_recitation_1_surah_1'), {'1:1': 'new.mp3'});
    expect(clearedReciter, 1);
  });

  test('concurrent validation requests share one in-flight operation',
      () async {
    await cache.put('quran_ar_surah_1', [
      {
        'verse_key': '1:1',
        'translations': [
          {'id': 401704, 'resource_id': 85, 'text': 'Current'},
        ],
      },
    ]);
    final api = _BlockingContentApi();
    final service = QuranContentSyncService(
      api: api,
      cacheBox: cache,
      audioBox: Hive.box('audio_cache'),
      settingsBox: settings,
      clearReciter: (_) async {},
    );

    final first = service.syncIfDue();
    final second = service.syncIfDue();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(api.snapshotCalls, 1);

    api.snapshotCompleter.complete(
      const QuranContentSnapshot(
        resourceGroup: 'translations',
        resourceId: 85,
        records: [
          {'id': 401704, 'verse_key': '1:1', 'text': 'Current'},
        ],
      ),
    );
    await Future.wait([first, second]);

    expect(api.snapshotCalls, 1);
    expect(api.pageCalls, 1);
  });
}
