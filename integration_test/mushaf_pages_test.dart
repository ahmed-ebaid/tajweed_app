import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';
import 'package:tajweed_practice/features/reader/mushaf_page_view.dart';

/// Renders Mushaf page data through the same Quran Foundation backend proxy path
/// used by the app, then captures screenshots for printed-page comparison.
const _configuredPages = String.fromEnvironment('MUSHAF_TEST_PAGES');
final _pages = _configuredPages.isEmpty
    ? <int>[1, 2, 251, 255, 300, 528, 600, 604]
    : _configuredPages.split(',').map(int.parse).toList(growable: false);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final api = QuranApiService();

  testWidgets(
    'capture Mushaf pages in portrait and landscape',
    (tester) async {
      for (final page in _pages) {
        final ayahs = await _fetchPage(api, page);
        expect(ayahs, isNotEmpty, reason: 'page $page returned no verses');

        for (final key in ayahs.map(
          (a) => '${a.surahNumber}:${a.ayahNumber}',
        )) {
          expect(
            ayahs
                .where((a) => '${a.surahNumber}:${a.ayahNumber}' == key)
                .length,
            1,
            reason: 'duplicate verse $key on page $page',
          );
        }
        for (final ayah in ayahs) {
          expect(
            ayah.pageNumber,
            page,
            reason:
                '${ayah.surahNumber}:${ayah.ayahNumber} is not on page $page',
          );
        }

        for (final orientation in const [
          (name: 'portrait', size: Size(430, 932), landscape: false),
          (name: 'landscape', size: Size(932, 430), landscape: true),
        ]) {
          await tester.binding.setSurfaceSize(orientation.size);
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: const Color(0xFFFFFCF3),
                appBar: AppBar(
                  title: const Text('Mushaf'),
                  actions: const [
                    Icon(Icons.chrome_reader_mode_outlined),
                    Icon(Icons.bookmark_border_rounded),
                    Icon(Icons.play_circle_outline),
                    Icon(Icons.palette_outlined),
                    Icon(Icons.settings_outlined),
                  ],
                ),
                body: MushafPageContent(
                  pageNumber: page,
                  ayahs: ayahs,
                  isLandscape: orientation.landscape,
                  textScale: 1,
                  highlightEnabled: true,
                  surahNameFor: (surah) => 'سورة $surah',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'page $page ${orientation.name} raised a layout error',
          );
          final contentRect = tester.getRect(
            find.byKey(const ValueKey('mushaf-content-region')),
          );
          final lastLine = find.byKey(const ValueKey('mushaf-line-15'));
          await tester.ensureVisible(lastLine);
          await tester.pumpAndSettle();
          final lastLineRect = tester.getRect(lastLine);
          expect(
            lastLineRect.bottom,
            lessThanOrEqualTo(contentRect.bottom + 0.5),
            reason:
                'page $page ${orientation.name} cannot scroll to Mushaf line 15',
          );

          await binding.takeScreenshot(
            'mushaf-${page.toString().padLeft(3, '0')}-${orientation.name}',
          );
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<List<Ayah>> _fetchPage(QuranApiService api, int page) async {
  final verses = await api.fetchVersesByPage(pageNumber: page, langCode: 'ar');
  return AyahMapper.fromApiList(verses, requestedLangCode: 'ar');
}
