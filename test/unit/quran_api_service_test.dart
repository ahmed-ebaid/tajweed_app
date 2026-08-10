import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = switch (options.path) {
      '/chapters' => {'chapters': <Object>[]},
      '/search' => {
          'search': {'results': <Object>[]},
        },
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
      final service = QuranApiService(
        contentClient: contentClient,
        searchClient: Dio(),
      );

      await service.fetchSurahList(langCode: 'en');

      expect(contentAdapter.requests, hasLength(1));
      expect(
        contentAdapter.requests.single.uri.host,
        'tajweed-quran-proxy.ebaidllc.workers.dev',
      );
      expect(contentAdapter.requests.single.uri.path, '/v1/content/chapters');
    });

    test('keeps Search on its separate API endpoint', () async {
      final searchAdapter = _RecordingAdapter();
      final searchClient = Dio(
        BaseOptions(baseUrl: 'https://api.quran.com/api/v4'),
      )..httpClientAdapter = searchAdapter;
      final service = QuranApiService(
        contentClient: Dio(),
        searchClient: searchClient,
      );

      await service.search(query: 'mercy', langCode: 'en');

      expect(searchAdapter.requests, hasLength(1));
      expect(searchAdapter.requests.single.uri.host, 'api.quran.com');
      expect(searchAdapter.requests.single.uri.path, '/api/v4/search');
    });
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
