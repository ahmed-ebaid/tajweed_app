import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/memorization_speech_service.dart';
import 'package:tajweed_practice/core/services/quran_asr_speech_input.dart';

void main() {
  const channel = MethodChannel('com.ebaidllc.tajweed_practice/quran_asr');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  late List<(String, bool)> results;
  late List<String> errors;
  late QuranAsrSpeechInput input;
  late Future<Object?> Function(MethodCall) handler;

  Map<String, Object> report(String text) => {
    'transcript': text,
    'durationSeconds': 4.0,
    'inferenceSeconds': 0.2,
    'windowStartSeconds': 0.0,
  };
  Future<void> start() => input.start(
    onResult: (text, finalResult) => results.add((text, finalResult)),
    onDone: () => fail('Lab results must end with an explicit final or error'),
    onError: errors.add,
  );

  setUp(() {
    calls = [];
    results = [];
    errors = [];
    input = QuranAsrSpeechInput();
    handler = (call) async => switch (call.method) {
      'available' => true,
      'preview' => report('بسم الله'),
      'check' => report('بسم الله الرحمن الرحيم'),
      _ => null,
    };
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      return handler(call);
    });
  });
  tearDown(() async {
    await input.cancel();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  if (!quranAsrExperimentEnabled) {
    test('ordinary builds cannot start lab recognition', () async {
      await expectLater(start(), throwsA(isA<MemorizationSpeechException>()));
      expect(calls, isEmpty);
    });
    return;
  }

  testWidgets('cumulative previews stay interim until stop', (tester) async {
    await start();
    await tester.pump(const Duration(seconds: 1));
    expect(results, [('بسم الله', false)]);
    await input.stop();
    expect(results.last, ('بسم الله الرحمن الرحيم', true));
    expect(calls, ['available', 'start', 'preview', 'finishCapture', 'check']);
    expect(errors, isEmpty);
  });

  testWidgets('audio retention requires the explicit lab build flag', (
    tester,
  ) async {
    Object? startArguments;
    handler = (call) async {
      if (call.method == 'available') return true;
      if (call.method == 'start') startArguments = call.arguments;
      return null;
    };
    await start();
    expect(startArguments, {'retainDebugAudio': quranAsrRetainDebugAudio});
    await input.cancel();
  });

  testWidgets(
    'progress diagnostics send only numeric counters on lab iOS',
    (tester) async {
      Map<dynamic, dynamic>? recorded;
      handler = (call) async {
        if (call.method == 'traceProgress') {
          recorded = call.arguments as Map<dynamic, dynamic>;
        }
        return null;
      };
      await input.recordProgress(
        expectedIndex: 2,
        rawWords: 5,
        visibleWords: 9,
        isFinal: false,
        contradictsPrefix: true,
      );
      expect(calls, ['traceProgress']);
      expect(recorded?['expectedIndex'], 2);
      expect(recorded?['visibleWords'], 9);
      expect(recorded?['contradiction'], 1);
      expect(recorded?.values, everyElement(isA<num>()));
      expect(recorded?.keys, isNot(contains('transcript')));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'exportDiagnostics returns native file paths on lab iOS',
    (tester) async {
      handler = (call) async {
        if (call.method == 'exportDiagnostics') {
          return ['/tmp/quran-asr-diagnostics.jsonl', '/tmp/snapshot-0.wav'];
        }
        return null;
      };
      final paths = await QuranAsrSpeechInput.exportDiagnostics();
      expect(calls, ['exportDiagnostics']);
      expect(paths, [
        '/tmp/quran-asr-diagnostics.jsonl',
        '/tmp/snapshot-0.wav',
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('first preview waits one second then refreshes after 500ms', (
    tester,
  ) async {
    await start();
    await tester.pump(const Duration(milliseconds: 999));
    expect(results, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(results, [('بسم الله', false)]);
    await tester.pump(const Duration(milliseconds: 499));
    expect(results, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(results, hasLength(2));
    expect(results.every((result) => !result.$2), isTrue);
    await input.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(results, hasLength(2));
  });

  testWidgets('refresh delay starts after slow inference completes', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    handler = (call) async => switch (call.method) {
      'available' => true,
      'preview' => pending.future,
      _ => null,
    };
    await start();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(calls.where((method) => method == 'preview'), hasLength(1));
    pending.complete(report('بسم الله'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(calls.where((method) => method == 'preview'), hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls.where((method) => method == 'preview'), hasLength(2));
    await input.cancel();
  });

  testWidgets('only one preview runs and stop waits for it', (tester) async {
    final pending = Completer<Object?>();
    handler = (call) async => switch (call.method) {
      'available' => true,
      'preview' => pending.future,
      'check' => report('بسم الله'),
      _ => null,
    };
    await start();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 10));
    expect(calls.where((method) => method == 'preview'), hasLength(1));
    final stopping = input.stop();
    await tester.pump();
    expect(calls, isNot(contains('check')));
    pending.complete(report('بسم'));
    await stopping;
    expect(results, [('بسم', false), ('بسم الله', true)]);
  });

  testWidgets('Stop retains an in-flight preview before a revised final', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    handler = (call) async => switch (call.method) {
      'available' => true,
      'preview' => pending.future,
      'check' => report('صراط الذي'),
      _ => null,
    };
    await start();
    await tester.pump(const Duration(seconds: 1));
    final stopping = input.stop();
    await tester.pump();
    pending.complete({
      ...report('أنعمت عليهم غير المغضوب عليهم ولا الضالين'),
      'durationSeconds': 8.0,
      'windowStartSeconds': 65.0,
    });
    await stopping;
    expect(results, [
      ('أنعمت عليهم غير المغضوب عليهم ولا الضالين', false),
      ('صراط الذي', true),
    ]);
    expect(calls.where((call) => call == 'preview'), hasLength(1));
    expect(errors, isEmpty);
  });

  testWidgets('Stop continues to final after the active preview is cancelled', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    handler = (call) async {
      switch (call.method) {
        case 'available':
          return true;
        case 'preview':
          return pending.future;
        case 'finishCapture':
          pending.completeError(PlatformException(code: 'preview_cancelled'));
          return null;
        case 'check':
          return report('بسم الله الرحمن الرحيم');
        default:
          return null;
      }
    };
    await start();
    await tester.pump(const Duration(seconds: 1));
    await input.stop();
    expect(results, [('بسم الله الرحمن الرحيم', true)]);
    expect(calls, ['available', 'start', 'preview', 'finishCapture', 'check']);
    expect(errors, isEmpty);
  });

  testWidgets('unexpected preview cancellation remains an error', (
    tester,
  ) async {
    handler = (call) async {
      if (call.method == 'available') return true;
      if (call.method == 'preview') {
        throw PlatformException(code: 'preview_cancelled');
      }
      return null;
    };
    await start();
    await tester.pump(const Duration(seconds: 1));
    expect(errors, ['preview_cancelled']);
  });

  testWidgets('cancel discards a late preview and permits restarting', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    handler = (call) async => switch (call.method) {
      'available' => true,
      'preview' => pending.future,
      _ => null,
    };
    await start();
    await tester.pump(const Duration(seconds: 3));
    final cancelled = input.cancel();
    pending.complete(report('بسم الله'));
    await cancelled;
    expect(results, isEmpty);
    await start();
    expect(calls.where((method) => method == 'start'), hasLength(2));
    await input.cancel();
  });

  testWidgets('silence clears previews without inventing a final result', (
    tester,
  ) async {
    await start();
    await tester.pump(const Duration(seconds: 3));
    handler = (call) async => null;
    await tester.pump(const Duration(seconds: 3));
    expect(results.last, ('', false));
    expect(errors, isEmpty);
    await input.cancel();
  });

  testWidgets('cancel waits for final inference and ignores its late result', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    handler = (call) async => switch (call.method) {
      'available' => true,
      'check' => pending.future,
      _ => null,
    };
    await start();
    final stopping = input.stop();
    await tester.pump();
    var finishedCancelling = false;
    final cancelled = input.cancel().then((_) => finishedCancelling = true);
    await tester.pump();
    expect(finishedCancelling, false);
    pending.complete(report('بسم الله'));
    await stopping;
    await cancelled;
    expect(results, isEmpty);
    await start();
    await input.cancel();
  });

  testWidgets('revised words replace previous interim hypotheses', (
    tester,
  ) async {
    await start();
    await tester.pump(const Duration(seconds: 1));
    handler = (call) async => report('بسم الكريم');
    await tester.pump(const Duration(milliseconds: 500));
    expect(results, [('بسم الله', false), ('بسم الكريم', false)]);
    await input.cancel();
  });

  testWidgets('invalid report and platform failure surface errors', (
    tester,
  ) async {
    await start();
    handler = (call) async => {'transcript': 'بسم', 'durationSeconds': 31};
    await tester.pump(const Duration(seconds: 3));
    expect(errors, ['quran_asr_invalid_result']);
    expect(results, isEmpty);
    await input.cancel();
    handler = (call) async {
      if (call.method == 'available') return true;
      if (call.method == 'preview') {
        throw PlatformException(code: 'conversion_failed');
      }
      return null;
    };
    await start();
    await tester.pump(const Duration(seconds: 3));
    expect(errors.last, 'conversion_failed');
  });

  testWidgets(
    'capture continues across multiple rolling windows until stopped',
    (tester) async {
      var windowStart = 0.0;
      handler = (call) async => switch (call.method) {
        'available' => true,
        'preview' || 'check' => {
          ...report('بسم الله'),
          'durationSeconds': 30.0,
          'windowStartSeconds': windowStart,
        },
        _ => null,
      };
      await start();
      for (final offset in [0.0, 30.0, 60.0, 95.0]) {
        windowStart = offset;
        await tester.pump(const Duration(seconds: 31));
        expect(input.windowStartSeconds, offset);
      }
      expect(results.length, greaterThanOrEqualTo(4));
      expect(results.every((result) => !result.$2), isTrue);
      expect(calls.where((method) => method == 'start'), hasLength(1));
      expect(calls, isNot(contains('finishCapture')));
      expect(calls, isNot(contains('check')));
      await input.stop();
      expect(calls.where((method) => method == 'check'), hasLength(1));
      expect(results.where((result) => result.$2), hasLength(1));
      expect(errors, isEmpty);
      await start();
      expect(input.windowStartSeconds, 0);
      await input.cancel();
    },
  );

  testWidgets('invalid or backwards window offsets fail explicitly', (
    tester,
  ) async {
    await start();
    handler = (call) async => {
      ...report('بسم الله'),
      'windowStartSeconds': -1.0,
    };
    await tester.pump(const Duration(seconds: 1));
    expect(errors, ['quran_asr_invalid_result']);
    await input.cancel();
    handler = (call) async => call.method == 'available'
        ? true
        : {...report('بسم الله'), 'windowStartSeconds': 10.0};
    await start();
    await tester.pump(const Duration(seconds: 1));
    handler = (call) async => report('بسم الله');
    await tester.pump(const Duration(milliseconds: 500));
    expect(errors, ['quran_asr_invalid_result', 'quran_asr_invalid_result']);
  });

  for (final (previewStart, finalStart) in [(12.0, 0.0), (42.0, 20.0)]) {
    testWidgets(
      'final full buffer may start before short preview at $previewStart',
      (tester) async {
        handler = (call) async => switch (call.method) {
          'available' => true,
          'preview' => {
            ...report('الرحمن الرحيم'),
            'durationSeconds': 8.0,
            'windowStartSeconds': previewStart,
          },
          'check' => {
            ...report('الحمد لله رب العالمين الرحمن الرحيم'),
            'durationSeconds': 30.0,
            'windowStartSeconds': finalStart,
          },
          _ => null,
        };
        await start();
        await tester.pump(const Duration(seconds: 1));
        expect(input.windowStartSeconds, previewStart);
        await input.stop();
        expect(results.last, ('الحمد لله رب العالمين الرحمن الرحيم', true));
        expect(input.windowStartSeconds, finalStart);
        expect(errors, isEmpty);
      },
    );
  }

  testWidgets('final buffer still rejects negative window offsets', (
    tester,
  ) async {
    handler = (call) async => switch (call.method) {
      'available' => true,
      'check' => {...report('بسم الله'), 'windowStartSeconds': -1.0},
      _ => null,
    };
    await start();
    await input.stop();
    expect(errors, ['quran_asr_invalid_result']);
    expect(results, isEmpty);
  });

  test('uploadDiagnosticsToCloud includes native snapshot-N.json and .wav files', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final tempDir = await Directory.systemTemp.createTemp('asr_diag_test');
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tempDir.delete(recursive: true);
    });
    final jsonl = File('${tempDir.path}/quran-asr-diagnostics.jsonl')
      ..writeAsStringSync('{"event":"progress"}\n');
    final snapJson = File('${tempDir.path}/snapshot-0.json')
      ..writeAsStringSync('{"slot":0,"transcript":"بسم الله"}');
    final snapWav = File('${tempDir.path}/snapshot-0.wav')
      ..writeAsBytesSync([82, 73, 70, 70, 1, 2, 3, 4]);

    Map<String, dynamic>? uploadedBody;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          uploadedBody = Map<String, dynamic>.from(options.data as Map);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 201,
              data: {'status': 'saved'},
            ),
          );
        },
      ),
    );

    final ok = await QuranAsrSpeechInput.uploadDiagnosticsToCloud(
      verseKey: '2:14',
      client: dio,
      exportPaths: () async => [jsonl.path, snapJson.path, snapWav.path],
    );
    expect(ok, isTrue);
    expect(uploadedBody?['verse_key'], '2:14');
    final snapshots = uploadedBody?['snapshots'] as List?;
    expect(snapshots, hasLength(1));
    final first = Map<String, dynamic>.from(snapshots!.single as Map);
    expect(first['slot'], 0);
    expect(first['json'], '{"slot":0,"transcript":"بسم الله"}');
    expect(first['wav_base64'], isNotEmpty);
  });
}
