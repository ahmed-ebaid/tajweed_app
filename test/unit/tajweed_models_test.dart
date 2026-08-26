import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';

void main() {
  group('TajweedRule', () {
    test('every rule has a non-empty Arabic name', () {
      for (final rule in TajweedRule.values) {
        expect(
          rule.arabicName,
          isNotEmpty,
          reason: '${rule.name} is missing an Arabic name',
        );
      }
    });

    test('every rule has a distinct palette color', () {
      final colors = TajweedRule.values.map((r) => r.color.toARGB32()).toList();
      expect(colors.toSet().length, TajweedRule.values.length);
    });

    test('every rule meets text contrast on the Mushaf background', () {
      const background = Color(0xFFFFFCF3);
      for (final rule in TajweedRule.values) {
        expect(
          _contrastRatio(rule.color, background),
          greaterThanOrEqualTo(4.5),
          reason: '${rule.name} is too faint on the Mushaf background',
        );
      }
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
        pageNumber: 1,
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
        pageNumber: 1,
        arabic: 'بِسْمِ اللَّهِ',
        translations: {'en': 'In the name of Allah', 'de': 'Im Namen Allahs'},
        words: [],
      );
      expect(ayah.translation('de'), equals('Im Namen Allahs'));
    });

    test('plain Arabic falls back to word text for sharing', () {
      const ayah = Ayah(
        surahNumber: 1,
        ayahNumber: 1,
        pageNumber: 1,
        arabic: '',
        translations: {},
        words: [
          TajweedWord(arabic: 'بِسْمِ', spans: []),
          TajweedWord(arabic: 'اللَّهِ', spans: []),
        ],
      );

      expect(ayah.plainArabicText(), 'بِسْمِ اللَّهِ');
    });

    test('plain Arabic falls back to unmarked tajweed segments', () {
      const ayah = Ayah(
        surahNumber: 1,
        ayahNumber: 1,
        pageNumber: 1,
        arabic: '',
        translations: {},
        words: [],
        tajweedSegments: [
          TajweedSegment(text: '<ghunnah>إِنَّ</ghunnah>'),
          TajweedSegment(text: 'ا'),
        ],
      );

      expect(ayah.plainArabicText(), 'إِنَّا');
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

double _contrastRatio(Color foreground, Color background) {
  final lighter = _relativeLuminance(background);
  final darker = _relativeLuminance(foreground);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  final argb = color.toARGB32();
  final channels = [(argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF]
      .map((channel) {
        final value = channel / 255;
        return value <= 0.04045
            ? value / 12.92
            : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
      })
      .toList(growable: false);
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}
