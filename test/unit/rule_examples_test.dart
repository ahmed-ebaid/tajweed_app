import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/rules/rule_detail_screen.dart';
import 'package:tajweed_practice/features/rules/rule_example_references.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';

void main() {
  test('rules repository covers every tajweed rule exactly once', () {
    final definedRules = RulesRepository.all
        .map((definition) => definition.rule)
        .toList();

    expect(definedRules, hasLength(TajweedRule.values.length));
    expect(definedRules.toSet(), equals(TajweedRule.values.toSet()));
  });

  test('every tajweed rule has an example ayah reference', () {
    for (final rule in TajweedRule.values) {
      final ref = RuleExampleReferences.referenceFor(rule);
      expect(ref, isNotNull, reason: 'Missing example ayah for ${rule.name}');
      expect(ref!.surah, inInclusiveRange(1, 114));
      expect(ref.ayah, greaterThan(0));
    }
  });

  test('shaddah uses the simple rabb example from Al-Fatiha 1:2', () {
    final ref = RuleExampleReferences.referenceFor(TajweedRule.shaddah);

    expect(ref, isNotNull);
    expect(ref!.surah, 1);
    expect(ref.ayah, 2);
    expect(
      RuleExampleReferences.forcedHighlightWordIndices[TajweedRule.shaddah],
      {2},
    );
  });

  test('waqf uses an ayah with a clear obligatory-stop marker', () {
    final ref = RuleExampleReferences.referenceFor(TajweedRule.waqf);

    expect(ref, isNotNull);
    expect(ref!.surah, 6);
    expect(ref.ayah, 36);
    expect(
      RuleExampleReferences.forcedMarkersAfterWordIndices[TajweedRule.waqf],
      {3: 'ۘ'},
    );
  });

  test('waqf symbol guidance is localized in every supported language', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
    final keys = <String>['title'];
    for (var index = 0; index < 7; index++) {
      keys
        ..add('name_$index')
        ..add('description_$index');
    }

    for (final languageCode in languageCodes) {
      final strings = WaqfRuleStrings(languageCode);
      for (final key in keys) {
        expect(
          strings.text(key),
          isNot(key),
          reason: 'Missing $key for $languageCode',
        );
      }
    }
  });

  test(
    'qalqalah Arabic description says kubra at the end and sughra in the middle',
    () {
      final description = RulesRepository.findByRule(
        TajweedRule.qalqalah,
      )!.description('ar');

      expect(description, contains('صغرى'));
      expect(description, contains('كبرى'));
      expect(description, contains('وسط الكلمة'));
      expect(description, contains('آخر الكلمة'));
    },
  );
}
