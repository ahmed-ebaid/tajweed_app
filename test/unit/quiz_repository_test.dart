import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/quiz/quiz_repository.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';

void main() {
  test('every Tajweed rule has library and quiz examples', () {
    final libraryRules = RulesRepository.all.map((entry) => entry.rule).toSet();
    expect(libraryRules, TajweedRule.values.toSet());

    for (final rule in TajweedRule.values) {
      final questions = QuizRepository.all
          .where((question) => question.rule == rule)
          .toList(growable: false);
      expect(
        questions,
        hasLength(5),
        reason: 'Missing quiz examples for $rule',
      );
      expect(
        questions.every((question) => question.arabicText.trim().isNotEmpty),
        isTrue,
        reason: 'Empty Arabic quiz example for $rule',
      );
    }
  });

  test('every Tajweed rule belongs to exactly one quiz level', () {
    final leveledRules = QuizRepository.levels
        .expand((level) => level.rules)
        .toList(growable: false);

    expect(leveledRules.toSet(), TajweedRule.values.toSet());
    expect(leveledRules, hasLength(TajweedRule.values.length));
  });
}
