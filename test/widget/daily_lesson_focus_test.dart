import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/providers/daily_lesson_provider.dart';
import 'package:tajweed_practice/features/reader/widgets/daily_lesson_focus.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';

void main() {
  testWidgets('lesson banner is localized, opens details, and dismisses', (
    tester,
  ) async {
    var opened = 0;
    var dismissed = 0;
    for (var day = 1; day <= 7; day++) {
      final lesson = DailyLesson.forDate(DateTime(2026, 1, day));
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: DailyLessonFocus(
                lesson: lesson,
                onOpen: () => opened++,
                onDismiss: () => dismissed++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = tester.widget<TextButton>(
          find.byKey(const Key('open_daily_lesson_rule')),
        );
        expect(
          (button.child as Text).data,
          RulesRepository.findByRule(lesson.rule)!.name(locale.languageCode),
        );
        expect(find.textContaining('rule_'), findsNothing);
        expect(
          find.text(AppLocalizations(locale).get('lesson_focus_hint')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('open_daily_lesson_rule')));
        await tester.tap(find.byKey(const Key('dismiss_daily_lesson')));
        expect(tester.takeException(), isNull);
      }
    }
    expect(opened, 56);
    expect(dismissed, 56);
  });

  testWidgets(
    'focus preserves rule colors and makes the whole example tappable',
    (tester) async {
      const ayah = Ayah(
        surahNumber: 67,
        ayahNumber: 12,
        pageNumber: 563,
        arabic: 'إِنَّ رَبَّهُم',
        translations: {},
        words: [
          TajweedWord(
            arabic: 'إِنَّ',
            spans: [TajweedSpan(start: 2, end: 4, rule: TajweedRule.ghunnah)],
          ),
          TajweedWord(arabic: 'رَبَّهُم', spans: []),
        ],
      );
      final tapped = <TajweedRule>[];
      for (final dark in [false, true]) {
        for (final colored in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Scaffold(
                body: TajweedText(
                  ayah: ayah,
                  highlightEnabled: colored,
                  lessonWordIndices: const {0},
                  lessonRule: TajweedRule.ghunnah,
                  onRuleTapped: (rule, word, audio) => tapped.add(rule),
                ),
              ),
            ),
          );
          final paragraph = tester.widget<RichText>(
            find.byType(RichText).first,
          );
          final spans = (paragraph.text as TextSpan).children!.cast<TextSpan>();
          final focused = spans
              .where((span) => span.style?.backgroundColor != null)
              .toList();
          expect(focused, isNotEmpty);
          expect(focused.map((span) => span.text).join(), 'إِنَّ');
          expect(
            spans
                .singleWhere((span) => span.text == 'رَبَّهُم')
                .style
                ?.backgroundColor,
            isNull,
          );
          if (colored) {
            expect(
              focused.any(
                (span) => span.style?.color == TajweedRule.ghunnah.color,
              ),
              isTrue,
            );
          }
          for (final span in focused) {
            (span.recognizer as TapGestureRecognizer).onTap!();
            expect(tapped.last, TajweedRule.ghunnah);
          }
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TajweedText(ayah: ayah)),
        ),
      );
      final spans =
          (tester.widget<RichText>(find.byType(RichText).first).text
                  as TextSpan)
              .children!
              .cast<TextSpan>();
      expect(
        spans.every((span) => span.style?.backgroundColor == null),
        isTrue,
      );
    },
  );
}
