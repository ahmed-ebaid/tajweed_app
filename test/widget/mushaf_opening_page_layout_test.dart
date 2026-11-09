import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/reader/mushaf_page_view.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

List<Ayah> shortSurahPage(int pageNumber) {
  // Quran.Foundation word and ayah-end line assignments, including split ayahs.
  final positions = pageNumber == 604
      ? [
          (112, 1, [(3, 'قُلْ هُوَ ٱللَّهُ أَحَدٌ')], 3),
          (112, 2, [(3, 'ٱللَّهُ ٱلصَّمَدُ')], 3),
          (112, 3, [(3, 'لَمْ يَلِدْ'), (4, 'وَلَمْ يُولَدْ')], 4),
          (112, 4, [(4, 'وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ')], 4),
          (113, 1, [(7, 'قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ')], 7),
          (113, 2, [(7, 'مِن شَرِّ مَا خَلَقَ')], 7),
          (113, 3, [(7, 'وَمِن'), (8, 'شَرِّ غَاسِقٍ إِذَا وَقَبَ')], 8),
          (
            113,
            4,
            [(8, 'وَمِن شَرِّ ٱلنَّفَّـٰثَـٰتِ فِى'), (9, 'ٱلْعُقَدِ')],
            9,
          ),
          (113, 5, [(9, 'وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ')], 9),
          (114, 1, [(12, 'قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ')], 12),
          (114, 2, [(12, 'مَلِكِ ٱلنَّاسِ')], 12),
          (114, 3, [(12, 'إِلَـٰهِ'), (13, 'ٱلنَّاسِ')], 13),
          (114, 4, [(13, 'مِن شَرِّ ٱلْوَسْوَاسِ ٱلْخَنَّاسِ')], 13),
          (
            114,
            5,
            [(13, 'ٱلَّذِى'), (14, 'يُوَسْوِسُ فِى صُدُورِ ٱلنَّاسِ')],
            14,
          ),
          (114, 6, [(15, 'مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ')], 15),
        ]
      : [
          (106, 1, [(3, 'لِإِيلَـٰفِ قُرَيْشٍ')], 3),
          (106, 2, [(3, 'إِۦلَـٰفِهِمْ رِحْلَةَ ٱلشِّتَآءِ وَٱلصَّيْفِ')], 4),
          (106, 3, [(4, 'فَلْيَعْبُدُوا۟ رَبَّ هَـٰذَا ٱلْبَيْتِ')], 4),
          (
            106,
            4,
            [
              (4, 'ٱلَّذِىٓ أَطْعَمَهُم'),
              (5, 'مِّن جُوعٍۢ وَءَامَنَهُم مِّنْ خَوْفٍۭ'),
            ],
            5,
          ),
          (107, 1, [(8, 'أَرَءَيْتَ ٱلَّذِى يُكَذِّبُ بِٱلدِّينِ')], 8),
          (107, 2, [(8, 'فَذَٰلِكَ ٱلَّذِى'), (9, 'يَدُعُّ ٱلْيَتِيمَ')], 9),
          (107, 3, [(9, 'وَلَا يَحُضُّ عَلَىٰ طَعَامِ ٱلْمِسْكِينِ')], 9),
          (107, 4, [(10, 'فَوَيْلٌۭ لِّلْمُصَلِّينَ')], 10),
          (107, 5, [(10, 'ٱلَّذِينَ هُمْ عَن صَلَاتِهِمْ سَاهُونَ')], 11),
          (107, 6, [(11, 'ٱلَّذِينَ هُمْ يُرَآءُونَ')], 11),
          (107, 7, [(11, 'وَيَمْنَعُونَ ٱلْمَاعُونَ')], 11),
          (108, 1, [(14, 'إِنَّآ أَعْطَيْنَـٰكَ ٱلْكَوْثَرَ')], 14),
          (108, 2, [(14, 'فَصَلِّ لِرَبِّكَ وَٱنْحَرْ')], 14),
          (108, 3, [(15, 'إِنَّ شَانِئَكَ هُوَ ٱلْأَبْتَرُ')], 15),
        ];
  return [
    for (final (surah, ayah, lines, endLine) in positions)
      Ayah(
        surahNumber: surah,
        ayahNumber: ayah,
        pageNumber: pageNumber,
        juzNumber: 30,
        arabic: lines.map((line) => line.$2).join(' '),
        translations: const {},
        words: [
          for (final (line, text) in lines)
            for (final word in text.split(' '))
              TajweedWord(arabic: word, spans: const [], lineNumber: line),
        ],
        endLineNumber: endLine,
      ),
  ];
}

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
          find.text('\uFDFD'),
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

  testWidgets('fixed lines keep natural proportions without scrolling', (
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
    final verticalSizes = <double>[];
    var previousFitFontSize = double.infinity;
    for (var line = 1; line <= 15; line++) {
      final words = find.descendant(
        of: find.byKey(ValueKey('mushaf-line-$line')),
        matching: find.byType(Text),
      );
      final rowRect = tester.getRect(find.byKey(ValueKey('mushaf-line-$line')));
      var measuredWidth = 0.0;
      var measuredHeight = 0.0;
      final lineTexts = tester.widgetList<Text>(words).toList();
      for (final text in lineTexts) {
        final painter = TextPainter(
          text: text.textSpan,
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout();
        measuredWidth += painter.width;
        measuredHeight = math.max(measuredHeight, painter.height);
        painter.dispose();
      }
      final style = (lineTexts.first.textSpan! as TextSpan).style!;
      final space = TextPainter(
        text: TextSpan(text: ' ', style: style),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling,
      )..layout();
      measuredWidth += space.width * 0.5 * (lineTexts.length - 1);
      space.dispose();
      previousFitFontSize = math.min(
        previousFitFontSize,
        style.fontSize! *
            math.min(
              (rowRect.width - 28 - 1) / measuredWidth,
              (rowRect.height - 8) / measuredHeight,
            ),
      );
      for (final element in words.evaluate()) {
        final text = element.widget as Text;
        final box = element.renderObject! as RenderBox;
        final scale = box.getTransformTo(null).getColumn(0).length;
        final verticalScale = box.getTransformTo(null).getColumn(1).length;
        final fontSize = (text.textSpan! as TextSpan).style!.fontSize!;
        sizes.add(text.textScaler!.scale(fontSize) * scale);
        verticalSizes.add(text.textScaler!.scale(fontSize) * verticalScale);
        final lineRect = tester.getRect(
          find.byKey(ValueKey('mushaf-line-$line')),
        );
        final textRect = tester.getRect(find.byWidget(text));
        expect(textRect.top, greaterThanOrEqualTo(lineRect.top - 0.1));
        expect(textRect.bottom, lessThanOrEqualTo(lineRect.bottom + 0.1));
      }
    }
    expect(sizes.every((size) => (size - sizes.first).abs() < 0.01), isTrue);
    expect(
      verticalSizes.every((size) => (size - verticalSizes.first).abs() < 0.01),
      isTrue,
    );
    expect(verticalSizes.first / sizes.first, closeTo(1, 0.001));
    final row = tester.getRect(find.byKey(const ValueKey('mushaf-line-1')));
    expect(row.height, greaterThanOrEqualTo(sizes.first * 1.8 + 5.9));
    expect(sizes.first, greaterThan(previousFitFontSize * 1.01));
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
      expect(wordRects.last.left, closeTo(lineRect.left + 14, 1));
      expect(wordRects.first.right, closeTo(lineRect.right - 14, 1));
      expect(
        (wordRects.last.left + wordRects.first.right) / 2,
        closeTo(lineRect.center.dx, 1),
      );
    }
    final firstLine = tester.getRect(
      find.byKey(const ValueKey('mushaf-line-1')),
    );
    expect(firstLine.top - region.top, lessThanOrEqualTo(3));
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

  for (final pageNumber in [602, 604]) {
    for (final size in [
      const Size(390, 650),
      const Size(390, 780),
      const Size(320, 480),
      const Size(844, 330),
    ]) {
      testWidgets(
        'page $pageNumber balances short lines and headings at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final ayahs = shortSurahPage(pageNumber);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MushafPageContent(
                  pageNumber: pageNumber,
                  ayahs: ayahs,
                  isLandscape: size.width > size.height,
                  textScale: 1,
                  highlightEnabled: true,
                  surahNameFor: (number) => const {
                    106: 'قريش',
                    107: 'الماعون',
                    108: 'الكوثر',
                    112: 'الإخلاص',
                    113: 'الفلق',
                    114: 'الناس',
                  }[number]!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final expectedLines = <int, List<String>>{};
          for (final ayah in ayahs) {
            for (final word in ayah.words) {
              expectedLines
                  .putIfAbsent(word.lineNumber!, () => [])
                  .add(
                    TextSpan(
                      children: TajweedText.buildStyledWordSpans(
                        word,
                        baseStyle: const TextStyle(),
                      ),
                    ).toPlainText(),
                  );
            }
            final digits = ayah.ayahNumber
                .toString()
                .split('')
                .map((digit) => '٠١٢٣٤٥٦٧٨٩'[int.parse(digit)])
                .join();
            expectedLines
                .putIfAbsent(ayah.endLineNumber!, () => [])
                .add('\u06DD$digits');
          }
          final fontSizes = <double>[];
          for (final entry in expectedLines.entries) {
            final line = find.byKey(ValueKey('mushaf-line-${entry.key}'));
            final row = tester.getRect(line);
            final texts = find.descendant(
              of: line,
              matching: find.byType(Text),
            );
            expect(
              tester
                  .widgetList<Text>(texts)
                  .map((text) => text.textSpan!.toPlainText())
                  .join(' ')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim(),
              entry.value.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
              reason:
                  'All words and ayah markers stay on printed line ${entry.key}',
            );
            final rects = <Rect>[];
            final effectiveSizes = <double>[];
            for (final element in texts.evaluate()) {
              final text = element.widget as Text;
              final box = element.renderObject! as RenderBox;
              final transform = box.getTransformTo(null);
              final scaleX = transform.getColumn(0).length;
              final scaleY = transform.getColumn(1).length;
              expect(scaleX, closeTo(scaleY, 0.0001));
              final span = text.textSpan! as TextSpan;
              expect(span.style!.fontWeight, FontWeight.w700);
              effectiveSizes.add(span.style!.fontSize! * scaleX);
              final rect = tester.getRect(find.byWidget(text));
              rects.add(rect);
              expect(rect.top, greaterThanOrEqualTo(row.top + 2.9));
              expect(rect.bottom, lessThanOrEqualTo(row.bottom - 2.9));
              expect(rect.left, greaterThanOrEqualTo(row.left + 13));
              expect(rect.right, lessThanOrEqualTo(row.right - 13));
            }
            fontSizes.addAll(effectiveSizes);
            expect(
              (rects.first.right + rects.last.left) / 2,
              closeTo(row.center.dx, 0.1),
            );
            final centered = (pageNumber == 602 ? {5, 15} : {9, 14, 15})
                .contains(entry.key);
            if (centered) {
              for (var index = 1; index < rects.length; index++) {
                final gap = rects[index - 1].left - rects[index].right;
                expect(gap, greaterThanOrEqualTo(-0.1));
                expect(
                  gap,
                  lessThanOrEqualTo(effectiveSizes.first * 0.45 + 0.1),
                );
              }
            } else {
              expect(rects.first.right, closeTo(row.right - 14, 1));
              expect(rects.last.left, closeTo(row.left + 14, 1));
            }
          }
          expect(
            fontSizes.every((size) => (size - fontSizes.first).abs() < 0.01),
            isTrue,
          );
          if (size == const Size(390, 780)) {
            expect(
              fontSizes.first,
              greaterThanOrEqualTo(pageNumber == 602 ? 23.8 : 24.4),
            );
          }
          expect(
            find.byKey(const ValueKey('mushaf-surah-cartouche')),
            findsNWidgets(3),
          );
          expect(find.text('\uFDFD'), findsNWidgets(3));
          for (final basmala in tester.widgetList<Text>(find.text('\uFDFD'))) {
            expect(
              basmala.semanticsLabel,
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            );
          }
          final region = tester.getRect(
            find.byKey(const ValueKey('mushaf-content-region')),
          );
          if (size.width > size.height) {
            final printedRow = tester.getRect(
              find.byKey(const ValueKey('mushaf-line-15')),
            );
            expect(printedRow.width, lessThanOrEqualTo(size.height * 0.62));
          }
          expect(
            tester.getRect(find.byKey(const ValueKey('mushaf-line-15'))).bottom,
            lessThanOrEqualTo(region.bottom),
          );
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .maxScrollExtent,
            closeTo(0, 0.01),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final (page, line, centered) in [
    (594, 5, false),
    (600, 9, true),
    (600, 10, false),
    (603, 10, true),
    (603, 15, false),
  ]) {
    testWidgets('page $page line $line follows V1 alignment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushafPageContent(
              pageNumber: page,
              ayahs: [
                Ayah(
                  surahNumber: 89,
                  ayahNumber: 2,
                  pageNumber: page,
                  arabic: 'وَلَيَالٍ عَشْرٍ',
                  translations: const {},
                  words: [
                    TajweedWord(
                      arabic: 'وَلَيَالٍ',
                      spans: const [],
                      lineNumber: line,
                    ),
                    TajweedWord(
                      arabic: 'عَشْرٍ',
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
              surahNameFor: (_) => 'الفجر',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('mushaf-line-$line'));
      final texts = find.descendant(of: row, matching: find.byType(Text));
      final rowRect = tester.getRect(row);
      final firstRect = tester.getRect(texts.first);
      final lastRect = tester.getRect(texts.last);
      if (centered) {
        expect(firstRect.right, lessThan(rowRect.right - 14));
        expect(lastRect.left, greaterThan(rowRect.left + 14));
        expect(
          (firstRect.right + lastRect.left) / 2,
          closeTo(rowRect.center.dx, 0.1),
        );
      } else {
        expect(firstRect.right, closeTo(rowRect.right - 14, 1));
        expect(lastRect.left, closeTo(rowRect.left + 14, 1));
      }
      expect(tester.takeException(), isNull);
    });
  }

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
