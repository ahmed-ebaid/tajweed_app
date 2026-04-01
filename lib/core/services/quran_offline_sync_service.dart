import 'package:hive_flutter/hive_flutter.dart';

import 'quran_api_service.dart';

class QuranOfflineSyncStatus {
  final bool inProgress;
  final bool completed;
  final int syncedSurahs;
  final int totalSurahs;
  final DateTime? lastCompletedAt;
  final String? lastError;

  const QuranOfflineSyncStatus({
    required this.inProgress,
    required this.completed,
    required this.syncedSurahs,
    required this.totalSurahs,
    required this.lastCompletedAt,
    required this.lastError,
  });
}

class QuranOfflineDiagnostics {
  final int schemaVersion;
  final int storedVersion;
  final bool inProgress;
  final int syncedSurahs;
  final int totalSurahs;
  final List<String> surahCacheKeys;
  final List<String> tajweedCacheKeys;
  final Map<String, String> ayahFirstWord;
  final Map<String, String> ayahFirstWordCodepoints;

  const QuranOfflineDiagnostics({
    required this.schemaVersion,
    required this.storedVersion,
    required this.inProgress,
    required this.syncedSurahs,
    required this.totalSurahs,
    required this.surahCacheKeys,
    required this.tajweedCacheKeys,
    required this.ayahFirstWord,
    required this.ayahFirstWordCodepoints,
  });

  String toMultilineString() {
    final buffer = StringBuffer()
      ..writeln('schemaVersion=$schemaVersion')
      ..writeln('storedVersion=$storedVersion')
      ..writeln('inProgress=$inProgress')
      ..writeln('syncedSurahs=$syncedSurahs/$totalSurahs')
      ..writeln('surahCacheKeys=[${surahCacheKeys.join(', ')}]')
      ..writeln('tajweedCacheKeys=[${tajweedCacheKeys.join(', ')}]');

    for (final key in ayahFirstWord.keys) {
      buffer.writeln('$key firstWord="${ayahFirstWord[key] ?? ''}"');
      buffer.writeln(
          '$key firstWordCodepoints=${ayahFirstWordCodepoints[key] ?? ''}');
    }

    return buffer.toString();
  }
}

class QuranOfflineSyncService {
  static const int totalSurahs = 114;
  static bool _isSyncRunning = false;
  static final RegExp _shaddaBeforeShortVowelPattern = RegExp(
    '\u0651([\u064B-\u0650])',
  );
  static const String _canonicalMarkerGlyph = '\u06DE';
  static const String _sajdahGlyph = '\u06E9';
  static const int _rubElHizbRune = 0x06DE;
  static const Set<int> _sajdahAyahKeys = {
    7 * 1000 + 206,
    13 * 1000 + 15,
    16 * 1000 + 50,
    17 * 1000 + 109,
    19 * 1000 + 58,
    22 * 1000 + 18,
    22 * 1000 + 77,
    25 * 1000 + 60,
    27 * 1000 + 26,
    32 * 1000 + 15,
    38 * 1000 + 24,
    41 * 1000 + 38,
    53 * 1000 + 62,
    84 * 1000 + 21,
    96 * 1000 + 19,
  };

  static const String _settingsBoxKey = 'settings';
  static const String _cacheBoxKey = 'verse_cache';

  static const int _syncSchemaVersion = 5;
  static const String _syncVersionKey = 'quran_sync_version';
  static const String _syncInProgressKey = 'quran_sync_in_progress';
  static const String _syncCompletedAtKey = 'quran_sync_completed_at';
  static const String _syncLastSurahKey = 'quran_sync_last_surah';
  static const String _syncLastErrorKey = 'quran_sync_last_error';

  final QuranApiService _api;

  QuranOfflineSyncService({QuranApiService? api})
      : _api = api ?? QuranApiService();

  static String _surahCacheKey(int surahNumber) =>
      'quran_ar_surah_$surahNumber';

  static String _tajweedCacheKey(int surahNumber) =>
      'quran_tajweed_surah_$surahNumber';

    static String _tafsirCacheKey(int tafsirId, int surahNumber) =>
      'tafsir_${tafsirId}_surah_$surahNumber';

  Box get _settingsBox => Hive.box(_settingsBoxKey);

  Box get _cacheBox => Hive.box(_cacheBoxKey);

  Future<QuranOfflineSyncStatus> getStatus() async {
    final completedAtMs = _settingsBox.get(_syncCompletedAtKey) as int?;
    final syncedSurahs = _countSyncedSurahs();
    final completed = syncedSurahs >= totalSurahs &&
        (_settingsBox.get(_syncVersionKey, defaultValue: 0) as int) >=
            _syncSchemaVersion;

    return QuranOfflineSyncStatus(
      inProgress:
          _settingsBox.get(_syncInProgressKey, defaultValue: false) as bool,
      completed: completed,
      syncedSurahs: syncedSurahs,
      totalSurahs: totalSurahs,
      lastCompletedAt: completedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(completedAtMs),
      lastError: _settingsBox.get(_syncLastErrorKey) as String?,
    );
  }

  Future<bool> isFullySynced() async {
    final status = await getStatus();
    return status.completed;
  }

  Future<List<Map<String, dynamic>>?> getCachedSurah(int surahNumber) async {
    final raw = _cacheBox.get(_surahCacheKey(surahNumber));
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    // Backward compatibility for older reader cache keys like "7_ar".
    final legacy = _loadLegacySurahRaw(surahNumber);
    if (legacy == null) return null;

    // Best-effort migration into the current cache key for future reads.
    _cacheBox.put(_surahCacheKey(surahNumber), legacy);
    return legacy;
  }

  Future<Map<String, String>> getCachedTajweedMap(int surahNumber) async {
    final raw = _cacheBox.get(_tajweedCacheKey(surahNumber));
    if (raw is! Map) return <String, String>{};

    return raw.map<String, String>((key, value) {
      return MapEntry(key.toString(), value?.toString() ?? '');
    });
  }

  Future<Map<String, String>> getCachedTafsirMap({
    required int tafsirId,
    required int surahNumber,
  }) async {
    final raw = _cacheBox.get(_tafsirCacheKey(tafsirId, surahNumber));
    if (raw is! Map) return <String, String>{};

    return raw.map<String, String>((key, value) {
      return MapEntry(key.toString(), value?.toString() ?? '');
    });
  }

  Future<void> saveTafsirMap({
    required int tafsirId,
    required int surahNumber,
    required Map<String, String> tafsirMap,
  }) async {
    await _cacheBox.put(_tafsirCacheKey(tafsirId, surahNumber), tafsirMap);
  }

  Future<void> ensureBackgroundSync({
    void Function(int done, int total)? onProgress,
  }) async {
    if (_isSyncRunning) return;

    final status = await getStatus();
    if (status.completed) return;

    // Recover from app restarts where the previous run was terminated and
    // left the persisted in-progress flag behind.
    if (status.inProgress) {
      await _settingsBox.put(_syncInProgressKey, false);
    }

    await _migrateCachedTextIfNeeded();

    // Migration-only schema updates can make the cache fully ready without
    // requiring a network re-download. Re-check before syncing.
    final afterMigration = await getStatus();
    if (afterMigration.completed) return;

    await syncAll(onProgress: onProgress);
  }

  Future<void> forceResync({
    void Function(int done, int total)? onProgress,
  }) async {
    await clearQuranCache();
    await syncAll(onProgress: onProgress);
  }

  Future<void> syncAll({
    void Function(int done, int total)? onProgress,
  }) async {
    if (_isSyncRunning) return;
    _isSyncRunning = true;

    final currentVersion =
        (_settingsBox.get(_syncVersionKey, defaultValue: 0) as int?) ?? 0;
    final needsFullRefresh = currentVersion < _syncSchemaVersion;

    _settingsBox.put(_syncInProgressKey, true);
    _settingsBox.delete(_syncLastErrorKey);

    try {
      for (int surah = 1; surah <= totalSurahs; surah++) {
        if (!needsFullRefresh && _isSurahCached(surah)) {
          _settingsBox.put(_syncLastSurahKey, surah);
          onProgress?.call(surah, totalSurahs);
          continue;
        }

        final verses = <Map<String, dynamic>>[];
        int page = 1;
        while (true) {
          final chunk = await _api.fetchVerses(
            surahNumber: surah,
            langCode: 'ar',
            page: page,
          );
          verses.addAll(chunk);
          if (chunk.length < 50) break;
          page++;
        }

        final tajweedMap = await _api.fetchTajweedText(chapterNumber: surah);
        await saveSurahCache(
          surahNumber: surah,
          verses: verses,
          tajweedMap: tajweedMap,
        );

        _settingsBox.put(_syncLastSurahKey, surah);
        onProgress?.call(surah, totalSurahs);
      }

      _settingsBox.put(_syncVersionKey, _syncSchemaVersion);
      _settingsBox.put(
        _syncCompletedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      _settingsBox.put(_syncLastErrorKey, e.toString());
      rethrow;
    } finally {
      _settingsBox.put(_syncInProgressKey, false);
      _isSyncRunning = false;
    }
  }

  Future<void> saveSurahCache({
    required int surahNumber,
    required List<Map<String, dynamic>> verses,
    required Map<String, String> tajweedMap,
  }) async {
    final normalizedVerses = _normalizeVerseList(verses);
    await _cacheBox.put(_surahCacheKey(surahNumber), normalizedVerses);
    await _cacheBox.put(_tajweedCacheKey(surahNumber), tajweedMap);
  }

  Future<void> clearQuranCache() async {
    final keys = <String>{};
    for (int surah = 1; surah <= totalSurahs; surah++) {
      keys.add(_surahCacheKey(surah));
      keys.add(_tajweedCacheKey(surah));
    }

    // Remove older cache formats too (e.g. "7_ar") so stale payloads do not
    // silently repopulate current keys after a user clears local data.
    final legacyKeys = _cacheBox.keys
        .whereType<String>()
      .where((k) =>
        RegExp(r'^\d+_').hasMatch(k) ||
        RegExp(r'^tafsir_\d+_surah_\d+$').hasMatch(k))
        .toList(growable: false);
    keys.addAll(legacyKeys);

    await _cacheBox.deleteAll(keys.toList(growable: false));

    await _settingsBox.delete(_syncVersionKey);
    await _settingsBox.delete(_syncInProgressKey);
    await _settingsBox.delete(_syncCompletedAtKey);
    await _settingsBox.delete(_syncLastSurahKey);
    await _settingsBox.delete(_syncLastErrorKey);
  }

  Future<int?> getFirstCachedSurahNumber() async {
    for (int surah = 1; surah <= totalSurahs; surah++) {
      final verses = await getCachedSurah(surah);
      if (verses != null && verses.isNotEmpty) return surah;
    }
    return null;
  }

  Future<QuranOfflineDiagnostics> getDiagnostics({
    int surahNumber = 7,
    List<int> ayahNumbers = const [101, 122],
  }) async {
    final status = await getStatus();
    final storedVersion =
        (_settingsBox.get(_syncVersionKey, defaultValue: 0) as int?) ?? 0;

    final surahKeys = <String>{
      _surahCacheKey(surahNumber),
      ..._legacySurahKeys(surahNumber),
    };
    final tajweedKeys = <String>{_tajweedCacheKey(surahNumber)};

    final ayahTexts = <String, String>{};
    final ayahCodepoints = <String, String>{};

    final cached = await getCachedSurah(surahNumber);
    if (cached != null) {
      for (final ayahNumber in ayahNumbers) {
        final verseKey = '$surahNumber:$ayahNumber';
        final verse = cached.firstWhere(
          (v) => (v['verse_key'] as String?) == verseKey,
          orElse: () => <String, dynamic>{},
        );

        final words = verse['words'];
        String firstWord = '';
        if (words is List && words.isNotEmpty) {
          for (final w in words) {
            if (w is! Map) continue;
            final type = w['char_type_name']?.toString() ?? '';
            if (type == 'end') continue;
            firstWord = w['text_uthmani']?.toString() ?? '';
            if (firstWord.isNotEmpty) break;
          }
        }

        if (firstWord.isEmpty) {
          final verseText = verse['text_uthmani']?.toString() ?? '';
          firstWord = verseText.split(' ').firstWhere(
                (p) => p.isNotEmpty,
                orElse: () => '',
              );
        }

        ayahTexts[verseKey] = firstWord;
        ayahCodepoints[verseKey] = _toCodepoints(firstWord);
      }
    }

    return QuranOfflineDiagnostics(
      schemaVersion: _syncSchemaVersion,
      storedVersion: storedVersion,
      inProgress: status.inProgress,
      syncedSurahs: status.syncedSurahs,
      totalSurahs: status.totalSurahs,
      surahCacheKeys: surahKeys.toList(growable: false),
      tajweedCacheKeys: tajweedKeys.toList(growable: false),
      ayahFirstWord: ayahTexts,
      ayahFirstWordCodepoints: ayahCodepoints,
    );
  }

  bool _isSurahCached(int surahNumber) {
    final versesRaw = _cacheBox.get(_surahCacheKey(surahNumber));
    final tajweedRaw = _cacheBox.get(_tajweedCacheKey(surahNumber));
    final hasVerses = (versesRaw is List && versesRaw.isNotEmpty) ||
        (_loadLegacySurahRaw(surahNumber)?.isNotEmpty ?? false);
    final hasTajweed = tajweedRaw is Map && tajweedRaw.isNotEmpty;
    return hasVerses && hasTajweed;
  }

  int _countSyncedSurahs() {
    int count = 0;
    for (int surah = 1; surah <= totalSurahs; surah++) {
      if (_isSurahCached(surah)) count++;
    }
    return count;
  }

  int _countAnyCachedSurahs() {
    int count = 0;
    for (int surah = 1; surah <= totalSurahs; surah++) {
      final raw = _cacheBox.get(_surahCacheKey(surah));
      if ((raw is List && raw.isNotEmpty) ||
          (_loadLegacySurahRaw(surah)?.isNotEmpty ?? false)) {
        count++;
      }
    }
    return count;
  }

  Future<void> _migrateCachedTextIfNeeded() async {
    final currentVersion =
        (_settingsBox.get(_syncVersionKey, defaultValue: 0) as int?) ?? 0;
    if (currentVersion >= _syncSchemaVersion) return;

    bool touchedAny = false;

    for (int surah = 1; surah <= totalSurahs; surah++) {
      final candidateKeys = <String>{
        _surahCacheKey(surah),
        ..._legacySurahKeys(surah),
      };

      for (final key in candidateKeys) {
        final raw = _cacheBox.get(key);
        if (raw is! List) continue;

        final migrated = <Map<String, dynamic>>[];
        bool changed = false;

        for (final item in raw) {
          if (item is! Map) continue;
          final verse = Map<String, dynamic>.from(item);

          final forceSajdahGlyph = _isSajdahAyahVerse(verse);
          final verseText = verse['text_uthmani'] as String?;
          if (verseText != null) {
            final normalizedVerse =
                _normalizeArabicText(verseText, forceSajdahGlyph: forceSajdahGlyph);
            if (normalizedVerse != verseText) {
              verse['text_uthmani'] = normalizedVerse;
              changed = true;
            }
          }

          final words = verse['words'];
          if (words is List) {
            final migratedWords = <dynamic>[];
            bool wordsChanged = false;

            for (final w in words) {
              if (w is Map) {
                final word = Map<String, dynamic>.from(w);
                final wordText = word['text_uthmani'] as String?;
                if (wordText != null) {
                  final normalizedWord = _normalizeArabicText(
                    wordText,
                    forceSajdahGlyph: forceSajdahGlyph,
                  );
                  if (normalizedWord != wordText) {
                    word['text_uthmani'] = normalizedWord;
                    wordsChanged = true;
                  }
                }
                migratedWords.add(word);
              } else {
                migratedWords.add(w);
              }
            }

            if (wordsChanged) {
              verse['words'] = migratedWords;
              changed = true;
            }
          }

          migrated.add(verse);
        }

        if (changed) {
          await _cacheBox.put(key, migrated);
          touchedAny = true;
        }
      }
    }

    if (_countAnyCachedSurahs() > 0 || touchedAny) {
      await _settingsBox.put(_syncVersionKey, _syncSchemaVersion);
    }
  }

  static String _normalizeArabicText(
    String text, {
    bool forceSajdahGlyph = false,
  }) {
    final reordered = text.replaceAllMapped(_shaddaBeforeShortVowelPattern, (match) {
      return '${match.group(1)}\u0651';
    });

    final out = StringBuffer();
    bool previousWasCanonicalMarker = false;
    for (final rune in reordered.runes) {
      if (rune == _rubElHizbRune) {
        out.write(_canonicalMarkerGlyph);
        previousWasCanonicalMarker = true;
        continue;
      }

      if (previousWasCanonicalMarker &&
          ((rune >= 0x06D6 && rune <= 0x06DC) ||
              (rune >= 0x06DF && rune <= 0x06E8) ||
              (rune >= 0x06EA && rune <= 0x06ED))) {
        continue;
      }

      out.write(String.fromCharCode(rune));
      previousWasCanonicalMarker = false;
    }
    var normalized = out.toString();
    if (forceSajdahGlyph) {
      normalized = normalized.replaceAll(_canonicalMarkerGlyph, _sajdahGlyph);
    }
    return normalized;
  }

  static List<Map<String, dynamic>> _normalizeVerseList(
    List<Map<String, dynamic>> verses,
  ) {
    final output = <Map<String, dynamic>>[];
    for (final item in verses) {
      final verse = Map<String, dynamic>.from(item);
      final forceSajdahGlyph = _isSajdahAyahVerse(verse);

      final verseText = verse['text_uthmani'] as String?;
      if (verseText != null) {
        verse['text_uthmani'] =
            _normalizeArabicText(verseText, forceSajdahGlyph: forceSajdahGlyph);
      }

      final words = verse['words'];
      if (words is List) {
        final normalizedWords = <dynamic>[];
        for (final w in words) {
          if (w is Map) {
            final word = Map<String, dynamic>.from(w);
            final wordText = word['text_uthmani'] as String?;
            if (wordText != null) {
              word['text_uthmani'] = _normalizeArabicText(
                wordText,
                forceSajdahGlyph: forceSajdahGlyph,
              );
            }
            normalizedWords.add(word);
          } else {
            normalizedWords.add(w);
          }
        }
        verse['words'] = normalizedWords;
      }

      output.add(verse);
    }
    return output;
  }

  static String _toCodepoints(String text) {
    return text.runes.map((r) => 'U+${r.toRadixString(16).toUpperCase()}').join(' ');
  }

  static bool _isSajdahAyahVerse(Map<String, dynamic> verse) {
    final key = verse['verse_key'] as String?;
    if (key != null) {
      final parts = key.split(':');
      if (parts.length == 2) {
        final surah = int.tryParse(parts[0]);
        final ayah = int.tryParse(parts[1]);
        if (surah != null && ayah != null) {
          return _sajdahAyahKeys.contains(surah * 1000 + ayah);
        }
      }
    }

    final surah = verse['chapter_id'] as int?;
    final ayah = verse['verse_number'] as int?;
    if (surah != null && ayah != null) {
      return _sajdahAyahKeys.contains(surah * 1000 + ayah);
    }
    return false;
  }

  List<String> _legacySurahKeys(int surahNumber) {
    final prefix = '${surahNumber}_';
    return _cacheBox.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList(growable: false);
  }

  List<Map<String, dynamic>>? _loadLegacySurahRaw(int surahNumber) {
    for (final key in _legacySurahKeys(surahNumber)) {
      final raw = _cacheBox.get(key);
      if (raw is List && raw.isNotEmpty) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    }
    return null;
  }
}
