import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajweed_practice/core/services/memorization_speech_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native Arabic microphone can start and restart',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Microphone startup check')),
        ),
      );
      final speech = MemorizationSpeechService();
      final errors = <String>[];
      await tester.runAsync(() async {
        try {
          for (var attempt = 0; attempt < 2; attempt++) {
            await speech
                .start(onResult: (_, _) {}, onDone: () {}, onError: errors.add)
                .timeout(const Duration(seconds: 15));
            await Future<void>.delayed(const Duration(seconds: 1));
            expect(errors, isEmpty, reason: 'Native session ${attempt + 1}');
            await speech.cancel();
          }
        } finally {
          await speech.cancel();
        }
      });
    },
    skip: !const bool.fromEnvironment('RUN_NATIVE_MICROPHONE_TEST'),
  );
}
