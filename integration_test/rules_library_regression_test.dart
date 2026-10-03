import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajweed_practice/features/rules/rules_screen.dart';

import '../test/widget/rules_library_regression_test.dart' as regression;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  regression.main();
  if (const bool.fromEnvironment('CAPTURE_RULES_REGRESSION')) {
    testWidgets('capture Arabic Madd rows for visual verification', (
      tester,
    ) async {
      await tester.pumpWidget(
        regression.subject(
          const RulesScreen(languageCodeOverride: 'ar'),
          'ar',
          TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();
      final farq = find.byKey(const ValueKey('madd_al_farq'));
      final header = find
          .descendant(of: farq, matching: find.byType(InkWell))
          .first;
      await Scrollable.ensureVisible(tester.element(header), alignment: 0.3);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('madd-al-farq-ar-collapsed');
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: farq, matching: find.byIcon(Icons.expand_less)),
        findsOneWidget,
      );
      await binding.takeScreenshot('madd-al-farq-ar-expanded');
    });
  }
}
