import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/l10n/memorization_localizations.dart';
import 'package:tajweed_practice/features/hifz/quran_asr_experiment_screen.dart';

void main() {
  const channel = MethodChannel('com.ebaidllc.tajweed_practice/quran_asr');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  late Future<Object?> Function(MethodCall) handler;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate],
        home: QuranAsrExperimentScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    calls = [];
    handler = (call) async {
      if (call.method == 'available') return true;
      if (call.method == 'check') {
        return {
          'transcript': 'الحمد لله رب العالمين',
          'durationSeconds': 5.5,
          'inferenceSeconds': 0.4,
        };
      }
      return null;
    };
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      return handler(call);
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('experiment labels exist in all supported languages', () {
    final keys = hifzTranslations['en']!.keys.where(
      (key) => key.startsWith('quran_asr_'),
    );
    for (final locale in AppLocalizations.supportedLocales) {
      for (final key in keys) {
        expect(hifzTranslations[locale.languageCode]![key], isNotEmpty);
      }
    }
  });

  if (!quranAsrExperimentEnabled) {
    testWidgets('disabled experiment never invokes native recording', (
      tester,
    ) async {
      await open(tester);
      expect(calls, isEmpty);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
    return;
  }

  testWidgets('model unavailable disables recording', (tester) async {
    handler = (call) async => call.method == 'available' ? false : null;
    await open(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('does not include'), findsOneWidget);
  });

  testWidgets('record then check shows only unverified output', (tester) async {
    await open(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Stop and check'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(calls, ['available', 'start', 'check']);
    expect(find.text('Unverified transcript'), findsOneWidget);
    expect(find.text('الحمد لله رب العالمين'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls.last, 'cancel');
  });

  testWidgets('timer checks at 30 seconds, not earlier', (tester) async {
    await open(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 29));
    expect(calls, isNot(contains('check')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(calls.where((call) => call == 'check'), hasLength(1));
  });

  testWidgets('microphone permission prompt does not cancel a pending start', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    handler = (call) async {
      if (call.method == 'available') return true;
      if (call.method == 'start') return pending.future;
      return null;
    };
    await open(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(calls, isNot(contains('cancel')));
    pending.complete(null);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Stop and check'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('native audio interruption cancels the attempt', (tester) async {
    await open(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    ServicesBinding.instance.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('interrupted'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(calls.last, 'cancel');
    expect(find.text('Recognition failed. Please try again.'), findsOneWidget);
    expect(find.text('Stop and check'), findsNothing);
  });

  testWidgets('native failure allows retry without confirming text', (
    tester,
  ) async {
    handler = (call) async {
      if (call.method == 'available') return true;
      if (call.method == 'check') {
        throw PlatformException(
          code: 'invalid_audio',
          message: 'No audible input.',
        );
      }
      return null;
    };
    await open(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Recognition failed. Please try again.'), findsOneWidget);
    expect(find.text('Unverified transcript'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('invalid native result is rejected', (tester) async {
    handler = (call) async => switch (call.method) {
      'available' => true,
      'check' => {'transcript': 'text', 'inferenceSeconds': double.nan},
      _ => null,
    };
    await open(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Recognition failed. Please try again.'), findsOneWidget);
  });

  testWidgets('background cancels and ignores an in-flight result', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    handler = (call) async {
      if (call.method == 'available') return true;
      if (call.method == 'check') return pending.future;
      return null;
    };
    await open(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls.last, 'cancel');
    pending.complete({
      'transcript': 'late transcript',
      'durationSeconds': 1,
      'inferenceSeconds': 0.1,
    });
    await tester.pumpAndSettle();
    expect(find.text('late transcript'), findsNothing);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
