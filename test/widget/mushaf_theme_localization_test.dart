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
