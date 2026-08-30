import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/reader/mushaf_page_view.dart';

void main() {
  testWidgets('opening pages expose overflowing bottom lines to scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ayahs = List.generate(
      15,
      (index) => Ayah(
        surahNumber: 1,
        ayahNumber: index + 1,
        pageNumber: 1,
        juzNumber: 1,
        arabic: 'كَلِمَةٌ',
        translations: const {},
        words: [
          TajweedWord(
            arabic: 'كَلِمَةٌ',
            spans: const [],
            lineNumber: index + 1,
          ),
        ],
        endLineNumber: index + 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MushafPageContent(
            pageNumber: 1,
            ayahs: ayahs,
            isLandscape: false,
            textScale: 1,
            highlightEnabled: true,
            surahNameFor: (_) => 'الفاتحة',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mushaf-line-15')), findsOneWidget);
  });
}
