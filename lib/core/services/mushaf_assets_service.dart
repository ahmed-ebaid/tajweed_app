import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

class MushafAssetsService {
  /// URL to the pages.zip hosted on GitHub Releases.
  /// Upload /tmp/pages.zip to a GitHub release and paste the asset URL here.
  static const String pagesZipUrl =
      'https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.0/pages.zip';

  static const String _unzipDirName = 'mushaf_pages';

  /// Returns the directory containing extracted page images.
  /// On first call downloads and extracts pages.zip from [pagesZipUrl].
  /// [onProgress] receives (bytesReceived, totalBytes) during download.
  static Future<Directory> getMushafPagesDir({
    void Function(int received, int total)? onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mushafDir = Directory('${docsDir.path}/$_unzipDirName');

    if (await mushafDir.exists()) return mushafDir;

    await _downloadAndExtract(mushafDir, onProgress: onProgress);
    return mushafDir;
  }

  /// Returns the asset path for a given page number.
  static Future<String> getPagePath(int pageNumber) async {
    final dir = await getMushafPagesDir();
    return '${dir.path}/tajweed/$pageNumber.webp';
  }

  static Future<void> _downloadAndExtract(
    Directory targetDir, {
    void Function(int received, int total)? onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tempZip = File('${docsDir.path}/pages_download.zip');

    try {
      // Download zip
      final dio = Dio();
      await dio.download(
        pagesZipUrl,
        tempZip.path,
        onReceiveProgress: onProgress,
        options: Options(responseType: ResponseType.bytes),
      );

      // Extract zip to target directory
      await targetDir.create(recursive: true);
      await extractFileToDisk(tempZip.path, targetDir.parent.path);
    } finally {
      if (await tempZip.exists()) await tempZip.delete();
    }
  }

  /// Delete extracted pages (e.g. to force a re-download).
  static Future<void> clearMushafPages() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mushafDir = Directory('${docsDir.path}/$_unzipDirName');
    if (await mushafDir.exists()) await mushafDir.delete(recursive: true);
  }
}
