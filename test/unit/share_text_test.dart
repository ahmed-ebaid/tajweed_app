import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/features/reader/ayah_share_content.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/shared/utils/share_text.dart';

void main() {
  test('shared guidance has readable marked letters in all languages', () {
    final rule = RulesRepository.findByRule(TajweedRule.silent)!;
    for (final language in ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es']) {
      final original = rule.description(language);
      final result = ShareText.guidance(original);
      expect(result, contains('(و۟)'));
      expect(result, contains('(بۡ)'));
      expect(result, isNot(contains('(۟)')));
      expect(result, isNot(contains('(ۡ)')));
      expect(ShareText.guidance(result), result);
      expect(
        result.replaceAll('(و۟)', '(۟)').replaceAll('(بۡ)', '(ۡ)'),
        original,
      );
    }
  });

  test('Quran share text retains every character and mark exactly', () {
    const quran = 'أُو۟لَـٰٓئِكَ عَلَىٰ هُدًى مِّن رَّبِّهِمْ ۖ';
    final result = AyahShareContent.build(
      heading: '2:5',
      arabicText: quran,
      translation: 'Rounded zero (۟), ordinary sukoon (ۡ).',
    );
    expect(result, contains('\n$quran\n'));
    expect(result, contains('Rounded zero (و۟), ordinary sukoon (بۡ).'));
    expect(ShareText.guidance(quran), quran);
  });
}
