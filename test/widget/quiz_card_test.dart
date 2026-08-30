import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/quiz/widgets/quiz_card.dart';

void main() {
  testWidgets('colors only the targeted Arabic rule segment', (tester) async {
    const arabic = 'بَعْدَ';
    final start = arabic.indexOf('دَ');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizCard(
            arabic: arabic,
            question: 'Which rule applies?',
            highlightRanges: [
              QuizHighlightRange(start: start, end: start + 'دَ'.length),
            ],
            highlightColor: Colors.red,
          ),
        ),
      ),
    );

    final arabicText = tester.widget<Text>(
      find
          .descendant(of: find.byType(QuizCard), matching: find.byType(Text))
          .first,
    );
    final rootSpan = arabicText.textSpan! as TextSpan;
    final highlightedSpan = rootSpan.children![1] as TextSpan;

    expect(highlightedSpan.text, 'دَ');
    expect(highlightedSpan.style?.color, Colors.red);
  });

  testWidgets('colors both symbols in a paired Waqf example', (tester) async {
    const arabic = 'لَا رَيْبَ ۛ فِيهِ ۛ هُدًى';
    final first = arabic.indexOf('ۛ');
    final second = arabic.indexOf('ۛ', first + 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizCard(
            arabic: arabic,
            question: 'What does this sign indicate?',
            highlightRanges: [
              QuizHighlightRange(start: first, end: first + 1),
              QuizHighlightRange(start: second, end: second + 1),
            ],
            highlightColor: Colors.red,
          ),
        ),
      ),
    );

    final arabicText = tester.widget<Text>(
      find
          .descendant(of: find.byType(QuizCard), matching: find.byType(Text))
          .first,
    );
    final rootSpan = arabicText.textSpan! as TextSpan;
    final highlighted = rootSpan.children!
        .cast<TextSpan>()
        .where((span) => span.style?.color == Colors.red)
        .map((span) => span.text)
        .toList(growable: false);

    expect(highlighted, ['ۛ', 'ۛ']);
  });
}
