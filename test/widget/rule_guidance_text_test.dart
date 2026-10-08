import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/widgets/rule_guidance_text.dart';

void main() {
  testWidgets('prose omits unreadable mark glyphs in every language', (
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
        expect(text.textSpan, isNull);
        expect(
          text.data,
          description.replaceAll(RegExp(r'\s*\((?:و۟|بۡ|۟|ۡ)\)'), ''),
        );
        expect(text.data, isNot(contains('۟')));
        expect(text.data, isNot(contains('ۡ')));
        expect(text.data, isNotEmpty);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'Quranic words keep their marks while prose annotations are removed',
    (tester) async {
      const quran = 'أُو۟لَـٰٓئِكَ كَفَرُوا۟';
      const guidance = '$quran (۟) (بۡ) — ordinary guidance';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RuleGuidanceText(guidance))),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, '$quran — ordinary guidance');
      expect(text.data, contains('أُو۟لَـٰٓئِكَ'));
      expect(text.data, contains('كَفَرُوا۟'));
      expect(text.textSpan, isNull);
    },
  );
}
