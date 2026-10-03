import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

String _coloredText(InlineSpan root, Color color) {
  final result = StringBuffer();
  root.visitChildren((span) {
    if (span is TextSpan && span.style?.color == color) {
      result.write(span.text ?? '');
    }
    return true;
  });
  return result.toString();
}

void main() {
  final fixtures = [
    (
      key: '18:8',
      html: 'صَعِي<rule class=ikhafa>دًا</rule>',
      expected: 'دً',
      rule: TajweedRule.ikhfa,
    ),
    (
      key: '18:45',
      html: 'ش<rule class=idgham_ghunnah>َىۡءٍ</rule>',
      expected: 'ءٍ',
      rule: TajweedRule.idghamWithGhunnah,
    ),
    (
      key: '18:45',
      html: 'هَشِي<rule class=ikhafa>مًا</rule>',
      expected: 'مً',
      rule: TajweedRule.ikhfa,
    ),
    (
      key: '4:92',
      html: 'خَطَـ<rule class=ikhafa>ـًٔا</rule>',
      expected: 'ـًٔ',
      rule: TajweedRule.ikhfa,
    ),
  ];

  for (final fixture in fixtures) {
    Ayah mapped() => AyahMapper.fromApi({
      'verse_key': fixture.key,
      'words': [
        {'char_type_name': 'word', 'text_uthmani_tajweed': fixture.html},
      ],
    });

    test('${fixture.html} highlights only the tanween carrier', () {
      final word = mapped().words.single;
      expect(word.spans, hasLength(1));
      final span = word.spans.single;
      expect(span.rule, fixture.rule);
      expect(word.arabic.substring(span.start, span.end), fixture.expected);
      expect(word.arabic, fixture.html.replaceAll(RegExp(r'<[^>]*>'), ''));
      expect(
        AyahMapper.unmatchedRuleClasses({'text_uthmani_tajweed': fixture.html}),
        isEmpty,
      );

      final styled = TextSpan(
        children: TajweedText.buildStyledWordSpans(
          word,
          baseStyle: const TextStyle(color: Colors.black),
        ),
      );
      expect(_coloredText(styled, fixture.rule.color), fixture.expected);
      expect(styled.toPlainText(), word.arabic);
    });

    testWidgets('${fixture.html} renders correctly in both reader layouts', (
      tester,
    ) async {
      for (final compact in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TajweedText(ayah: mapped(), compactFlow: compact),
            ),
          ),
        );
        final text = tester.widget<RichText>(
          find
              .descendant(
                of: find.byType(TajweedText),
                matching: find.byType(RichText),
              )
              .first,
        );
        expect(_coloredText(text.text, fixture.rule.color), fixture.expected);
      }
    });
  }

  test('the next word keeps its separately annotated trigger letter', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '18:45',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani_tajweed': 'ش<rule class=idgham_ghunnah>َىۡءٍ</rule>',
        },
        {
          'char_type_name': 'word',
          'text_uthmani_tajweed':
              '<rule class=idgham_ghunnah>م</rule>ُّ'
              '<rule class=qalaqah>قۡ</rule>تَدِرًا',
        },
      ],
    });
    final next = ayah.words.last;
    expect(next.spans, hasLength(2));
    expect(
      next.arabic.substring(next.spans.first.start, next.spans.first.end),
      'مُّ',
    );
    expect(next.spans.last.rule, TajweedRule.qalqalah);
    expect(
      next.arabic.substring(next.spans.last.start, next.spans.last.end),
      'قۡ',
    );
  });

  test('non-tanween spans retain their annotated range', () {
    final word = AyahMapper.fromApi({
      'verse_key': '18:45',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani_tajweed': 'أَ<rule class=ikhafa>نز</rule>َلۡنَـٰهُ',
        },
      ],
    }).words.single;
    expect(
      word.arabic.substring(word.spans.single.start, word.spans.single.end),
      'نزَ',
    );
  });

  test('tanween outside a noon rule tag does not move its highlight', () {
    final word = AyahMapper.fromApi({
      'verse_key': '11:12',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani_tajweed': 'كَ<rule class=ikhafa>نز</rule>ٌ',
        },
      ],
    }).words.single;
    expect(
      word.arabic.substring(word.spans.single.start, word.spans.single.end),
      'نزٌ',
    );
  });

  test('all tanween rules focus the carrier in legacy and verse markup', () {
    for (final entry in {
      'ikhfa': TajweedRule.ikhfa,
      'iqlab': TajweedRule.iqlab,
      'izhar': TajweedRule.izhar,
      'idgham_ghunnah': TajweedRule.idghamWithGhunnah,
      'idgham_no_ghunnah': TajweedRule.idghamWithoutGhunnah,
    }.entries) {
      final ayah = AyahMapper.fromApi({
        'verse_key': '1:1',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'صَعِيدًا',
            'tajweed': '<tajweed class="tajweed_${entry.key}">دًا</tajweed>',
          },
        ],
      });
      final word = ayah.words.single;
      expect(word.spans.single.rule, entry.value);
      expect(
        word.arabic.substring(word.spans.single.start, word.spans.single.end),
        'دً',
      );

      final segments = AyahMapper.parseTajweedHtml(
        'صَعِي<tajweed class=${entry.key}>دًا</tajweed>',
      );
      expect(segments.map((s) => s.text).join(), 'صَعِيدًا');
      expect(segments.where((s) => s.rule == entry.value).single.text, 'دً');
    }
  });

  test('all three tanween vowels retain their attached Quranic marks', () {
    for (final ruleClass in [
      'ikhafa',
      'iqlab',
      'izhar',
      'idgham_ghunnah',
      'idgham_no_ghunnah',
    ]) {
      for (final vowel in ['ً', 'ٌ', 'ٍ']) {
        for (final mark in ['', 'ۢ', 'ۭ']) {
          final word = AyahMapper.fromApi({
            'verse_key': '1:1',
            'words': [
              {
                'char_type_name': 'word',
                'text_uthmani_tajweed':
                    'ب<rule class=$ruleClass>َء$vowel$markا</rule>',
              },
            ],
          }).words.single;
          final span = word.spans.single;
          expect(
            word.arabic.substring(span.start, span.end),
            'ء$vowel$mark',
            reason: '$ruleClass must keep the carrier and all its marks',
          );
          final styled = TextSpan(
            children: TajweedText.buildStyledWordSpans(
              word,
              baseStyle: const TextStyle(color: Colors.black),
            ),
          );
          expect(_coloredText(styled, span.rule.color), 'ء$vowel$mark');
          expect(styled.toPlainText(), word.arabic);
        }
      }
    }
  });
}
