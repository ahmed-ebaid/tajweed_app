import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/l10n/reader_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/theme/app_theme.dart';
import 'package:tajweed_practice/features/reader/mushaf_page_view.dart';

Widget subject(
  Widget child, {
  Locale locale = const Locale('ar'),
  ThemeMode themeMode = ThemeMode.light,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: themeMode,
  home: Scaffold(body: child),
);

Widget page({
  required bool printed,
  required bool landscape,
  required bool highlighted,
  Set<String> hiddenAyahs = const {},
}) => MushafPageContent(
  pageNumber: 3,
  ayahs: [
    Ayah(
      surahNumber: 2,
      ayahNumber: 1,
      pageNumber: 3,
      juzNumber: 1,
      rubElHizbNumber: 1,
      arabic: 'نَّ كَلِمَةٌ',
      translations: const {},
      words: [
        TajweedWord(
          arabic: 'نَّ',
          spans: const [
            TajweedSpan(start: 0, end: 3, rule: TajweedRule.ghunnah),
          ],
          lineNumber: printed ? 3 : null,
        ),
        TajweedWord(
          arabic: 'كَلِمَةٌ',
          spans: const [],
          lineNumber: printed ? 3 : null,
        ),
      ],
      endLineNumber: printed ? 3 : null,
    ),
    Ayah(
      surahNumber: 2,
      ayahNumber: 2,
      pageNumber: 3,
      juzNumber: 1,
      rubElHizbNumber: 2,
      arabic: 'كَلِمَةٌ',
      translations: const {},
      words: [
        TajweedWord(
          arabic: 'كَلِمَةٌ',
          spans: const [],
          lineNumber: printed ? 4 : null,
        ),
      ],
      endLineNumber: printed ? 4 : null,
    ),
  ],
  isLandscape: landscape,
  textScale: 1,
  highlightEnabled: highlighted,
  surahNameFor: (_) => 'البقرة',
  hiddenAyahs: hiddenAyahs,
);

Color pageBackground(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const ValueKey('mushaf-content-region')),
  );
  return (container.decoration! as BoxDecoration).color!;
}

List<TextSpan> pageSpans(WidgetTester tester) {
  final spans = <TextSpan>[];
  void collect(InlineSpan span) {
    if (span is TextSpan) {
      spans.add(span);
      for (final child in span.children ?? <InlineSpan>[]) {
        collect(child);
      }
    }
  }

  for (final richText in tester.widgetList<RichText>(
    find.descendant(
      of: find.byKey(const ValueKey('mushaf-content-region')),
      matching: find.byType(RichText),
    ),
  )) {
    collect(richText.text);
  }
  return spans;
}

void main() {
  for (final printed in [true]) {
    testWidgets('pause marks do not hide matched words printed=$printed', (
      tester,
    ) async {
      const words = [
        'ذَٰلِكَ',
        'ٱلْكِتَـٰبُ',
        'لَا',
        'رَيْبَ ۛ',
        'فِيهِ ۛ',
        'هُدًۭى',
        'لِّلْمُتَّقِينَ',
      ];
      await tester.pumpWidget(
        subject(
          MushafPageContent(
            pageNumber: 3,
            ayahs: [
              Ayah(
                surahNumber: 2,
                ayahNumber: 2,
                pageNumber: 3,
                arabic: words.join(' '),
                translations: const {},
                words: [
                  for (final word in words)
                    TajweedWord(
                      arabic: word,
                      spans: const [],
                      lineNumber: printed ? 3 : null,
                    ),
                ],
                endLineNumber: printed ? 3 : null,
              ),
              Ayah(
                surahNumber: 2,
                ayahNumber: 3,
                pageNumber: 3,
                arabic: 'أول ثاني',
                translations: const {},
                words: [
                  TajweedWord(
                    arabic: 'أول ثاني',
                    spans: const [],
                    lineNumber: printed ? 4 : null,
                  ),
                ],
                endLineNumber: printed ? 4 : null,
              ),
            ],
            isLandscape: false,
            textScale: 1,
            highlightEnabled: true,
            surahNameFor: (_) => 'البقرة',
            hiddenAyahs: const {'2:2', '2:3'},
            revealedWordCounts: const {'2:2': 5, '2:3': 1},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final spans = pageSpans(tester);
      for (final word in ['رَيْبَ', 'فِيهِ']) {
        expect(
          spans
              .firstWhere(
                (span) => (span.text ?? '').contains(word),
                orElse: () => throw StateError(
                  'Missing $word: ${spans.map((s) => s.text).toList()}',
                ),
              )
              .style
              ?.color,
          isNot(Colors.transparent),
        );
      }
      for (final word in ['هُد', 'مُت', 'أول ثاني']) {
        final span = spans.firstWhere(
          (span) => (span.text ?? '').contains(word),
          orElse: () => throw StateError(
            'Missing $word: ${spans.map((s) => s.text).toList()}',
          ),
        );
        expect(span.style?.color, Colors.transparent);
        expect(span.semanticsLabel, '');
      }
    });
  }

  for (final landscape in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'shared printed page retains line ends and Hizb through hints landscape=$landscape dark=$dark',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            tester.view.physicalSize = landscape
                ? const Size(844, 390)
                : const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final ayahs = [
              Ayah(
                surahNumber: 2,
                ayahNumber: 142,
                pageNumber: 22,
                juzNumber: 2,
                hizbNumber: 3,
                rubElHizbNumber: 9,
                arabic: '۞ سَيَقُولُ السُّفَهَاءُ مِنَ النَّاسِ',
                translations: const {},
                words: [
                  const TajweedWord(
                    arabic: '۞ سَيَقُولُ',
                    spans: [],
                    lineNumber: 3,
                  ),
                  const TajweedWord(
                    arabic: 'السُّفَهَاءُ',
                    spans: [],
                    lineNumber: 3,
                  ),
                  const TajweedWord(arabic: 'مِنَ', spans: [], lineNumber: 4),
                  const TajweedWord(
                    arabic: 'النَّاسِ',
                    spans: [],
                    lineNumber: 4,
                  ),
                ],
                endLineNumber: 4,
              ),
              const Ayah(
                surahNumber: 3,
                ayahNumber: 1,
                pageNumber: 22,
                juzNumber: 2,
                arabic: 'الٓمٓ',
                translations: {},
                words: [TajweedWord(arabic: 'الٓمٓ', spans: [], lineNumber: 7)],
                endLineNumber: 7,
              ),
            ];
            Widget shared({bool hidden = false, bool hint = false}) => subject(
              MushafPageContent(
                pageNumber: 22,
                ayahs: ayahs,
                isLandscape: landscape,
                textScale: 1,
                highlightEnabled: true,
                surahNameFor: (surah) => surah == 2 ? 'البقرة' : 'آل عمران',
                hiddenAyahs: hidden ? {'2:142'} : {},
                hintedWords: hint ? {'2:142': 2} : {},
              ),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            );
            await tester.pumpWidget(shared());
            await tester.pumpAndSettle();
            final texts = find.descendant(
              of: find.byKey(const ValueKey('mushaf-content-region')),
              matching: find.byType(RichText),
            );
            final rects = [
              for (var i = 0; i < texts.evaluate().length; i++)
                tester.getRect(texts.at(i)),
            ];
            final hizb = find.bySemanticsLabel(RegExp('.*حزب.*'));
            expect(hizb, findsWidgets);
            for (final hint in [false, true]) {
              await tester.pumpWidget(shared(hidden: true, hint: hint));
              await tester.pumpAndSettle();
              expect([
                for (var i = 0; i < texts.evaluate().length; i++)
                  tester.getRect(texts.at(i)),
              ], rects);
              expect(hizb, findsWidgets);
              final spans = pageSpans(tester);
              String plain(String? text) => (text ?? '')
                  .replaceAll(RegExp(r'[\u064B-\u065F\u06DE]'), '')
                  .trim();
              for (final word in ayahs.first.words.take(2)) {
                final span = spans.firstWhere(
                  (span) => plain(span.text) == plain(word.arabic),
                );
                expect(span.style?.color == Colors.transparent, !hint);
              }
              expect(
                spans
                    .firstWhere((span) => plain(span.text) == 'الناس')
                    .style
                    ?.color,
                Colors.transparent,
              );
              expect(
                spans.firstWhere((span) => span.text == 'الٓمٓ').style?.color,
                isNot(Colors.transparent),
              );
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  for (final printed in [false, true]) {
    for (final landscape in [false, true]) {
      testWidgets(
        'masking preserves text geometry and hides semantics printed=$printed landscape=$landscape',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              subject(
                page(printed: printed, landscape: landscape, highlighted: true),
              ),
            );
            await tester.pumpAndSettle();
            final richTexts = find.descendant(
              of: find.byKey(const ValueKey('mushaf-content-region')),
              matching: find.byType(RichText),
            );
            final sizes = [
              for (var i = 0; i < richTexts.evaluate().length; i++)
                tester.getSize(richTexts.at(i)),
            ];
            await tester.pumpWidget(
              subject(
                page(
                  printed: printed,
                  landscape: landscape,
                  highlighted: true,
                  hiddenAyahs: {'2:1'},
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect([
              for (var i = 0; i < richTexts.evaluate().length; i++)
                tester.getSize(richTexts.at(i)),
            ], sizes);
            final hidden = pageSpans(
              tester,
            ).where((span) => span.style?.color == Colors.transparent).toList();
            expect(hidden, hasLength(2));
            expect(hidden.every((span) => span.semanticsLabel == ''), isTrue);
            expect(find.bySemanticsLabel(RegExp('نَّ')), findsNothing);
            expect(
              pageSpans(tester).any(
                (span) =>
                    span.text == 'كَلِمَةٌ' &&
                    span.style?.color != Colors.transparent,
              ),
              isTrue,
            );
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('Mushaf palette is localized in ${locale.languageCode}', (
      tester,
    ) async {
      bool? changed;
      final l10n = AppLocalizations(locale);
      await tester.pumpWidget(
        subject(
          MushafTajweedPalette(
            enabled: true,
            onChanged: (value) => changed = value,
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.get('tajweed_colors')), findsOneWidget);
      expect(
        find.text(
          readerTranslations[locale
              .languageCode]!['tajweed_colors_description']!,
        ),
        findsOneWidget,
      );
      if (locale.languageCode != 'en') {
        expect(find.text('Tajweed colors'), findsNothing);
        expect(
          find.text('Show the same rule colors used in ayah view'),
          findsNothing,
        );
      }
      final tileContext = tester.element(find.byType(SwitchListTile));
      expect(
        Directionality.of(tileContext),
        ['ar', 'ur'].contains(locale.languageCode)
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
      await tester.tap(find.byType(Switch));
      expect(changed, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final printed in [false, true]) {
    for (final landscape in [false, true]) {
      for (final highlighted in [false, true]) {
        for (final dark in [false, true]) {
          testWidgets('Mushaf ${printed ? 'printed' : 'flow'} '
              '${landscape ? 'landscape' : 'portrait'} '
              'highlight=$highlighted dark=$dark', (tester) async {
            tester.view.physicalSize = landscape
                ? const Size(844, 390)
                : const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              subject(
                page(
                  printed: printed,
                  landscape: landscape,
                  highlighted: highlighted,
                ),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              ),
            );
            await tester.pumpAndSettle();

            final background = pageBackground(tester);
            final scheme = dark
                ? AppTheme.darkTheme.colorScheme
                : AppTheme.lightTheme.colorScheme;
            expect(
              background,
              dark
                  ? AppTheme.darkTheme.colorScheme.surface
                  : const Color(0xFFFFFCF3),
            );
            final spans = pageSpans(tester);
            final region = tester.widget<Container>(
              find.byKey(const ValueKey('mushaf-content-region')),
            );
            expect(
              ((region.decoration! as BoxDecoration).border! as Border)
                  .top
                  .color,
              dark ? scheme.outline : const Color(0xFF5F9584),
            );
            final surahTitle = tester.widget<Text>(find.text('سُورَةُ البقرة'));
            expect(
              surahTitle.style!.color,
              dark ? scheme.primary : const Color(0xFF083F31),
            );
            final ayahMarkers = spans.where(
              (span) => span.text?.contains('\u06DD') ?? false,
            );
            expect(ayahMarkers, isNotEmpty);
            expect(
              ayahMarkers.every(
                (span) =>
                    span.style?.color ==
                    (dark ? const Color(0xFFE2BD6B) : const Color(0xFF8B6B2A)),
              ),
              isTrue,
            );
            final neutral = spans.where(
              (span) => span.text?.contains('كَلِمَةٌ') ?? false,
            );
            expect(neutral, isNotEmpty);
            for (final span in neutral) {
              final ink = span.style!.color!;
              expect(
                ink,
                dark
                    ? AppTheme.darkTheme.colorScheme.onSurface
                    : const Color(0xFF050807),
              );
              final contrast = dark
                  ? (ink.computeLuminance() + 0.05) /
                        (background.computeLuminance() + 0.05)
                  : (background.computeLuminance() + 0.05) /
                        (ink.computeLuminance() + 0.05);
              expect(contrast, greaterThanOrEqualTo(4.5));
            }
            expect(
              spans.any(
                (span) => span.style?.color == TajweedRule.ghunnah.color,
              ),
              highlighted,
            );
            final basmala = tester.widget<Text>(
              find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
            );
            expect(
              basmala.style!.color,
              dark
                  ? AppTheme.darkTheme.colorScheme.onSurface
                  : const Color(0xFF050807),
            );
            if (!landscape) {
              expect(find.text('الجزء ١'), findsOneWidget);
              expect(find.text('٣'), findsOneWidget);
              expect(find.text('Juz 1'), findsNothing);
              expect(
                tester.widget<Text>(find.text('الجزء ١')).style!.color,
                dark ? scheme.primary : const Color(0xFF0A4B39),
              );
              expect(
                tester.widget<Text>(find.text('٣')).style!.color,
                dark ? scheme.primary : const Color(0xFF0B5C45),
              );
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets('Mushaf follows live system night-mode changes', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      subject(
        page(printed: true, landscape: false, highlighted: false),
        themeMode: ThemeMode.system,
      ),
    );
    await tester.pumpAndSettle();
    expect(pageBackground(tester), const Color(0xFFFFFCF3));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(pageBackground(tester), AppTheme.darkTheme.colorScheme.surface);
    expect(
      pageSpans(tester)
          .where((span) => span.text?.contains('كَلِمَةٌ') ?? false)
          .every(
            (span) =>
                span.style?.color == AppTheme.darkTheme.colorScheme.onSurface,
          ),
      isTrue,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(pageBackground(tester), const Color(0xFFFFFCF3));
    expect(tester.takeException(), isNull);
  });
}
