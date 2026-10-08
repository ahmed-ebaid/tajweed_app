import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
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
  testWidgets('full Quran ayah 32:15 colors tanween, never dal', (
    tester,
  ) async {
    final path = Platform.environment['QURAN_WORDS_JSON_PATH'];
    if (path == null || path.isEmpty) {
      markTestSkipped(
        'Set QURAN_WORDS_JSON_PATH for the full-ayah regression.',
      );
      return;
    }
    final data = jsonDecode(File(path).readAsStringSync()) as Map;
    final verse = (data['verses'] as List).cast<Map>().singleWhere(
      (verse) => verse['verse_key'] == '32:15',
    );
    final mapped = AyahMapper.fromApi(Map<String, dynamic>.from(verse));
    final fallback = Ayah(
      surahNumber: 32,
      ayahNumber: 15,
      pageNumber: mapped.pageNumber,
      arabic: 'سُجَّدًا وَسَبَّحُوا',
      translations: const {},
      words: const [],
      tajweedSegments: AyahMapper.parseTajweedHtml(
        'سُجَّ<tajweed class=idgham_ghunnah>دًا</tajweed> '
        '<tajweed class=idgham_ghunnah>و</tajweed>َسَبَّحُوا',
      ),
    );
    for (final ayah in [mapped, fallback]) {
      for (final compact in [false, true]) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: TajweedText(
                  ayah: ayah,
                  compactFlow: compact,
                  focusedRule: TajweedRule.idghamWithGhunnah,
                  strictFocusedRuleOnly: true,
                ),
              ),
            ),
          );
          final paragraphs = tester.widgetList<RichText>(
            find.descendant(
              of: find.byType(TajweedText),
              matching: find.byType(RichText),
            ),
          );
          final highlighted = paragraphs
              .map(
                (text) => _coloredText(
                  text.text,
                  TajweedRule.idghamWithGhunnah.color,
                ),
              )
              .join();
          expect(highlighted, contains('ً'));
          expect(highlighted, contains('و'));
          expect(highlighted, isNot(contains('د')));
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  final fixtures = [
    (
      key: '32:15',
      html: 'سُجَّ<rule class=idgham_ghunnah>دًا</rule>',
      expected: 'ً',
      rule: TajweedRule.idghamWithGhunnah,
    ),
    (
      key: '18:8',
      html: 'صَعِي<rule class=ikhafa>دًا</rule>',
      expected: 'ً',
      rule: TajweedRule.ikhfa,
    ),
    (
      key: '18:45',
      html: 'ش<rule class=idgham_ghunnah>َىۡءٍ</rule>',
      expected: 'ٍ',
      rule: TajweedRule.idghamWithGhunnah,
    ),
    (
      key: '18:45',
      html: 'هَشِي<rule class=ikhafa>مًا</rule>',
      expected: 'ً',
      rule: TajweedRule.ikhfa,
    ),
    (
      key: '4:92',
      html: 'خَطَـ<rule class=ikhafa>ـًٔا</rule>',
      expected: 'ً',
      rule: TajweedRule.ikhfa,
    ),
  ];

  testWidgets('32:15 tanween color preserves glyph placement and joining', (
    tester,
  ) async {
    final loader = FontLoader('AmiriQuran')
      ..addFont(rootBundle.load('assets/fonts/AmiriQuran.ttf'));
    await loader.load();
    final ayah = AyahMapper.fromApi({
      'verse_key': '32:15',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani_tajweed': 'سُجَّ<rule class=idgham_ghunnah>دًا</rule>',
        },
        {
          'char_type_name': 'word',
          'text_uthmani_tajweed':
              '<rule class=idgham_ghunnah>و</rule>َسَبَّحُوا',
        },
      ],
    });
    const style = TextStyle(
      fontFamily: 'AmiriQuran',
      fontSize: 56,
      color: Colors.black,
    );
    Future<List<int>> mask(InlineSpan span) async {
      final recorder = ui.PictureRecorder();
      final painter = TextPainter(text: span, textDirection: TextDirection.rtl)
        ..layout(maxWidth: 600);
      painter.paint(Canvas(recorder), const Offset(20, 20));
      final picture = recorder.endRecording();
      final image = await picture.toImage(640, 200);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      // Colored runs can rasterize with different edge alpha on Linux.
      // Compare occupied pixels, not antialiasing intensity.
      final alpha = [
        for (var i = 3; i < bytes.length; i += 4) bytes[i] > 0 ? 1 : 0,
      ];
      image.dispose();
      picture.dispose();
      painter.dispose();
      return alpha;
    }

    for (final word in ayah.words) {
      final spans = TajweedText.buildStyledWordSpans(word, baseStyle: style);
      final colored = TextSpan(style: style, children: spans);
      expect(colored.toPlainText(), word.arabic);
      expect(
        await tester.runAsync(() => mask(colored)),
        await tester.runAsync(
          () => mask(TextSpan(text: word.arabic, style: style)),
        ),
        reason: 'Color splitting must not move marks or add dotted circles',
      );
    }
    final left = TextSpan(
      children: TajweedText.buildStyledWordSpans(
        ayah.words.first,
        baseStyle: style,
      ),
    );
    final right = TextSpan(
      children: TajweedText.buildStyledWordSpans(
        ayah.words.last,
        baseStyle: style,
      ),
    );
    expect(_coloredText(left, TajweedRule.idghamWithGhunnah.color), 'ً');
    expect(_coloredText(right, TajweedRule.idghamWithGhunnah.color), 'وَ');
  });

  for (final fixture in fixtures) {
    Ayah mapped() => AyahMapper.fromApi({
      'verse_key': fixture.key,
      'words': [
        {'char_type_name': 'word', 'text_uthmani_tajweed': fixture.html},
      ],
    });

    test('${fixture.html} highlights only the tanween marks', () {
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
      for (final disabled in [true, false]) {
        final neutral = TextSpan(
          children: TajweedText.buildStyledWordSpans(
            word,
            baseStyle: const TextStyle(color: Colors.black),
            highlightEnabled: !disabled,
            suppressedRules: disabled ? const {} : {fixture.rule},
          ),
        );
        expect(_coloredText(neutral, fixture.rule.color), isEmpty);
        expect(neutral.toPlainText(), word.arabic);
      }
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

  test('all tanween rules color only marks in legacy and verse markup', () {
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
        'ً',
      );

      final segments = AyahMapper.parseTajweedHtml(
        'صَعِي<tajweed class=${entry.key}>دًا</tajweed>',
      );
      expect(segments.map((s) => s.text).join(), 'صَعِيدًا');
      expect(segments.where((s) => s.rule == entry.value).single.text, 'ً');
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
            '$vowel$mark',
            reason: '$ruleClass must color only tanween and attached marks',
          );
          final styled = TextSpan(
            children: TajweedText.buildStyledWordSpans(
              word,
              baseStyle: const TextStyle(color: Colors.black),
            ),
          );
          expect(_coloredText(styled, span.rule.color), '$vowel$mark');
          expect(styled.toPlainText(), word.arabic);
        }
      }
    }
  });
}
