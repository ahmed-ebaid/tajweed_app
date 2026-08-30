import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/quiz/quiz_repository.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/waqf_symbols.dart';

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
        hasLength(rule == TajweedRule.waqf ? 7 : 5),
        reason: 'Missing quiz examples for $rule',
      );
      expect(
        questions.every((question) => question.arabicText.trim().isNotEmpty),
        isTrue,
        reason: 'Empty Arabic quiz example for $rule',
      );
      expect(
        questions.every(
          (question) =>
              question.highlightRanges.isNotEmpty &&
              question.highlightRanges.every(
                (range) =>
                    range.start >= 0 &&
                    range.end > range.start &&
                    range.end <= question.arabicText.length,
              ),
        ),
        isTrue,
        reason: 'Invalid quiz highlight for $rule',
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

  test('qalqalah in بَعْدَ highlights the final letter and its vowel', () {
    final question = QuizRepository.all.firstWhere(
      (entry) =>
          entry.rule == TajweedRule.qalqalah && entry.arabicText == 'بَعْدَ',
    );

    expect(
      question.arabicText.substring(
        question.highlightRanges.single.start,
        question.highlightRanges.single.end,
      ),
      'دَ',
    );
  });

  test('each Waqf sign is quizzed once with its localized meaning', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
    final questions = QuizRepository.all
        .where((question) => question.rule == TajweedRule.waqf)
        .toList(growable: false);

    for (final example in WaqfSymbols.examples) {
      final question = questions.singleWhere(
        (entry) => entry.arabicText == example.arabicText,
      );
      final highlighted = question.highlightRanges
          .map((range) => question.arabicText.substring(range.start, range.end))
          .toList(growable: false);

      expect(highlighted, everyElement(example.quranSymbol));
      expect(
        question.highlightRanges,
        hasLength(example.quranSymbol == 'ۛ' ? 2 : 1),
      );
      for (final languageCode in languageCodes) {
        expect(
          question.optionText(question.correctIndex, languageCode),
          WaqfRuleStrings(languageCode).text('name_${example.index}'),
        );
      }
    }
  });

  test('highlight question is localized in every supported language', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
    final question = QuizRepository.all.first;

    for (final languageCode in languageCodes) {
      expect(
        question.questionText[languageCode]?.trim(),
        isNotEmpty,
        reason: 'Missing highlighted question prompt for $languageCode',
      );
    }
  });
}
