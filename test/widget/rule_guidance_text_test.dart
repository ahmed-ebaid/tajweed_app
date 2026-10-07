import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/constants/arabic_shaping.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/widgets/rule_guidance_text.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('AmiriQuran')
      ..addFont(rootBundle.load('assets/fonts/AmiriQuran.ttf'));
    await loader.load();
  });

  testWidgets('standalone Quran marks use a carrier and the bundled font', (
    tester,
  ) async {
    final definition = RulesRepository.findByRule(TajweedRule.silent)!;
    for (final language in ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es']) {
      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        final description = definition.description(language);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: direction,
                child: SizedBox(
                  width: 280,
                  child: RuleGuidanceText(
                    description,
                    style: const TextStyle(fontSize: 18, height: 1.6),
                  ),
                ),
              ),
            ),
          ),
        );
        final text = tester.widget<Text>(find.byType(Text));
        final span = text.textSpan! as TextSpan;
        final children = span.children!.cast<TextSpan>();
        final symbols = children.where(
          (child) => child.style?.fontFamily == 'AmiriQuran',
        );
        expect(symbols.map((child) => child.text), ['و۟', 'بۡ']);
        expect(symbols.first.style!.color, TajweedRule.silent.color);
        expect(symbols.last.style!.color, isNull);
        for (final symbol in symbols) {
          expect(symbol.style!.fontFeatures, arabicShapingFeatures);
          expect(symbol.style!.fontWeight, FontWeight.normal);
        }
        expect(
          span.toPlainText(includeSemanticsLabels: false),
          description.replaceAll('(۟)', '(و۟)').replaceAll('(ۡ)', '(بۡ)'),
        );
        expect(text.semanticsLabel, description);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('ordinary guidance and marked words remain unchanged', (
    tester,
  ) async {
    const guidance = 'أُو۟لَـٰٓئِكَ كَفَرُوا۟ بۡ — ordinary guidance';
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RuleGuidanceText(guidance))),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, guidance);
    expect(text.textSpan, isNull);
  });
}
