import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/widgets/rule_example_text.dart';

/// Arabic is cursive: letters change shape depending on their neighbours.
/// Flutter shapes text one style run at a time, so a word split across several
/// [TextSpan]s only stays joined when every run resolves to the same font.
/// Varying anything that selects a different typeface — weight above all —
/// forces a run break, and the letters either side revert to isolated forms.
///
/// These tests pin that contract: only `color` may vary across the spans of a
/// single word.
void main() {
  List<TextSpan> spansOf(WidgetTester tester) {
    final widget = tester.widget<Text>(find.byType(Text));
    final root = widget.textSpan as TextSpan?;
    if (root == null) return const [];
    final children = root.children;
    if (children == null) return [root];
    return children.cast<TextSpan>();
  }

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('example words keep one typeface across every span', (
    tester,
  ) async {
    for (final definition in RulesRepository.all) {
      for (var i = 0; i < definition.exampleArabic.length; i++) {
        final word = definition.exampleArabic[i];
        await pump(
          tester,
          RuleExampleText(
            rule: definition.rule,
            text: word,
            exampleIndex: i,
            fontSize: 28,
          ),
        );

        final spans = spansOf(tester);
        final label = '${definition.rule.name}[$i]';
        expect(spans, isNotEmpty, reason: '$label rendered nothing');

        final first = spans.first.style!;
        for (final span in spans) {
          final style = span.style!;
          expect(
            style.fontWeight,
            first.fontWeight,
            reason:
                '$label varies fontWeight across spans, which breaks Arabic '
                'joining. Vary colour only.',
          );
          expect(style.fontFamily, first.fontFamily, reason: label);
          expect(style.fontSize, first.fontSize, reason: label);
          expect(style.fontFeatures, isNotNull, reason: label);
        }
      }
    }
  });

  testWidgets('splitting the word never drops or reorders characters', (
    tester,
  ) async {
    for (final definition in RulesRepository.all) {
      for (var i = 0; i < definition.exampleArabic.length; i++) {
        final word = definition.exampleArabic[i];
        await pump(
          tester,
          RuleExampleText(
            rule: definition.rule,
            text: word,
            exampleIndex: i,
            fontSize: 28,
          ),
        );

        final rebuilt = spansOf(tester).map((s) => s.text ?? '').join();
        expect(
          rebuilt,
          word,
          reason: '${definition.rule.name}[$i] lost characters when split',
        );
      }
    }
  });

  testWidgets('silent examples color only the marked letter in both themes', (
    tester,
  ) async {
    final definition = RulesRepository.findByRule(TajweedRule.silent)!;
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (var i = 0; i < definition.exampleArabic.length; i++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: RuleExampleText(
                rule: definition.rule,
                text: definition.exampleArabic[i],
                exampleIndex: i,
                fontSize: 28,
              ),
            ),
          ),
        );
        final spans = spansOf(tester);
        final highlighted = spans.where(
          (span) => span.style!.color == TajweedRule.silent.color,
        );
        expect(
          highlighted.map((span) => span.text).join(),
          i == 0 ? 'و۟' : 'ا۟',
        );
        final color = highlighted.single.style!.color!;
        expect(color.b, greaterThan(color.r));
        expect(color.g, greaterThan(color.r));
        for (final span in spans) {
          expect(span.style!.fontFamily, 'AmiriQuran');
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
}
