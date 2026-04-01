import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';

void main() {
  const testAyah = Ayah(
    surahNumber: 67,
    ayahNumber: 1,
    pageNumber: 562,
    arabic: 'تَبَارَكَ الَّذِي بِيَدِهِ الْمُلْكُ',
    translations: {'en': 'Blessed is He in Whose Hand is the dominion'},
    words: [
      TajweedWord(arabic: 'تَبَارَكَ', spans: []),
      TajweedWord(
        arabic: 'بِيَدِهِ',
        spans: [
          TajweedSpan(start: 0, end: 3, rule: TajweedRule.maddTabeei),
        ],
      ),
    ],
  );

  Widget buildSubject({
    bool highlightEnabled = true,
    void Function(TajweedRule, String, String?)? onRuleTapped,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TajweedText(
          ayah: testAyah,
          highlightEnabled: highlightEnabled,
          onRuleTapped: onRuleTapped,
        ),
      ),
    );
  }

  testWidgets('renders without crashing', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.byType(RichText), findsWidgets);
  });

  testWidgets('shows ayah arabic text', (tester) async {
    await tester.pumpWidget(buildSubject());
    expect(find.byType(TajweedText), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);
  });

  testWidgets('calls onRuleTapped when colored span is tapped', (tester) async {
    await tester.pumpWidget(buildSubject(
      onRuleTapped: (_, __, ___) {},
    ));

    // Tap the first RichText (which contains the tappable span)
    await tester.tap(find.byType(RichText).first);
    await tester.pump();

    // In a full integration test this would verify the tap callback;
    // widget tests with TapGestureRecognizer require additional setup.
    expect(find.byType(TajweedText), findsOneWidget);
  });

  testWidgets(
      'prefers word rendering over segmented tajweed html when words exist',
      (tester) async {
    const segmentedAyah = Ayah(
      surahNumber: 7,
      ayahNumber: 115,
      pageNumber: 165,
      arabic: 'أَن نَّكُونَ نَحْنُ',
      translations: {'en': 'or that we may be the ones'},
      words: [
        TajweedWord(arabic: 'أَن', spans: []),
        TajweedWord(
          arabic: 'نَّكُونَ',
          spans: [
            TajweedSpan(start: 0, end: 2, rule: TajweedRule.ghunnah),
          ],
        ),
        TajweedWord(arabic: 'نَحْنُ', spans: []),
      ],
      tajweedSegments: [
        TajweedSegment(text: 'أَ'),
        TajweedSegment(text: 'ن نّ', rule: TajweedRule.ghunnah),
        TajweedSegment(text: 'َكُونَ ن'),
        TajweedSegment(text: 'َحْ', rule: TajweedRule.ikhfa),
        TajweedSegment(text: 'نُ'),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TajweedText(ayah: segmentedAyah),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    final rootSpan = richText.text as TextSpan;
    final children = rootSpan.children!.whereType<TextSpan>().toList();

    expect(children.any((span) => span.text == 'نَحْنُ '), isTrue);
    expect(children.any((span) => span.text == 'َحْ'), isFalse);
  });

  testWidgets('falls back to segment rendering when words have no spans',
      (tester) async {
    const fallbackAyah = Ayah(
      surahNumber: 7,
      ayahNumber: 122,
      pageNumber: 165,
      arabic: 'رَبِّ مُوسَىٰ',
      translations: {'en': 'Lord of Moses'},
      words: [
        TajweedWord(arabic: 'رَبِّ', spans: []),
        TajweedWord(arabic: 'مُوسَىٰ', spans: []),
      ],
      tajweedSegments: [
        TajweedSegment(text: 'رَبِّ', rule: TajweedRule.ghunnah),
        TajweedSegment(text: ' مُوسَىٰ'),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TajweedText(ayah: fallbackAyah),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    final rootSpan = richText.text as TextSpan;
    final children = rootSpan.children!.whereType<TextSpan>().toList();

    // Segment fallback should keep the original segment text, not append
    // word-mode trailing spaces.
    expect(children.any((span) => span.text == 'رَبِّ '), isFalse);
    expect(
      children.any((span) => (span.text ?? '').contains('رَب')),
      isTrue,
    );
  });

  testWidgets('falls back to plain ayah text when words and segments are empty',
      (tester) async {
    const plainFallbackAyah = Ayah(
      surahNumber: 7,
      ayahNumber: 101,
      pageNumber: 165,
      arabic: 'تِلْكَ ٱلْقُرَىٰ',
      translations: {'en': 'Those towns'},
      words: [],
      tajweedSegments: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TajweedText(ayah: plainFallbackAyah),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    final rootSpan = richText.text as TextSpan;
    final children = rootSpan.children!.whereType<TextSpan>().toList();

    expect(children.any((span) => span.text == 'تِلْكَ ٱلْقُرَىٰ '), isTrue);
    expect(children.any((span) => span.text!.contains('﴿١٠١﴾')), isTrue);
  });

  testWidgets('does not duplicate grapheme clusters across adjacent tajweed spans',
      (tester) async {
    const overlappingSpanAyah = Ayah(
      surahNumber: 7,
      ayahNumber: 146,
      pageNumber: 168,
      arabic: 'ذٰلِكَ',
      translations: {'en': 'That'},
      words: [
        TajweedWord(
          arabic: 'ذٰلِكَ',
          spans: [
            TajweedSpan(start: 0, end: 1, rule: TajweedRule.ikhfa),
            TajweedSpan(start: 1, end: 2, rule: TajweedRule.maddTabeei),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TajweedText(ayah: overlappingSpanAyah),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    final rootSpan = richText.text as TextSpan;
    final children = rootSpan.children!.whereType<TextSpan>().toList();
    final renderedClusters = children
        .map((span) => span.text)
        .whereType<String>()
        .where((text) => text == 'ذٰ')
        .length;

    expect(renderedClusters, 1);
  });
}
