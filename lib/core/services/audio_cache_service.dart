import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class AudioCacheService {
  static const _boxKey = 'audio_cache';
  final Dio _dio = Dio();

  Future<String?> getCachedAyahPath({
    required int reciterId,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final box = Hive.box(_boxKey);
    final key = _ayahKey(reciterId, surahNumber, ayahNumber);
    final path = box.get(key) as String?;
    if (path == null || path.isEmpty) return null;

    final f = File(path);
    return f.existsSync() ? path : null;
  }

  Future<int> getDownloadedCountForSurah({
    required int reciterId,
    required int surahNumber,
  }) async {
    final box = Hive.box(_boxKey);
    var count = 0;
    for (final k in box.keys) {
      if (k is! String) continue;
      if (k.startsWith('r${reciterId}_s${surahNumber}_a')) {
        final p = box.get(k) as String?;
        if (p == null) continue;
        if (File(p).existsSync()) count++;
      }
    }
    return count;
  }

  Future<void> clearReciter(int reciterId) async {
    final box = Hive.box(_boxKey);
    final keys = box.keys
        .whereType<String>()
        .where(
          (key) =>
              key.startsWith('r${reciterId}_') ||
              key.startsWith('meta_r${reciterId}_'),
        )
        .toList(growable: false);

    for (final key in keys) {
      final path = box.get(key);
      if (path is String && path.isNotEmpty) {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    }
    await box.deleteAll(keys);
  }

  Future<void> downloadSurah({
    required int reciterId,
    required int surahNumber,
    required Map<String, String> audioUrls,
    required void Function(int done, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final surahDir = Directory(
      '${dir.path}/audio_cache/r$reciterId/s$surahNumber',
    );
    if (!surahDir.existsSync()) {
      surahDir.createSync(recursive: true);
    }

    final entries =
        audioUrls.entries
            .where((e) => e.key.startsWith('$surahNumber:'))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    final total = entries.length;
    var done = 0;
    onProgress(done, total);

    final box = Hive.box(_boxKey);
    for (final e in entries) {
      final verseParts = e.key.split(':');
      if (verseParts.length != 2) continue;
      final ayah = int.tryParse(verseParts[1]);
      if (ayah == null) continue;

      final filePath = '${surahDir.path}/$ayah.mp3';
      final file = File(filePath);

      if (!file.existsSync() || file.lengthSync() == 0) {
        if (file.existsSync()) await file.delete();
        final raw = e.value;
        final url = raw.startsWith('http')
            ? raw
            : 'https://verses.quran.com/$raw';
        final partial = File('$filePath.part');
        if (partial.existsSync()) await partial.delete();
        try {
          await _dio.download(url, partial.path, cancelToken: cancelToken);
          if (!partial.existsSync() || partial.lengthSync() == 0) {
            throw StateError('Downloaded audio is empty for ${e.key}.');
          }
          await partial.rename(filePath);
        } catch (_) {
          if (partial.existsSync()) await partial.delete();
          rethrow;
        }
      }

      await box.put(_ayahKey(reciterId, surahNumber, ayah), filePath);
      done++;
      onProgress(done, total);
    }

    await box.put(_surahMetaKey(reciterId, surahNumber), {
      'downloaded': done,
      'total': total,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  String _ayahKey(int reciterId, int surahNumber, int ayahNumber) =>
      'r${reciterId}_s${surahNumber}_a$ayahNumber';

  String _surahMetaKey(int reciterId, int surahNumber) =>
      'meta_r${reciterId}_s$surahNumber';
}
