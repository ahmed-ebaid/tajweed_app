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
        hasLength(switch (rule) {
          TajweedRule.waqf => 7,
          TajweedRule.sajdah => 1,
          _ => 5,
        }),
        reason: 'Missing quiz examples for $rule',
      );
      expect(
        questions.every((question) => question.arabicText.trim().isNotEmpty),
        isTrue,
        reason: 'Empty Arabic quiz example for $rule',
      );
      if (rule != TajweedRule.waqf && rule != TajweedRule.sajdah) {
        final examples = RulesRepository.findByRule(rule)!.exampleArabic;
        expect(
          questions.map((question) => question.arabicText).toSet(),
          containsAll(examples),
          reason: 'Quiz examples do not cover the rule data for $rule',
        );
      }
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

  test('qalqalah highlights the qalqalah letter and its sukoon only', () {
    final question = QuizRepository.all.firstWhere(
      (entry) =>
          entry.rule == TajweedRule.qalqalah &&
          entry.arabicText == '\u062A\u064E\u062C\u0652\u0631\u0650\u0649',
    );

    expect(
      question.arabicText.substring(
        question.highlightRanges.single.start,
        question.highlightRanges.single.end,
      ),
      '\u062C\u0652', // جْ
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

  test('sajdah is asked as a notation question with verse context', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
    final question = QuizRepository.all.singleWhere(
      (entry) => entry.rule == TajweedRule.sajdah,
    );

    expect(question.arabicText, contains('۩'));
    expect(
      question.arabicText.replaceAll('۩', '').trim(),
      isNotEmpty,
      reason: 'Sajdah question must show surrounding verse context',
    );

    final range = question.highlightRanges.single;
    expect(question.arabicText.substring(range.start, range.end), '۩');

    expect(question.options, hasLength(4));
    for (final languageCode in languageCodes) {
      expect(question.questionText[languageCode]?.trim(), isNotEmpty);
      expect(question.explanation[languageCode]?.trim(), isNotEmpty);
      for (var i = 0; i < question.options.length; i++) {
        expect(
          question.options[i][languageCode]?.trim(),
          isNotEmpty,
          reason: 'Missing sajdah option $i for $languageCode',
        );
      }
      // The prompt must not frame the sign as a tajweed ruling, and no option
      // may reuse a pronunciation rule name.
      final ruleNames = RulesRepository.all
          .where((entry) => entry.rule != TajweedRule.sajdah)
          .map((entry) => entry.names[languageCode])
          .whereType<String>()
          .toSet();
      for (final option in question.options) {
        expect(ruleNames, isNot(contains(option[languageCode])));
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

  test('every quiz question is complete in all supported languages', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];

    for (final question in QuizRepository.all) {
      expect(question.options, hasLength(4));
      for (final languageCode in languageCodes) {
        expect(
          question.questionText[languageCode]?.trim(),
          isNotEmpty,
          reason: '${question.rule.name} has no $languageCode prompt',
        );
        expect(
          question.explanation[languageCode]?.trim(),
          isNotEmpty,
          reason: '${question.rule.name} has no $languageCode explanation',
        );
        final options = question.options
            .map((option) => option[languageCode]?.trim())
            .toList(growable: false);
        expect(
          options,
          everyElement(isNotEmpty),
          reason:
              '${question.rule.name} has an incomplete $languageCode option',
        );
        expect(
          options.toSet(),
          hasLength(4),
          reason: '${question.rule.name} has duplicate $languageCode options',
        );
      }

      if (question.rule != TajweedRule.waqf &&
          question.rule != TajweedRule.sajdah) {
        final definition = RulesRepository.findByRule(question.rule)!;
        for (final languageCode in languageCodes) {
          expect(
            question.optionText(question.correctIndex, languageCode),
            definition.name(languageCode),
            reason:
                '${question.rule.name} has an incorrect $languageCode answer',
          );
        }
      }
    }
  });

  test(
    'rules without trigger letters omit the empty trigger-letter lead-in',
    () {
      final question = QuizRepository.all
          .where((entry) => entry.rule == TajweedRule.shaddah)
          .elementAt(1);
      const triggerLabels = [
        'Trigger letters:',
        'حروف السبب:',
        'حروفِ سبب:',
        'Tetikleyici harfler:',
        'Lettres déclencheuses :',
        'Huruf pemicu:',
        'Auslöser-Buchstaben:',
        'Letras clave:',
      ];

      for (final languageCode in [
        'en',
        'ar',
        'ur',
        'tr',
        'fr',
        'id',
        'de',
        'es',
      ]) {
        final explanation = question.explain(languageCode);
        expect(
          triggerLabels.any(explanation.contains),
          isFalse,
          reason:
              'Unexpected trigger-letter label in $languageCode explanation',
        );
        expect(explanation.trim(), isNotEmpty);
      }
    },
  );
}
