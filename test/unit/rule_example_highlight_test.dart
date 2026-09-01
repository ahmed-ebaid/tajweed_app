import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/rules/rule_example_highlight.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';

/// Rules whose highlight must land on the madd/lin letter alone — never on the
/// preceding consonant, its harakah, or the cause of the madd.
const _maddLetterOnlyRules = {
  TajweedRule.maddTabeei,
  TajweedRule.maddMuttasil,
  TajweedRule.maddMunfasil,
  TajweedRule.maddAridLissukun,
  TajweedRule.maddLin,
  TajweedRule.maddLazimKalimiMuthaqqal,
  TajweedRule.maddLazimKalimiMukhaffaf,
};

const _alif = '\u0627';
const _waw = '\u0648';
const _ya = '\u064A';
const _alifMaqsura = '\u0649';
const _maddah = '\u0653';
const _sukoon = '\u0652';

void main() {
  group('rule example highlights', () {
    test('every rule has one fragment per example word', () {
      for (final definition in RulesRepository.all) {
        final fragments = RuleExampleHighlight.fragments[definition.rule];
        expect(
          fragments,
          isNotNull,
          reason: 'No highlight fragments for ${definition.rule.name}',
        );
        expect(
          fragments!.length,
          definition.exampleArabic.length,
          reason:
              'Fragment count must match exampleArabic for '
              '${definition.rule.name}',
        );
      }
    });

    test('every fragment resolves inside its own example word', () {
      for (final definition in RulesRepository.all) {
        for (var i = 0; i < definition.exampleArabic.length; i++) {
          final word = definition.exampleArabic[i];
          final range = RuleExampleHighlight.rangeIn(definition.rule, word, i);
          expect(
            range,
            isNotNull,
            reason:
                'Fragment ${RuleExampleHighlight.fragmentFor(definition.rule, i)} '
                'not found in "$word" for ${definition.rule.name}',
          );
          expect(range!.start, greaterThanOrEqualTo(0));
          expect(range.end, lessThanOrEqualTo(word.length));
        }
      }
    });

    test('madd highlights cover the madd letter only', () {
      for (final rule in _maddLetterOnlyRules) {
        final definition = RulesRepository.findByRule(rule)!;
        for (var i = 0; i < definition.exampleArabic.length; i++) {
          final fragment = RuleExampleHighlight.fragmentFor(rule, i)!;

          expect(
            fragment,
            isNot(contains(' ')),
            reason: '${rule.name} highlight must not span a word break',
          );
          expect(
            fragment.length,
            lessThanOrEqualTo(2),
            reason:
                '${rule.name} highlight "$fragment" covers more than the '
                'madd letter and its mark',
          );

          final base = fragment[0];
          expect(
            [_alif, _waw, _ya, _alifMaqsura],
            contains(base),
            reason:
                '${rule.name} highlight starts on "$base", which is not a '
                'madd/lin letter',
          );
          if (fragment.length == 2) {
            expect(
              [_maddah, _sukoon],
              contains(fragment[1]),
              reason:
                  '${rule.name} highlight trails "${fragment[1]}" instead of '
                  'a maddah or sukoon',
            );
          }
        }
      }
    });

    test('madd arid lissukun highlights the waw, not the preceding ha', () {
      final definition = RulesRepository.findByRule(
        TajweedRule.maddAridLissukun,
      )!;
      final word = definition.exampleArabic.first; // يَعْمَهُونَ
      final range = RuleExampleHighlight.rangeIn(
        TajweedRule.maddAridLissukun,
        word,
        0,
      )!;

      expect(word.substring(range.start, range.end), _waw);
      expect(
        word.substring(range.start, range.end),
        isNot(contains('\u0647')),
        reason: 'The ha of يَعْمَهُونَ must stay uncoloured',
      );
    });

    test('madd lin highlights only the lin letter and its sukoon', () {
      final definition = RulesRepository.findByRule(TajweedRule.maddLin)!;
      final word = definition.exampleArabic.first; // قُرَيْشٍ
      final range = RuleExampleHighlight.rangeIn(TajweedRule.maddLin, word, 0)!;
      final highlighted = word.substring(range.start, range.end);

      expect(highlighted, '$_ya$_sukoon');
      expect(highlighted, isNot(contains('\u0631'))); // ر
      expect(highlighted, isNot(contains('\u0634'))); // ش
    });

    test('madd muttasil highlights the alif, not the hamza that causes it', () {
      final definition = RulesRepository.findByRule(TajweedRule.maddMuttasil)!;
      for (var i = 0; i < definition.exampleArabic.length; i++) {
        final word = definition.exampleArabic[i];
        final range = RuleExampleHighlight.rangeIn(
          TajweedRule.maddMuttasil,
          word,
          i,
        )!;
        final highlighted = word.substring(range.start, range.end);
        expect(highlighted, _alif);
        expect(highlighted, isNot(contains('\u0621'))); // ء
      }
    });
  });
}
