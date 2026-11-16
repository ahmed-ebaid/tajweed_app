import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/mushaf_page_starts.dart';
import '../models/tajweed_models.dart';
import 'ayah_mapper.dart';
import 'quran_api_service.dart';
import 'quran_attestation_service.dart';
import 'quran_offline_sync_service.dart';

class HifzContentService {
  static bool get prelivePreviewEnabled =>
      !kReleaseMode &&
      QuranAttestationService.appAttestBypassEnabled &&
      Uri.parse(QuranApiService.contentApiBaseUrl).host ==
          'tajweed-quran-proxy.ebaidllc.workers.dev';

  HifzContentService({
    QuranApiService? api,
    QuranOfflineSyncService? offline,
    Future<bool> Function()? isOffline,
  }) : _api = api ?? QuranApiService(),
       _offline = offline ?? QuranOfflineSyncService(),
       _isOffline = isOffline ?? _deviceOffline;

  final QuranApiService _api;
  final QuranOfflineSyncService _offline;
  final Future<bool> Function() _isOffline;

  static Future<bool> _deviceOffline() async =>
      (await Connectivity().checkConnectivity().timeout(
        const Duration(seconds: 2),
      )).every((result) => result == ConnectivityResult.none);

  Future<List<Map<String, dynamic>>> chapters() async {
    final settings = Hive.box('settings');
    final cached = settings.get('reader_surah_list_ar');
    if (cached is List && cached.length == 114) {
      return cached
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    final chapters = await _api
        .fetchSurahList(langCode: 'ar')
        .timeout(const Duration(seconds: 15));
    if (chapters.length != 114) {
      if (prelivePreviewEnabled &&
          chapters.isNotEmpty &&
          chapters.every(
            (chapter) =>
                chapter['id'] is int &&
                (chapter['id'] as int) >= 1 &&
                (chapter['id'] as int) <= 114 &&
                chapter['verses_count'] is int &&
                (chapter['verses_count'] as int) > 0,
          ) &&
          chapters.map((chapter) => chapter['id']).toSet().length ==
              chapters.length) {
        debugPrint(
          'Hifz prelive preview: ${chapters.length} sandbox chapters; '
          'complete surah and page checks remain enabled.',
        );
        // Sandbox chapter lists must not replace the complete Reader cache.
        return chapters;
      }
      throw StateError('Incomplete Hifz chapters');
    }
    await settings.put('reader_surah_list_ar', chapters);
    return chapters;
  }

  Future<List<Ayah>> loadSurah({
    required int surahNumber,
    required int expectedCount,
    required int reciterId,
  }) async {
    var raw = await _offline.getCachedSurah(surahNumber) ?? [];
    bool complete() => isCompleteSurah(
      AyahMapper.fromApiList(raw, requestedLangCode: 'ar'),
      surahNumber: surahNumber,
      expectedCount: expectedCount,
    );
    final offline = await _isOffline();
    if (!offline &&
        (!complete() ||
            AyahMapper.fromApiList(
              raw,
              requestedLangCode: 'ar',
            ).any((ayah) => ayah.imlaei == null))) {
      raw = [];
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      for (var batch = 1; batch <= 6; batch++) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException('Hifz surah loading timed out');
        }
        final verses = await _api
            .fetchVerses(
              surahNumber: surahNumber,
              langCode: 'ar',
              reciterId: reciterId,
              page: batch,
            )
            .timeout(
              remaining < const Duration(seconds: 15)
                  ? remaining
                  : const Duration(seconds: 15),
            );
        raw.addAll(verses);
        if (verses.length < 50) break;
      }
    }
    if (!complete()) throw StateError('Incomplete Hifz surah');
    return AyahMapper.fromApiList(raw, requestedLangCode: 'ar')
      ..sort((a, b) => a.ayahNumber.compareTo(b.ayahNumber));
  }

  Future<List<Ayah>> loadPage(
    int pageNumber,
    List<Map<String, dynamic>> chapters,
  ) async {
    if (pageNumber < 1 || pageNumber > 604) {
      throw ArgumentError.value(pageNumber, 'pageNumber');
    }
    final expected = <String>{
      for (final chapter in chapters)
        for (var ayah = 1; ayah <= (chapter['verses_count'] as int); ayah++)
          if (verseBelongsToMushafPage('${chapter['id']}:$ayah', pageNumber))
            '${chapter['id']}:$ayah',
    };
    var raw = await _offline.getCachedVersesForPage(pageNumber);
    bool complete() {
      final ayahs = AyahMapper.fromApiList(raw, requestedLangCode: 'ar');
      return expected.isNotEmpty &&
          ayahs.length == expected.length &&
          ayahs.every(
            (ayah) =>
                ayah.pageNumber == pageNumber &&
                ayah.plainArabicText().isNotEmpty &&
                ayah.words.isNotEmpty &&
                ayah.endLineNumber != null &&
                ayah.words.every((word) => word.lineNumber != null),
          ) &&
          expected.containsAll(
            ayahs.map((ayah) => '${ayah.surahNumber}:${ayah.ayahNumber}'),
          ) &&
          ayahs
                  .map((ayah) => '${ayah.surahNumber}:${ayah.ayahNumber}')
                  .toSet()
                  .length ==
              expected.length;
    }

    if (!complete() && !await _isOffline()) {
      raw = await _api
          .fetchVersesByPage(pageNumber: pageNumber, langCode: 'ar')
          .timeout(const Duration(seconds: 15));
    }
    if (!complete()) throw StateError('Incomplete Hifz Mushaf page');
    return AyahMapper.fromApiList(raw, requestedLangCode: 'ar')..sort((a, b) {
      final surah = a.surahNumber.compareTo(b.surahNumber);
      return surah == 0 ? a.ayahNumber.compareTo(b.ayahNumber) : surah;
    });
  }

  static bool isCompleteSurah(
    List<Ayah> ayahs, {
    required int surahNumber,
    required int expectedCount,
  }) {
    if (expectedCount <= 0 || ayahs.length != expectedCount) return false;
    final numbers = <int>{};
    for (final ayah in ayahs) {
      if (ayah.surahNumber != surahNumber ||
          ayah.ayahNumber < 1 ||
          ayah.ayahNumber > expectedCount ||
          ayah.pageNumber < 1 ||
          ayah.pageNumber > 604 ||
          ayah.plainArabicText().isEmpty) {
        return false;
      }
      numbers.add(ayah.ayahNumber);
    }
    return numbers.length == expectedCount;
  }
}
