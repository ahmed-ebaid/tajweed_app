import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/rules/rule_example_references.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';

void main() {
  test('rules repository covers every tajweed rule exactly once', () {
    final definedRules =
        RulesRepository.all.map((definition) => definition.rule).toList();

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

  test('qalqalah Arabic description says kubra at the end and sughra in the middle', () {
    final description =
        RulesRepository.findByRule(TajweedRule.qalqalah)!.description('ar');

    expect(description, contains('صغرى'));
    expect(description, contains('كبرى'));
    expect(description, contains('وسط الكلمة'));
    expect(description, contains('آخر الكلمة'));
  });
}