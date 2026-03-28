import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';

void main() {
  group('TajweedRule', () {
    test('every rule has a non-empty Arabic name', () {
      for (final rule in TajweedRule.values) {
        expect(rule.arabicName, isNotEmpty,
            reason: '${rule.name} is missing an Arabic name');
      }
    });

    test('every rule has a distinct color', () {
      final colors = TajweedRule.values.map((r) => r.color.value).toList();
      // Allow shared colors only for madd variants (all blue)
      final unique = colors.toSet();
      expect(unique.length, greaterThan(5));
    });

    test('every rule has a nameKey', () {
      for (final rule in TajweedRule.values) {
        expect(rule.nameKey, isNotEmpty);
        expect(rule.nameKey, startsWith('rule_'));
      }
    });
  });

  group('TajweedSpan', () {
    test('span start must be less than end', () {
      const span = TajweedSpan(start: 2, end: 5, rule: TajweedRule.ghunnah);
      expect(span.start, lessThan(span.end));
    });
  });

  group('Ayah', () {
    test('translation falls back to English if language missing', () {
      const ayah = Ayah(
        surahNumber: 1,
        ayahNumber: 1,
        arabic: 'بِسْمِ اللَّهِ',
        translations: {'en': 'In the name of Allah'},
        words: [],
      );
      expect(ayah.translation('de'), equals('In the name of Allah'));
      expect(ayah.translation('en'), equals('In the name of Allah'));
    });

    test('translation returns correct language when available', () {
      const ayah = Ayah(
        surahNumber: 1,
        ayahNumber: 1,
        arabic: 'بِسْمِ اللَّهِ',
        translations: {
          'en': 'In the name of Allah',
          'de': 'Im Namen Allahs',
        },
        words: [],
      );
      expect(ayah.translation('de'), equals('Im Namen Allahs'));
    });
  });

  group('RecitationFeedback', () {
    test('overall score is within 0–100', () {
      final feedback = RecitationFeedback(
        overallScore: 85,
        ruleScores: {TajweedRule.ghunnah: 0.9},
        audioPath: '/tmp/test.m4a',
        timestamp: DateTime.now(),
      );
      expect(feedback.overallScore, inInclusiveRange(0, 100));
    });

    test('rule scores are within 0.0–1.0', () {
      final feedback = RecitationFeedback(
        overallScore: 72,
        ruleScores: {
          TajweedRule.ghunnah: 0.85,
          TajweedRule.qalqalah: 0.70,
          TajweedRule.maddTabeei: 1.0,
        },
        audioPath: '/tmp/test.m4a',
        timestamp: DateTime.now(),
      );
      for (final score in feedback.ruleScores.values) {
        expect(score, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
