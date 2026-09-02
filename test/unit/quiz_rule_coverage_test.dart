import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/quiz/quiz_repository.dart';

void main() {
  test('every tajweed rule is quizzable in exactly one level', () {
    final assignments = <TajweedRule, List<QuizLevel>>{};
    for (final level in QuizRepository.levels) {
      for (final rule in level.rules) {
        assignments.putIfAbsent(rule, () => []).add(level.level);
      }
    }

    final missing = TajweedRule.values
        .where((r) => !assignments.containsKey(r))
        .toList();
    expect(
      missing,
      isEmpty,
      reason:
          'New rules must be added to a QuizRepository level: '
          '${missing.map((r) => r.name).join(', ')}',
    );

    final duplicated = assignments.entries.where((e) => e.value.length > 1);
    expect(
      duplicated.map((e) => e.key.name),
      isEmpty,
      reason: 'A rule must appear in exactly one quiz level',
    );
  });

  test('every tajweed rule has at least one generated question', () {
    // QuizRepository.all is built eagerly and throws if a highlight fragment
    // is not a literal substring of its example word, so this also guards the
    // exampleArabic/_highlightFragments pair from drifting apart.
    final quizzed = QuizRepository.all.map((q) => q.rule).toSet();
    final missing = TajweedRule.values
        .where((r) => !quizzed.contains(r))
        .toList();

    expect(
      missing.map((r) => r.name),
      isEmpty,
      reason: 'Every rule needs a quiz question',
    );
  });

  test('the four madd lazim types are each quizzed separately', () {
    final lazim = TajweedRule.values
        .where((r) => r.name.startsWith('maddLazim'))
        .toList();

    expect(lazim, hasLength(4));
    for (final rule in lazim) {
      expect(
        QuizRepository.all.where((q) => q.rule == rule),
        isNotEmpty,
        reason: '${rule.name} must be quizzable',
      );
      expect(QuizRepository.questionLevel(rule), QuizLevel.advanced);
    }
  });
}
