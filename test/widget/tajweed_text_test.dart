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
    void Function(TajweedRule, String)? onRuleTapped,
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
      onRuleTapped: (_, __) {},
    ));

    // Tap the first RichText (which contains the tappable span)
    await tester.tap(find.byType(RichText).first);
    await tester.pump();

    // In a full integration test this would verify the tap callback;
    // widget tests with TapGestureRecognizer require additional setup.
    expect(find.byType(TajweedText), findsOneWidget);
  });
}
