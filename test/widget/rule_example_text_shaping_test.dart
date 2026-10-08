import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/widgets/rule_example_text.dart';
import 'package:tajweed_practice/features/rules/waqf_symbols.dart';

/// Arabic is cursive: letters change shape depending on their neighbours.
/// Flutter shapes text one style run at a time, so a word split across several
/// [TextSpan]s only stays joined when every run resolves to the same font.
/// Varying anything that selects a different typeface — weight above all —
/// forces a run break, and the letters either side revert to isolated forms.
///
/// These tests pin that contract: only `color` may vary across the spans of a
/// single word.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'AmiriQuran',
    )..addFont(rootBundle.load('assets/fonts/AmiriQuran.ttf'))).load();
  });

  List<TextSpan> spansOf(WidgetTester tester) {
    final widget = tester.widget<Text>(find.byType(Text));
    final root = widget.textSpan as TextSpan?;
    if (root == null) {
      return [TextSpan(text: widget.data, style: widget.style)];
    }
    final children = root.children;
    if (children == null) return [root];
    return children.cast<TextSpan>();
  }

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('hamza below alif and its vowel remain highlighted together', (
    tester,
  ) async {
    final definition = RulesRepository.findByRule(TajweedRule.hamzatQat)!;
    for (var i = 0; i < definition.exampleArabic.length; i++) {
      await pump(
        tester,
        RuleExampleText(
          rule: definition.rule,
          text: definition.exampleArabic[i],
          exampleIndex: i,
          fontSize: 28,
        ),
      );
      final highlighted = spansOf(tester)
          .where((span) => span.style!.color == definition.rule.color)
          .map((span) => span.text)
          .join();
      expect(highlighted, ['أَ', 'إِ', 'أُ'][i]);
      expect(spansOf(tester).first.style!.height, greaterThanOrEqualTo(1.8));
    }
  });

  testWidgets('every example keeps all glyph ink with chip padding', (
    tester,
  ) async {
    const captureKey = ValueKey('example-ink');
    Future<int> inkCount(Widget child, String label) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );
      return tester
          .runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(captureKey),
            );
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData();
            final width = image.width;
            final height = image.height;
            image.dispose();
            expect(data, isNotNull);
            var count = 0;
            for (var i = 3; i < data!.lengthInBytes; i += 4) {
              if (data.getUint8(i) > 0) {
                count++;
                final pixel = (i - 3) ~/ 4;
                final x = pixel % width;
                final y = pixel ~/ width;
                expect(x, inInclusiveRange(2, width - 3), reason: label);
                expect(y, inInclusiveRange(2, height - 3), reason: label);
              }
            }
            return count;
          })
          .then((value) => value!);
    }

    for (final definition in RulesRepository.all) {
      for (var i = 0; i < definition.exampleArabic.length; i++) {
        for (final scale in [1.0, 1.6]) {
          Widget subject(double padding) => RepaintBoundary(
            key: captureKey,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: 268,
                  child: RuleExampleText(
                    rule: definition.rule,
                    text: definition.exampleArabic[i],
                    exampleIndex: i,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
          );
          final label = '${definition.rule.name}[$i], scale $scale';
          final reference = await inkCount(subject(40), '$label reference');
          final chip = await inkCount(
            subject((16 * scale).ceilToDouble()),
            label,
          );
          expect(reference, greaterThan(0));
          expect(
            chip,
            closeTo(reference, reference * 0.01),
            reason: '${definition.rule.name}[$i], scale $scale clips glyph ink',
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

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
          definition.rule == TajweedRule.waqf
              ? WaqfSymbols.examples[i].displaySymbol
              : word,
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
