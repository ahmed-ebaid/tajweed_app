import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

class MushafAssetsStatus {
  final bool installed;
  final int pageCount;
  final String? rootPath;

  const MushafAssetsStatus({
    required this.installed,
    required this.pageCount,
    required this.rootPath,
  });
}

class MushafAssetsService {
  /// URL to the pages.zip hosted on GitHub Releases.
  /// Upload /tmp/pages.zip to a GitHub release and paste the asset URL here.
  static const String pagesZipUrl =
      'https://github.com/ahmed-ebaid/tajweed_app/releases/download/v1.0.0-assets/images.zip';

  static const String _unzipDirName = 'mushaf_pages';
  static const int expectedPageCount = 604;

  /// Returns the directory containing extracted page images.
  /// On first call downloads and extracts pages.zip from [pagesZipUrl].
  /// [onProgress] receives (bytesReceived, totalBytes) during download.
  static Future<Directory> getMushafPagesDir({
    void Function(int received, int total)? onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mushafDir = Directory('${docsDir.path}/$_unzipDirName');

    final hasCompleteSet = await _hasCompletePageSet(mushafDir);
    if (hasCompleteSet) return mushafDir;

    if (await mushafDir.exists()) {
      await mushafDir.delete(recursive: true);
    }

    await _downloadAndExtract(mushafDir, onProgress: onProgress);
    return mushafDir;
  }

  /// Returns the local file path for a given page number.
  static Future<String> getPagePath(int pageNumber) async {
    final dir = await getMushafPagesDir();
    return _pagePathFor(dir.path, pageNumber);
  }

  /// Forces a full refresh of downloaded pages.
  static Future<Directory> forceRedownload({
    void Function(int received, int total)? onProgress,
  }) async {
    await clearMushafPages();
    return getMushafPagesDir(onProgress: onProgress);
  }

  /// Returns current install status for settings/debug UI.
  static Future<MushafAssetsStatus> getStatus() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mushafDir = Directory('${docsDir.path}/$_unzipDirName');
    if (!await mushafDir.exists()) {
      return const MushafAssetsStatus(
          installed: false, pageCount: 0, rootPath: null);
    }

    final pageCount = await _countPageImages(mushafDir);
    final hasCompleteSet = await _hasCompletePageSet(mushafDir);
    return MushafAssetsStatus(
      installed: hasCompleteSet,
      pageCount: pageCount,
      rootPath: mushafDir.path,
    );
  }

  static Future<void> _downloadAndExtract(
    Directory targetDir, {
    void Function(int received, int total)? onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tempZip = File('${docsDir.path}/pages_download.zip');
    final extractDir = Directory(
        '${docsDir.path}/mushaf_extract_tmp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}');

    try {
      // Download zip
      final dio = Dio();
      await dio.download(
        pagesZipUrl,
        tempZip.path,
        onReceiveProgress: onProgress,
        options: Options(responseType: ResponseType.bytes),
      );

      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }

      await extractDir.create(recursive: true);
      await extractFileToDisk(tempZip.path, extractDir.path);

      // The current zip contains images/*.png.
      final extractedImagesDir = Directory('${extractDir.path}/images');
      if (await extractedImagesDir.exists()) {
        await targetDir.create(recursive: true);
        await extractedImagesDir.rename('${targetDir.path}/images');
      } else {
        // Fallback: some packs may already contain the final folder shape.
        await extractFileToDisk(tempZip.path, targetDir.path);
      }

      final count = await _countPageImages(targetDir);
      if (count < expectedPageCount) {
        throw StateError('Downloaded pack is incomplete: $count pages');
      }
    } finally {
      if (await tempZip.exists()) await tempZip.delete();
      if (await extractDir.exists()) await extractDir.delete(recursive: true);
    }
  }

  static String _pagePathFor(String rootPath, int pageNumber) {
    return '$rootPath/images/$pageNumber.png';
  }

  static Future<int> _countPageImages(Directory mushafDir) async {
    final imagesDir = Directory('${mushafDir.path}/images');
    if (!await imagesDir.exists()) return 0;

    var count = 0;
    await for (final entity in imagesDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (name.endsWith('.png')) count++;
    }
    return count;
  }

  static Future<bool> _hasCompletePageSet(Directory mushafDir) async {
    final rootPath = mushafDir.path;
    for (int page = 1; page <= expectedPageCount; page++) {
      if (_resolveExistingPagePath(rootPath, page) == null) return false;
    }
    return true;
  }

  static String? _resolveExistingPagePath(String rootPath, int pageNumber) {
    final plain = '$rootPath/images/$pageNumber.png';
    if (File(plain).existsSync()) return plain;

    final padded = pageNumber.toString().padLeft(3, '0');
    final paddedOnly = '$rootPath/images/$padded.png';
    if (File(paddedOnly).existsSync()) return paddedOnly;

    final pagePrefixed = '$rootPath/images/page$padded.png';
    if (File(pagePrefixed).existsSync()) return pagePrefixed;

    return null;
  }

  /// Delete extracted pages (e.g. to force a re-download).
  static Future<void> clearMushafPages() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mushafDir = Directory('${docsDir.path}/$_unzipDirName');
    if (await mushafDir.exists()) await mushafDir.delete(recursive: true);
  }
}
