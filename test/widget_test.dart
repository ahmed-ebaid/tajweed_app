import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic material app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Tajweed Practice'),
        ),
      ),
    );

    expect(find.text('Tajweed Practice'), findsOneWidget);
  });
}
