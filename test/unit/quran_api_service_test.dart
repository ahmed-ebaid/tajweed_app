import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, Map<String, Object?>> responseBodies = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body =
        responseBodies[options.path] ??
        switch (options.path) {
          '/chapters' => {'chapters': <Object>[]},
          _ => <String, Object>{},
        };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('QuranApiService routing', () {
    test('uses the app-owned proxy for Content API requests', () async {
      final contentAdapter = _RecordingAdapter();
      final contentClient = Dio(
        BaseOptions(baseUrl: QuranApiService.contentApiBaseUrl),
      )..httpClientAdapter = contentAdapter;
      final service = QuranApiService(contentClient: contentClient);

      await service.fetchSurahList(langCode: 'en');

      expect(contentAdapter.requests, hasLength(1));
      expect(
        contentAdapter.requests.single.uri.host,
        'tajweed-quran-proxy-production.ebaidllc.workers.dev',
      );
      expect(contentAdapter.requests.single.uri.path, '/v2/content/chapters');
    });

    test('requests Uthmani text and metadata for Mushaf pages', () async {
      final adapter = _RecordingAdapter();
      final contentClient = Dio(
        BaseOptions(baseUrl: QuranApiService.contentApiBaseUrl),
      )..httpClientAdapter = adapter;
      final service = QuranApiService(contentClient: contentClient);
      adapter.responseBodies['/verses/by_page/293'] = {
        'verses': [
          {
            'verse_key': '18:1',
            'text_uthmani': 'ٱلْحَمْدُ لِلَّهِ',
            'page_number': 293,
            'juz_number': 15,
          },
        ],
      };

      final verses = await service.fetchVersesByPage(
        pageNumber: 293,
        langCode: 'ar',
      );

      expect(verses.single['verse_key'], '18:1');
      expect(adapter.requests.single.queryParameters, {
        'language': 'ar',
        'words': 'false',
        'fields': 'text_uthmani,page_number,verse_key,juz_number',
        'per_page': 50,
      });
    });

    test(
      'parses Content Sync pages and sends the canonical bootstrap query',
      () async {
        final adapter = _RecordingAdapter();
        final contentClient = Dio(
          BaseOptions(baseUrl: QuranApiService.contentApiBaseUrl),
        )..httpClientAdapter = adapter;
        final service = QuranApiService(contentClient: contentClient);

        adapter.responseBodies['/resources/sync'] = {
          'sync': {
            'has_more': false,
            'next_page_url': null,
            'next_sync_token': 'final-token',
            'mutations': [
              {
                'type': 'ROW_UPDATE',
                'resource_group': 'translations',
                'resource_id': 85,
                'record_key': '401704',
                'data': {'id': 401704, 'verse_key': '1:1', 'text': 'Updated'},
              },
            ],
          },
        };

        final page = await service.fetchContentSyncPage(
          resources: 'translations:85',
        );

        expect(page.nextSyncToken, 'final-token');
        expect(page.mutations.single.recordKey, '401704');
        expect(adapter.requests.single.queryParameters, {
          'resources': 'translations:85',
          'per_page': 100,
          'bootstrap': true,
        });
      },
    );
  });

  group('QuranApiService.ruleFromCode', () {
    test('maps all known tajweed codes to rules', () {
      final expected = {
        'g': TajweedRule.ghunnah,
        'q': TajweedRule.qalqalah,
        'm': TajweedRule.maddTabeei,
        'M': TajweedRule.maddMuttasil,
        'n': TajweedRule.maddMunfasil,
        'i': TajweedRule.ikhfa,
        'I': TajweedRule.iqlab,
        'd': TajweedRule.idghamWithGhunnah,
        'D': TajweedRule.idghamWithoutGhunnah,
        'z': TajweedRule.izhar,
        's': TajweedRule.shaddah,
      };
      for (final entry in expected.entries) {
        expect(
          QuranApiService.ruleFromCode(entry.key),
          equals(entry.value),
          reason: 'Code "${entry.key}" should map to ${entry.value}',
        );
      }
    });

    test('returns null for unknown codes', () {
      expect(QuranApiService.ruleFromCode('x'), isNull);
      expect(QuranApiService.ruleFromCode(''), isNull);
      expect(QuranApiService.ruleFromCode('Z'), isNull);
    });

    test('codes are case-sensitive (m ≠ M)', () {
      expect(QuranApiService.ruleFromCode('m'), equals(TajweedRule.maddTabeei));
      expect(
        QuranApiService.ruleFromCode('M'),
        equals(TajweedRule.maddMuttasil),
      );
    });
  });

  group('QuranApiService.audioUrl', () {
    test('formats URL correctly with zero-padded surah and ayah', () {
      final service = QuranApiService();
      final url = service.audioUrl(reciterId: 7, surahNumber: 1, ayahNumber: 1);
      expect(url, equals('https://verses.quran.com/7/001001.mp3'));
    });

    test('handles double-digit surah and ayah', () {
      final service = QuranApiService();
      final url = service.audioUrl(
        reciterId: 7,
        surahNumber: 67,
        ayahNumber: 30,
      );
      expect(url, equals('https://verses.quran.com/7/067030.mp3'));
    });
  });

  group('QuranApiService.translationIdFor', () {
    test('uses available Abdel Haleem English translation', () {
      expect(QuranApiService.translationIdFor('en'), '85');
    });

    test('uses a Spanish translation rather than an English fallback', () {
      expect(QuranApiService.translationIdFor('es'), '83');
    });
  });
}
