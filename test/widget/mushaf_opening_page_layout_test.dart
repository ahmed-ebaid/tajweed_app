import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/reader/mushaf_page_view.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('AmiriQuran')
      ..addFont(rootBundle.load('assets/fonts/AmiriQuran.ttf'));
    await font.load();
  });

  for (final firstTextLine in [1, 2, 3]) {
    testWidgets(
      'opening decorations never replace printed line $firstTextLine',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MushafPageContent(
                pageNumber: 591,
                ayahs: [
                  Ayah(
                    surahNumber: 86,
                    ayahNumber: 1,
                    pageNumber: 591,
                    arabic: 'وَالسَّمَاءِ وَالطَّارِقِ',
                    translations: const {},
                    words: [
                      TajweedWord(
                        arabic: 'وَالسَّمَاءِ',
                        spans: const [],
                        lineNumber: firstTextLine,
                      ),
                      TajweedWord(
                        arabic: 'وَالطَّارِقِ',
                        spans: const [],
                        lineNumber: firstTextLine,
                      ),
                    ],
                    endLineNumber: firstTextLine,
                  ),
                ],
                isLandscape: false,
                textScale: 1,
                highlightEnabled: true,
                surahNameFor: (_) => 'الطارق',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final line = find.byKey(ValueKey('mushaf-line-$firstTextLine'));
        final expectedWord = TextSpan(
          children: TajweedText.buildStyledWordSpans(
            const TajweedWord(arabic: 'وَالسَّمَاءِ', spans: []),
            baseStyle: const TextStyle(),
          ),
        ).toPlainText();
        expect(
          find.descendant(
            of: line,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  (widget.textSpan?.toPlainText().contains(expectedWord) ??
                      false),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
          firstTextLine > 1 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('mushaf-surah-cartouche')),
          firstTextLine == 3 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('fixed lines share one font size and do not stretch vertically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MushafPageContent(
            pageNumber: 22,
            ayahs: [
              for (var line = 1; line <= 15; line++)
                Ayah(
                  surahNumber: 2,
                  ayahNumber: line + 141,
                  pageNumber: 22,
                  arabic: 'كَلِمَةٌ',
                  translations: const {},
                  words: [
                    for (var word = 0; word < (line.isEven ? 8 : 6); word++)
                      TajweedWord(
                        arabic: 'كَلِمَةٌ',
                        spans: const [],
                        lineNumber: line,
                      ),
                  ],
                  endLineNumber: line,
                ),
            ],
            isLandscape: false,
            textScale: 1,
            highlightEnabled: true,
            surahNameFor: (_) => 'البقرة',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sizes = <double>[];
    for (var line = 1; line <= 15; line++) {
      final words = find.descendant(
        of: find.byKey(ValueKey('mushaf-line-$line')),
        matching: find.byType(Text),
      );
      for (final element in words.evaluate()) {
        final text = element.widget as Text;
        final box = element.renderObject! as RenderBox;
        final scale = box.getTransformTo(null).getColumn(0).length;
        final fontSize = (text.textSpan! as TextSpan).style!.fontSize!;
        sizes.add(text.textScaler!.scale(fontSize) * scale);
      }
    }
    expect(sizes.every((size) => (size - sizes.first).abs() < 0.01), isTrue);
    final row = tester.getRect(find.byKey(const ValueKey('mushaf-line-1')));
    expect(row.height, lessThanOrEqualTo(sizes.first * 2.2 + 4.01));
    final region = tester.getRect(
      find.byKey(const ValueKey('mushaf-content-region')),
    );
    final last = tester.getRect(find.byKey(const ValueKey('mushaf-line-15')));
    expect(last.bottom, lessThanOrEqualTo(region.bottom));
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .maxScrollExtent,
      closeTo(0, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Al-Fajr page 593 includes ayah 23 in the fitted viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Quran.Foundation page 593 word lines and end-token lines.
    const positions = [
      ([3], 3),
      ([3, 3], 3),
      ([3, 3], 3),
      ([3, 3, 3], 4),
      ([4, 4, 4, 4, 4, 4], 4),
      ([4, 4, 4, 4, 4, 4], 5),
      ([5, 5, 5], 5),
      ([5, 5, 5, 5, 5, 5], 5),
      ([6, 6, 6, 6, 6], 6),
      ([6, 6, 6], 6),
      ([7, 7, 7, 7], 7),
      ([7, 7, 7], 7),
      ([7, 8, 8, 8, 8], 8),
      ([8, 8, 8], 8),
      ([8, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9], 10),
      ([10, 10, 10, 10, 10, 10, 10, 10, 10, 10], 10),
      ([11, 11, 11, 11, 11], 11),
      ([11, 11, 11, 11, 12], 12),
      ([12, 12, 12, 12], 12),
      ([13, 13, 13, 13], 13),
      ([13, 13, 13, 13, 13, 14], 14),
      ([14, 14, 14, 14, 14], 14),
      ([14, 14, 15, 15, 15, 15, 15, 15, 15], 15),
    ];
    final ayahs = [
      for (var index = 0; index < positions.length; index++)
        Ayah(
          surahNumber: 89,
          ayahNumber: index + 1,
          pageNumber: 593,
          juzNumber: 30,
          arabic: 'كَلِمَةٌ',
          translations: const {},
          words: [
            for (final line in positions[index].$1)
              TajweedWord(
                arabic: 'كَلِمَةٌ',
                spans: const [],
                lineNumber: line,
              ),
          ],
          endLineNumber: positions[index].$2,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: MushafPageContent(
            pageNumber: 593,
            ayahs: ayahs,
            isLandscape: false,
            textScale: 1,
            highlightEnabled: true,
            fitToViewport: true,
            surahNameFor: (_) => 'الفجر',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final region = tester.getRect(
      find.byKey(const ValueKey('mushaf-content-region')),
    );
    final lastLine = find.byKey(const ValueKey('mushaf-line-15'));
    expect(tester.getRect(lastLine).bottom, lessThanOrEqualTo(region.bottom));
    expect(
      find.descendant(
        of: lastLine,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.textSpan?.toPlainText().contains('\u06DD٢٣') ?? false),
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .maxScrollExtent,
      closeTo(0, 0.01),
    );
    final expectedLines = <int, List<String>>{};
    for (var index = 0; index < positions.length; index++) {
      for (final line in positions[index].$1) {
        expectedLines.putIfAbsent(line, () => []).add('كَلِمَةٌ');
      }
      final digits = (index + 1)
          .toString()
          .split('')
          .map((digit) => '٠١٢٣٤٥٦٧٨٩'[int.parse(digit)])
          .join();
      expectedLines
          .putIfAbsent(positions[index].$2, () => [])
          .add('\u06DD$digits');
    }
    for (final entry in expectedLines.entries) {
      final line = find.byKey(ValueKey('mushaf-line-${entry.key}'));
      final texts = tester.widgetList<Text>(
        find.descendant(of: line, matching: find.byType(Text)),
      );
      final actual = texts
          .map((text) => text.textSpan?.toPlainText() ?? '')
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      expect(
        actual,
        entry.value.join(' '),
        reason: 'Printed line ${entry.key} must keep every word and end marker',
      );
      final wordRects = [
        for (final element
            in find
                .descendant(of: line, matching: find.byType(Text))
                .evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ];
      final lineRect = tester.getRect(line);
      expect(wordRects.last.left, closeTo(lineRect.left + 20, 1));
      expect(wordRects.first.right, closeTo(lineRect.right - 20, 1));
    }
    expect(tester.takeException(), isNull);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    viewer.transformationController!.value = Matrix4.diagonal3Values(
      1.5,
      1.5,
      1,
    );
    viewer.onInteractionEnd!(ScaleEndDetails());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.zoom_out_map), findsOneWidget);
    await tester.tap(find.byIcon(Icons.zoom_out_map));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
  });

  for (final size in [
    const Size(390, 600),
    const Size(320, 480),
    const Size(844, 300),
  ]) {
    for (final printedLines in [true, false]) {
      testWidgets('complete page fits $size with printed lines $printedLines', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final ayahs = List.generate(
          13,
          (index) => Ayah(
            surahNumber: 2,
            ayahNumber: index + 1,
            pageNumber: 2,
            juzNumber: 1,
            arabic: List.filled(12, 'كَلِمَةٌ').join(' '),
            translations: const {},
            words: List.generate(
              12,
              (_) => TajweedWord(
                arabic: 'كَلِمَةٌ',
                spans: const [],
                lineNumber: printedLines ? index + 3 : null,
              ),
            ),
            endLineNumber: printedLines ? index + 3 : null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MushafPageContent(
                pageNumber: 2,
                ayahs: ayahs,
                isLandscape: size.width > size.height,
                textScale: 1.4,
                highlightEnabled: true,
                fitToViewport: true,
                surahNameFor: (_) => 'البقرة',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!printedLines) {
          expect(find.text('Unable to load this Quran page'), findsOneWidget);
          expect(find.byType(Scrollable), findsNothing);
          return;
        }
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.maxScrollExtent, closeTo(0, 0.01));
        if (printedLines) {
          final region = tester.getRect(
            find.byKey(const ValueKey('mushaf-content-region')),
          );
          final lastLine = tester.getRect(
            find.byKey(const ValueKey('mushaf-line-15')),
          );
          expect(lastLine.bottom, lessThanOrEqualTo(region.bottom));
          expect(find.byKey(const ValueKey('mushaf-line-1')), findsOneWidget);
          expect(find.byKey(const ValueKey('mushaf-line-2')), findsOneWidget);
        }
      });
    }
  }

  testWidgets('page mode rejects missing ayah-end line metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: MushafPageContent(
            pageNumber: 593,
            ayahs: [
              Ayah(
                surahNumber: 89,
                ayahNumber: 1,
                pageNumber: 593,
                arabic: 'وَالْفَجْرِ',
                translations: const {},
                words: const [
                  TajweedWord(arabic: 'وَالْفَجْرِ', spans: [], lineNumber: 3),
                ],
              ),
            ],
            isLandscape: false,
            textScale: 1,
            highlightEnabled: true,
            fitToViewport: true,
            surahNameFor: (_) => 'الفجر',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load this Quran page'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const ValueKey('mushaf-line-3')), findsNothing);
  });

  testWidgets('legacy scroll mode exposes overflowing bottom lines', (
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
            fitToViewport: false,
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
