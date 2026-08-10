import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'audio_cache_service.dart';
import 'quran_api_service.dart';

class QuranContentSyncService {
  static const _cacheBoxKey = 'verse_cache';
  static const _audioBoxKey = 'audio_cache';
  static const _settingsBoxKey = 'settings';
  static const _resourceFilterKey = 'qf_content_sync_resource_filter';
  static const _syncTokenKey = 'qf_content_sync_token';
  static const _lastValidatedAtKey = 'qf_content_sync_validated_at';
  static const _lastAttemptAtKey = 'qf_content_sync_attempted_at';
  static const _failureCountKey = 'qf_content_sync_failure_count';
  static const _lastErrorKey = 'qf_content_sync_last_error';
  static const _validationInterval = Duration(days: 7);
  static const _supportedGroups = {
    'translations',
    'tafsirs',
    'recitations',
  };

  final QuranApiService _api;
  final Box _cacheBox;
  final Box _audioBox;
  final Box _settingsBox;
  final DateTime Function() _now;
  final Future<void> Function(int) _clearReciter;
  final Duration Function(int) _backoffForAttempt;
  static Future<void>? _activeSync;

  QuranContentSyncService({
    QuranApiService? api,
    Box? cacheBox,
    Box? audioBox,
    Box? settingsBox,
    DateTime Function()? now,
    Future<void> Function(int)? clearReciter,
    Duration Function(int)? backoffForAttempt,
  })  : _api = api ?? QuranApiService(),
        _cacheBox = cacheBox ?? Hive.box(_cacheBoxKey),
        _audioBox = audioBox ?? Hive.box(_audioBoxKey),
        _settingsBox = settingsBox ?? Hive.box(_settingsBoxKey),
        _now = now ?? DateTime.now,
        _clearReciter = clearReciter ?? AudioCacheService().clearReciter,
        _backoffForAttempt = backoffForAttempt ?? _defaultBackoff;

  DateTime? get lastValidatedAt => _readDate(_lastValidatedAtKey);

  bool get isValidationDue {
    final resources = _discoverResources();
    if (resources.isNotEmpty &&
        _settingsBox.get(_resourceFilterKey) != _canonicalFilter(resources)) {
      return true;
    }
    final validatedAt = lastValidatedAt;
    return validatedAt == null ||
        !_now().isBefore(validatedAt.add(_validationInterval));
  }

  Map<String, String> getCachedRecitationMap({
    required int reciterId,
    required int surahNumber,
  }) {
    final raw = _cacheBox.get(
      'qf_recitation_${reciterId}_surah_$surahNumber',
    );
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  Future<void> cacheRecitationMap({
    required int reciterId,
    required int surahNumber,
    required Map<String, String> audioUrls,
  }) async {
    final current = _activeSync;
    if (current != null) await current;
    final records = _readResource('recitations', reciterId)
      ..removeWhere(
        (record) => _surahFromVerseKey(_verseKey(record)) == surahNumber,
      )
      ..addAll(
        audioUrls.entries.map(
          (entry) => {
            'id': entry.key,
            'verse_key': entry.key,
            'url': entry.value,
            'resource_id': reciterId,
          },
        ),
      );
    await _replaceResource(
      'recitations',
      reciterId,
      records,
      invalidateAudio: false,
    );
  }

  Future<void> syncIfDue({bool ignoreBackoff = false}) {
    final current = _activeSync;
    if (current != null) return current;
    if (!isValidationDue) return Future.value();
    if (!ignoreBackoff && !_backoffElapsed()) return Future.value();

    final sync = _sync().whenComplete(() => _activeSync = null);
    _activeSync = sync;
    return sync;
  }

  Future<void> _sync() async {
    final now = _now();
    await _settingsBox.put(
      _lastAttemptAtKey,
      now.millisecondsSinceEpoch,
    );

    try {
      final resources = _discoverResources();
      if (resources.isEmpty) {
        await _markSuccess(now);
        return;
      }

      final resourceFilter = _canonicalFilter(resources);
      final storedFilter = _settingsBox.get(_resourceFilterKey) as String?;
      var syncToken = storedFilter == resourceFilter
          ? _settingsBox.get(_syncTokenKey) as String?
          : null;

      try {
        if (syncToken == null) {
          await _bootstrapResources(resources);
        }
        syncToken = await _consumePages(
          resources: resourceFilter,
          syncToken: syncToken,
        );
      } on DioException catch (error) {
        if (error.response?.statusCode != 410) rethrow;
        await _bootstrapResources(resources);
        syncToken = await _consumePages(
          resources: resourceFilter,
          syncToken: null,
        );
      }

      await _settingsBox.putAll({
        _resourceFilterKey: resourceFilter,
        _syncTokenKey: syncToken,
      });
      await _markSuccess(now);
    } catch (error) {
      final failures =
          (_settingsBox.get(_failureCountKey, defaultValue: 0) as int) + 1;
      await _settingsBox.putAll({
        _failureCountKey: failures,
        _lastErrorKey: error.toString(),
      });
      rethrow;
    }
  }

  Future<void> _bootstrapResources(Set<_Resource> resources) async {
    final ordered = resources.toList()
      ..sort((a, b) {
        final groupComparison = a.group.compareTo(b.group);
        return groupComparison != 0 ? groupComparison : a.id.compareTo(b.id);
      });
    for (final resource in ordered) {
      final snapshot = await _api.fetchContentSnapshot(
        resourceGroup: resource.group,
        resourceId: resource.id,
      );
      if (snapshot.resourceGroup != resource.group ||
          snapshot.resourceId != resource.id) {
        throw const FormatException(
          'Content snapshot does not match its requested resource',
        );
      }
      await _replaceResource(
        resource.group,
        resource.id,
        snapshot.records,
        invalidateAudio: false,
      );
    }
  }

  Future<String> _consumePages({
    required String resources,
    required String? syncToken,
  }) async {
    String? nextPageUrl;
    String? finalToken;
    var pageCount = 0;

    do {
      if (++pageCount > 1000) {
        throw StateError('Content Sync exceeded the page limit');
      }
      final page = await _api.fetchContentSyncPage(
        resources: resources,
        syncToken: syncToken,
        nextPageUrl: nextPageUrl,
      );
      for (final mutation in page.mutations) {
        await _applyMutation(mutation);
      }
      nextPageUrl = page.hasMore ? page.nextPageUrl : null;
      if (page.hasMore && nextPageUrl == null) {
        throw const FormatException(
          'Content Sync omitted the next-page URL',
        );
      }
      if (!page.hasMore) finalToken = page.nextSyncToken;
    } while (nextPageUrl != null);

    if (finalToken == null || finalToken.isEmpty) {
      throw const FormatException('Content Sync omitted its final token');
    }
    return finalToken;
  }

  Future<void> _applyMutation(QuranContentMutation mutation) async {
    if (!_supportedGroups.contains(mutation.resourceGroup)) {
      throw StateError(
        'Unsupported Content Sync group: ${mutation.resourceGroup}',
      );
    }

    switch (mutation.type) {
      case 'RESOURCE_CREATE':
      case 'RESOURCE_INVALIDATE':
        final snapshot = await _api.fetchContentSnapshot(
          resourceGroup: mutation.resourceGroup,
          resourceId: mutation.resourceId,
        );
        if (snapshot.resourceGroup != mutation.resourceGroup ||
            snapshot.resourceId != mutation.resourceId) {
          throw const FormatException(
            'Content snapshot does not match its mutation',
          );
        }
        await _replaceResource(
          mutation.resourceGroup,
          mutation.resourceId,
          snapshot.records,
          invalidateAudio: mutation.type == 'RESOURCE_INVALIDATE',
        );
        return;
      case 'RESOURCE_DELETE':
        await _deleteResource(
          mutation.resourceGroup,
          mutation.resourceId,
        );
        return;
      case 'ROW_CREATE':
      case 'ROW_UPDATE':
        final data = mutation.data;
        if (data == null) {
          throw const FormatException('Content Sync row has no data');
        }
        await _upsertRow(
          mutation.resourceGroup,
          mutation.resourceId,
          mutation.recordKey,
          data,
        );
        return;
      case 'ROW_DELETE':
        final recordKey = mutation.recordKey;
        if (recordKey == null || recordKey.isEmpty) {
          throw const FormatException(
            'Content Sync row delete has no record key',
          );
        }
        await _deleteRow(
          mutation.resourceGroup,
          mutation.resourceId,
          recordKey,
        );
        return;
      case 'RESOURCE_UPDATE':
        return;
      default:
        throw StateError(
          'Unsupported Content Sync mutation: ${mutation.type}',
        );
    }
  }

  Future<void> _replaceResource(
    String group,
    int resourceId,
    List<Map<String, dynamic>> records, {
    required bool invalidateAudio,
  }) async {
    final normalized = records
        .map(
          (record) => {
            ...record,
            'resource_id': resourceId,
          },
        )
        .toList(growable: false);
    final updates = _derivedUpdates(group, resourceId, normalized);
    updates[_resourceCacheKey(group, resourceId)] = normalized;
    await _cacheBox.putAll(updates);

    if (group == 'recitations' && invalidateAudio) {
      await _clearReciter(resourceId);
    }
  }

  Future<void> _deleteResource(String group, int resourceId) async {
    if (group == 'translations') {
      await _cacheBox.putAll(
        _translationUpdates(resourceId, const []),
      );
    } else {
      final prefix = group == 'tafsirs'
          ? 'tafsir_${resourceId}_surah_'
          : 'qf_recitation_${resourceId}_surah_';
      final keys = _cacheBox.keys
          .whereType<String>()
          .where((key) => key.startsWith(prefix))
          .toList(growable: false);
      await _cacheBox.deleteAll(keys);
    }
    await _cacheBox.delete(_resourceCacheKey(group, resourceId));
    if (group == 'recitations') {
      await _clearReciter(resourceId);
    }
  }

  Future<void> _upsertRow(
    String group,
    int resourceId,
    String? recordKey,
    Map<String, dynamic> data,
  ) async {
    final records = _readResource(group, resourceId);
    final normalized = {
      ...data,
      'resource_id': resourceId,
    };
    final targetKey = recordKey ?? _recordKey(normalized);
    if (targetKey == null || targetKey.isEmpty) {
      throw const FormatException('Content Sync row has no stable key');
    }
    records.removeWhere((record) => _recordKey(record) == targetKey);
    records.add(normalized);
    await _replaceResource(
      group,
      resourceId,
      records,
      invalidateAudio: group == 'recitations',
    );
  }

  Future<void> _deleteRow(
    String group,
    int resourceId,
    String recordKey,
  ) async {
    final records = _readResource(group, resourceId);
    records.removeWhere((record) => _recordKey(record) == recordKey);
    await _replaceResource(
      group,
      resourceId,
      records,
      invalidateAudio: group == 'recitations',
    );
  }

  Map<dynamic, dynamic> _derivedUpdates(
    String group,
    int resourceId,
    List<Map<String, dynamic>> records,
  ) {
    return switch (group) {
      'translations' => _translationUpdates(resourceId, records),
      'tafsirs' => _tafsirUpdates(resourceId, records),
      'recitations' => _recitationUpdates(resourceId, records),
      _ => throw StateError('Unsupported Content Sync group: $group'),
    };
  }

  Map<dynamic, dynamic> _translationUpdates(
    int resourceId,
    List<Map<String, dynamic>> records,
  ) {
    final recordsByVerse = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final verseKey = _verseKey(record);
      if (verseKey != null) recordsByVerse[verseKey] = record;
    }
    final updates = <dynamic, dynamic>{};
    for (final key in _verseCacheKeys()) {
      final rawVerses = _cacheBox.get(key);
      if (rawVerses is! List) continue;
      final verses = rawVerses.whereType<Map>().map((rawVerse) {
        final verse = Map<String, dynamic>.from(rawVerse);
        final translations = (verse['translations'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['resource_id'] != resourceId)
            .toList();
        final replacement = recordsByVerse[verse['verse_key']?.toString()];
        if (replacement != null) translations.add(replacement);
        verse['translations'] = translations;
        return verse;
      }).toList(growable: false);
      updates[key] = verses;
    }
    return updates;
  }

  Map<dynamic, dynamic> _tafsirUpdates(
    int resourceId,
    List<Map<String, dynamic>> records,
  ) {
    final bySurah = <int, Map<String, String>>{};
    for (final record in records) {
      final verseKey = _verseKey(record);
      final surah = _surahFromVerseKey(verseKey);
      final text = record['text']?.toString();
      if (verseKey == null || surah == null || text == null) continue;
      bySurah.putIfAbsent(surah, () => {})[verseKey] = text;
    }

    final existingSurahs = _cacheBox.keys
        .whereType<String>()
        .map(
          (key) => RegExp(
            '^tafsir_${resourceId}_surah_(\\d+)\$',
          ).firstMatch(key),
        )
        .whereType<RegExpMatch>()
        .map((match) => int.parse(match.group(1)!));
    final surahs = {...existingSurahs, ...bySurah.keys};
    return {
      for (final surah in surahs)
        'tafsir_${resourceId}_surah_$surah':
            bySurah[surah] ?? <String, String>{},
    };
  }

  Map<dynamic, dynamic> _recitationUpdates(
    int resourceId,
    List<Map<String, dynamic>> records,
  ) {
    final bySurah = <int, Map<String, String>>{};
    for (final record in records) {
      final verseKey = _verseKey(record);
      final surah = _surahFromVerseKey(verseKey);
      final url = record['url']?.toString();
      if (verseKey == null || surah == null || url == null || url.isEmpty) {
        continue;
      }
      bySurah.putIfAbsent(surah, () => {})[verseKey] = url;
    }

    final existingSurahs = _cacheBox.keys
        .whereType<String>()
        .map(
          (key) => RegExp(
            '^qf_recitation_${resourceId}_surah_(\\d+)\$',
          ).firstMatch(key),
        )
        .whereType<RegExpMatch>()
        .map((match) => int.parse(match.group(1)!));
    final surahs = {...existingSurahs, ...bySurah.keys};
    return {
      for (final surah in surahs)
        'qf_recitation_${resourceId}_surah_$surah':
            bySurah[surah] ?? <String, String>{},
    };
  }

  Set<_Resource> _discoverResources() {
    final resources = <_Resource>{};
    for (final key in _verseCacheKeys()) {
      final rawVerses = _cacheBox.get(key);
      if (rawVerses is! List) continue;
      for (final rawVerse in rawVerses.whereType<Map>()) {
        final translations = rawVerse['translations'];
        if (translations is! List) continue;
        for (final rawTranslation in translations.whereType<Map>()) {
          final id = rawTranslation['resource_id'];
          if (id is int) resources.add(_Resource('translations', id));
        }
      }
    }

    for (final key in _cacheBox.keys.whereType<String>()) {
      final tafsirMatch = RegExp(r'^tafsir_(\d+)_surah_\d+$').firstMatch(key);
      if (tafsirMatch != null) {
        resources.add(
          _Resource('tafsirs', int.parse(tafsirMatch.group(1)!)),
        );
      }
      final rawMatch =
          RegExp(r'^qf_resource_(translations|tafsirs|recitations)_(\d+)$')
              .firstMatch(key);
      if (rawMatch != null) {
        resources.add(
          _Resource(rawMatch.group(1)!, int.parse(rawMatch.group(2)!)),
        );
      }
      final recitationMatch =
          RegExp(r'^qf_recitation_(\d+)_surah_\d+$').firstMatch(key);
      if (recitationMatch != null) {
        resources.add(
          _Resource('recitations', int.parse(recitationMatch.group(1)!)),
        );
      }
    }

    for (final key in _audioBox.keys.whereType<String>()) {
      final match = RegExp(r'^(?:meta_)?r(\d+)_s\d+').firstMatch(key);
      if (match != null) {
        resources.add(
          _Resource('recitations', int.parse(match.group(1)!)),
        );
      }
    }
    return resources;
  }

  Iterable<String> _verseCacheKeys() =>
      _cacheBox.keys.whereType<String>().where(
            (key) =>
                RegExp(r'^quran_(?:ar|tajweed)_surah_\d+$').hasMatch(key) ||
                RegExp(r'^\d+_[a-z-]+$').hasMatch(key),
          );

  List<Map<String, dynamic>> _readResource(String group, int resourceId) {
    final raw = _cacheBox.get(_resourceCacheKey(group, resourceId));
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .toList();
  }

  String _canonicalFilter(Set<_Resource> resources) {
    final grouped = <String, List<int>>{};
    for (final resource in resources) {
      grouped.putIfAbsent(resource.group, () => []).add(resource.id);
    }
    return _supportedGroups.where(grouped.containsKey).map((group) {
      final ids = grouped[group]!..sort();
      return '$group:${ids.join(',')}';
    }).join(';');
  }

  bool _backoffElapsed() {
    final lastAttempt = _readDate(_lastAttemptAtKey);
    final failures = _settingsBox.get(_failureCountKey, defaultValue: 0) as int;
    if (lastAttempt == null || failures == 0) return true;
    return !_now().isBefore(
      lastAttempt.add(_backoffForAttempt(failures)),
    );
  }

  Future<void> _markSuccess(DateTime now) async {
    await _settingsBox.putAll({
      _lastValidatedAtKey: now.millisecondsSinceEpoch,
      _failureCountKey: 0,
    });
    await _settingsBox.delete(_lastErrorKey);
  }

  DateTime? _readDate(String key) {
    final value = _settingsBox.get(key);
    return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
  }

  static Duration _defaultBackoff(int attempt) {
    const baseMinutes = [5, 30, 120, 720, 1440];
    final base = baseMinutes[min(attempt - 1, baseMinutes.length - 1)];
    final jitter = Random().nextInt(max(1, base ~/ 5));
    return Duration(minutes: base + jitter);
  }

  static String _resourceCacheKey(String group, int id) =>
      'qf_resource_${group}_$id';

  static String? _recordKey(Map<String, dynamic> record) =>
      record['id']?.toString() ?? record['record_key']?.toString();

  static String? _verseKey(Map<String, dynamic> record) {
    final direct = record['verse_key'];
    if (direct != null) return direct.toString();
    final verse = record['verse'];
    return verse is Map ? verse['verse_key']?.toString() : null;
  }

  static int? _surahFromVerseKey(String? verseKey) =>
      verseKey == null ? null : int.tryParse(verseKey.split(':').first);
}

class _Resource {
  final String group;
  final int id;

  const _Resource(this.group, this.id);

  @override
  bool operator ==(Object other) =>
      other is _Resource && other.group == group && other.id == id;

  @override
  int get hashCode => Object.hash(group, id);
}
