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

  group('experimental context recovery', () {
    late double audioEnd;
    late int visible;
    late bool feedback;
    late List<bool> recoveryRequests;
    late List<int> requestedContexts;
    FutureOr<Object?> Function(bool)? previewReply;

    Map<String, Object> frame(bool recovery) {
      final duration = recovery
          ? requestedContexts.last.toDouble()
          : (audioEnd < 8 ? audioEnd : 8.0);
      return {
        ...report('بسم الله'),
        'windowStartSeconds': audioEnd > duration ? audioEnd - duration : 0.0,
        'durationSeconds': audioEnd < duration ? audioEnd : duration,
        if (recovery) 'recovery': true,
        if (recovery) 'contextSeconds': requestedContexts.last,
      };
    }

    Future<void> begin() => input.start(
      onResult: (text, finalResult) {
        results.add((text, finalResult));
        if (feedback) {
          unawaited(
            input.recordProgress(
              expectedIndex: 0,
              rawWords: 2,
              visibleWords: visible,
              isFinal: finalResult,
              contradictsPrefix: false,
            ),
          );
        }
      },
      onDone: () => fail('Unexpected completion'),
      onError: errors.add,
    );

    Future<void> sample(WidgetTester tester, double end) async {
      audioEnd = end;
      await tester.pump(
        Duration(milliseconds: recoveryRequests.isEmpty ? 500 : 200),
      );
    }

    Future<void> stall(WidgetTester tester) async {
      await begin();
      await sample(tester, 8);
      await sample(tester, 12);
      await sample(tester, 12.2);
    }

    setUp(() {
      audioEnd = 8;
      visible = 2;
      feedback = true;
      recoveryRequests = [];
      requestedContexts = [];
      previewReply = null;
      handler = (call) async {
        if (call.method == 'available') return true;
        if (call.method == 'check') return report('بسم الله');
        if (call.method == 'preview') {
          final recovery = call.arguments != null;
          if (recovery) {
            final arguments = call.arguments as Map<dynamic, dynamic>;
            final contextSeconds = arguments['contextSeconds'] as int;
            expectSync(contextSeconds, anyOf(12, 28));
            expectSync(arguments, {
              'recovery': true,
              'contextSeconds': contextSeconds,
            });
            requestedContexts.add(contextSeconds);
          }
          recoveryRequests.add(recovery);
          return previewReply == null
              ? frame(recovery)
              : await previewReply!(recovery);
        }
        return null;
      };
    });

    testWidgets('recovery requires an actual stall', (tester) async {
      await begin();
      await sample(tester, 4);
      await sample(tester, 8);
      await sample(tester, 8);
      expect(recoveryRequests, everyElement(false));
      await sample(tester, 8.1);
      expect(recoveryRequests, everyElement(false));
      await sample(tester, 8.2);
      expect(recoveryRequests.last, quranAsrContextRecoveryEnabled);
      expect(errors, isEmpty);
      await input.cancel();
    });

    testWidgets('wall time without advancing captured audio cannot trigger', (
      tester,
    ) async {
      await begin();
      await sample(tester, 8);
      await tester.pump(const Duration(seconds: 10));
      expect(recoveryRequests, everyElement(false));
      await input.cancel();
    });

    testWidgets(
      'advancing visible progress or absent feedback never triggers',
      (tester) async {
        await begin();
        for (final end in [8.0, 12.0, 20.0, 30.0]) {
          visible++;
          await sample(tester, end);
        }
        expect(recoveryRequests, everyElement(false));
        feedback = false;
        await sample(tester, 38);
        await sample(tester, 46);
        expect(recoveryRequests, everyElement(false));
        await input.cancel();
        recoveryRequests.clear();
        feedback = false;
        await begin();
        for (final end in [8.0, 12.0, 20.0, 30.0]) {
          await sample(tester, end);
        }
        expect(recoveryRequests, everyElement(false));
        await input.cancel();
      },
    );

    testWidgets('unsolicited recovery responses remain invalid', (
      tester,
    ) async {
      previewReply = (_) => {...frame(false), 'recovery': true};
      await begin();
      await sample(tester, 8);
      expect(errors, ['quran_asr_invalid_result']);
      expect(results, isEmpty);
    });

    if (quranAsrContextRecoveryEnabled) {
      testWidgets('cooldown uses eight audio seconds from attempt dispatch', (
        tester,
      ) async {
        await stall(tester);
        expect(recoveryRequests, [false, false, true]);
        expect(input.windowStartSeconds, closeTo(0.2, 1e-9));
        await sample(tester, 19.9);
        await sample(tester, 20);
        expect(recoveryRequests.where((value) => value), hasLength(1));
        await sample(tester, 20.1);
        await sample(tester, 20.2);
        expect(recoveryRequests.where((value) => value), hasLength(1));
        await sample(tester, 20.3);
        expect(recoveryRequests.where((value) => value), hasLength(2));
        expect(errors, isEmpty);
        await input.cancel();
      });

      testWidgets('limits retries until a zero-word prefix advances', (
        tester,
      ) async {
        visible = 0;
        await stall(tester);
        await sample(tester, 20.2);
        await sample(tester, 20.4);
        expect(requestedContexts, [12, 28]);
        await sample(tester, 28.5);
        await sample(tester, 28.6);
        expect(requestedContexts, [12, 28, 28]);
        await sample(tester, 36.8);
        await sample(tester, 37);
        expect(requestedContexts, [12, 28, 28]);
        await input.cancel();
      });

      testWidgets('recovery does not lower ordinary start watermark', (
        tester,
      ) async {
        await stall(tester);
        await sample(tester, 11);
        expect(errors, ['quran_asr_invalid_result']);
      });

      testWidgets(
        'unsuccessful recovery escalates, any advance resets context',
        (tester) async {
          await stall(tester);
          expect(requestedContexts, [12]);
          await sample(tester, 20.2);
          await sample(tester, 20.4);
          expect(requestedContexts, [12, 28]);
          await sample(tester, 28.5);
          await sample(tester, 28.6);
          expect(requestedContexts, [12, 28, 28]);
          visible++;
          await sample(tester, 30);
          await sample(tester, 38);
          await sample(tester, 38.2);
          expect(requestedContexts, [12, 28, 28, 12]);
          await input.cancel();
        },
      );

      testWidgets('a recovery visible advance resets its next context to 12', (
        tester,
      ) async {
        await begin();
        await sample(tester, 8);
        await sample(tester, 12);
        visible++;
        await sample(tester, 12.2);
        await sample(tester, 20.2);
        await sample(tester, 20.4);
        expect(requestedContexts, [12, 12]);
        await input.cancel();
      });

      testWidgets(
        'progress feedback takes effect before pending iOS diagnostics finish',
        (tester) async {
          final pending = Completer<Object?>();
          final native = handler;
          handler = (call) async =>
              call.method == 'traceProgress' ? pending.future : native(call);
          await stall(tester);
          expect(requestedContexts, [12]);
          pending.complete(null);
          await tester.pump();
          await input.cancel();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );

      for (final invalid in [
        'missing marker',
        'wrong context',
        'stale end',
        'oversize',
        'null',
      ]) {
        testWidgets('recovery rejects $invalid explicitly', (tester) async {
          previewReply = (recovery) {
            if (!recovery) return frame(false);
            return switch (invalid) {
              'missing marker' => frame(true)..remove('recovery'),
              'wrong context' => {...frame(true), 'contextSeconds': 28},
              'stale end' => {
                ...frame(true),
                'windowStartSeconds': 0.0,
                'durationSeconds': 11.9,
              },
              'oversize' => {
                ...frame(true),
                'windowStartSeconds': 0.0,
                'durationSeconds': 12.2,
              },
              _ => null,
            };
          };
          await stall(tester);
          expect(errors, ['quran_asr_invalid_result']);
          expect(results, hasLength(2));
          await tester.pump(const Duration(seconds: 10));
          expect(recoveryRequests, [false, false, true]);
        });
      }

      testWidgets('recovery accepts sub-sample end rounding only', (
        tester,
      ) async {
        previewReply = (recovery) => recovery
            ? {
                ...frame(true),
                'windowStartSeconds': 0.0,
                'durationSeconds': 12.0 - 1e-8,
              }
            : frame(false);
        await stall(tester);
        expect(errors, isEmpty);
        expect(results, hasLength(3));
        await input.cancel();
      });

      testWidgets(
        'recovery platform errors stop explicitly and reset on start',
        (tester) async {
          previewReply = (recovery) {
            if (recovery) throw PlatformException(code: 'recovery_failed');
            return frame(false);
          };
          await stall(tester);
          expect(errors, ['recovery_failed']);
          await tester.pump(const Duration(seconds: 10));
          expect(recoveryRequests, [false, false, true]);
          await input.cancel();
          recoveryRequests.clear();
          previewReply = null;
          await begin();
          await sample(tester, 30);
          expect(recoveryRequests, [false]);
          expect(errors, ['recovery_failed']);
          await input.cancel();
        },
      );

      for (final stopping in [false, true]) {
        testWidgets(
          '${stopping ? 'stop' : 'cancel'} discards pending recovery without overlap',
          (tester) async {
            final pending = Completer<Object?>();
            previewReply = (recovery) =>
                recovery ? pending.future : frame(false);
            await stall(tester);
            await tester.pump(const Duration(seconds: 10));
            expect(recoveryRequests, [false, false, true]);
            final finishing = stopping ? input.stop() : input.cancel();
            await tester.pump();
            pending.complete(frame(true));
            await finishing;
            await tester.pump(const Duration(seconds: 10));
            expect(results.where((result) => !result.$2), hasLength(2));
            expect(
              results.where((result) => result.$2),
              hasLength(stopping ? 1 : 0),
            );
            expect(recoveryRequests, [false, false, true]);
            expect(errors, isEmpty);
          },
        );
      }
    }
  });

  testWidgets('cumulative previews stay interim until stop', (tester) async {
    await start();
    await tester.pump(const Duration(milliseconds: 500));
    expect(results, [('بسم الله', false)]);
    await input.stop();
    expect(results.last, ('بسم الله الرحمن الرحيم', true));
    expect(calls, [
      'available',
      'start',
      'preview',
      'finishCapture',
      'tailPreview',
      'check',
    ]);
    expect(errors, isEmpty);
  });

  testWidgets('stop decodes the stopped tail before the final check', (
    tester,
  ) async {
    Object? tailArguments;
    handler = (call) async => switch (call.method) {
      'available' => true,
      'preview' => report('بسم الله'),
      'tailPreview' => () {
        tailArguments = call.arguments;
        return {...report('الرحمن الرحيم'), 'windowStartSeconds': 1.0};
      }(),
      'check' => report('بسم الله الرحمن'),
      _ => null,
    };
    await start();
    await tester.pump(const Duration(milliseconds: 500));
    await input.stop();
    expect(tailArguments, {'afterSeconds': 4.0});
    expect(results, [
      ('بسم الله', false),
      ('الرحمن الرحيم', false),
      ('بسم الله الرحمن', true),
    ]);
    expect(errors, isEmpty);
  });

  testWidgets('a failed or empty tail still reaches the final check', (
    tester,
  ) async {
    for (final tail in <Object? Function()>[
      () => throw PlatformException(code: 'busy'),
      () => {...report(' '), 'windowStartSeconds': 1.0},
    ]) {
      results.clear();
      handler = (call) async => switch (call.method) {
        'available' => true,
        'preview' => report('بسم الله'),
        'tailPreview' => tail(),
        'check' => report('بسم الله الرحمن الرحيم'),
        _ => null,
      };
      await start();
      await tester.pump(const Duration(milliseconds: 500));
      await input.stop();
      expect(results, [('بسم الله', false), ('بسم الله الرحمن الرحيم', true)]);
      expect(errors, isEmpty);
    }
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
    'preview reveal reports numeric audio position and latency after the frame',
    (tester) async {
      Map<dynamic, dynamic>? recorded;
      handler = (call) async {
        switch (call.method) {
          case 'available':
            return true;
          case 'preview':
            return {
              ...report('بسم الله'),
              'windowStartSeconds': 4.0,
              'durationSeconds': 8.0,
              'snapshotRequestedAtUnixMs':
                  DateTime.now().millisecondsSinceEpoch - 250,
            };
          case 'tracePreviewReveal':
            recorded = call.arguments as Map<dynamic, dynamic>;
        }
        return null;
      };
      await start();
      await tester.pump(const Duration(milliseconds: 500));
      final frame = Completer<void>();
      final pendingReveal = input.recordPreviewReveal(
        newVisibleWords: 2,
        visibleWords: 9,
        frame: frame.future,
      );
      expect(recorded, isNull);
      frame.complete();
      await pendingReveal;
      expect(recorded, {
        'generation': 1,
        'audioEndSeconds': 12.0,
        'newVisibleWords': 2,
        'visibleWords': 9,
        'snapshotToRevealMs': greaterThanOrEqualTo(250),
      });

      recorded = null;
      await input.recordPreviewReveal(
        newVisibleWords: 0,
        visibleWords: 9,
        frame: Future.value(),
      );
      expect(recorded, isNull);
      final staleFrame = Completer<void>();
      final staleReveal = input.recordPreviewReveal(
        newVisibleWords: 1,
        visibleWords: 10,
        frame: staleFrame.future,
      );
      await input.cancel();
      staleFrame.complete();
      await staleReveal;
      expect(recorded, isNull);
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

  testWidgets('first preview probes at 500ms then refreshes after 200ms', (
    tester,
  ) async {
    await start();
    await tester.pump(const Duration(milliseconds: 499));
    expect(results, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(results, [('بسم الله', false)]);
    await tester.pump(const Duration(milliseconds: 199));
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
    await tester.pump(const Duration(milliseconds: 199));
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
    expect(calls, [
      'available',
      'start',
      'preview',
      'finishCapture',
      'tailPreview',
      'check',
    ]);
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
    await tester.pump(const Duration(milliseconds: 500));
    handler = (call) async => report('بسم الكريم');
    await tester.pump(const Duration(milliseconds: 200));
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

  test(
    'cloud diagnostics include complete snapshot pairs only when enabled',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final tempDir = await Directory('build').createTemp('asr_diag_test_');
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
      final orphanWav = File('${tempDir.path}/snapshot-1.wav')
        ..writeAsBytesSync([82, 73, 70, 70]);

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
        exportPaths: () async => [
          jsonl.path,
          snapJson.path,
          snapWav.path,
          orphanWav.path,
        ],
      );
      expect(ok, isTrue);
      expect(uploadedBody?['verse_key'], '2:14');
      final snapshots = uploadedBody?['snapshots'] as List?;
      if (!quranAsrRetainDebugAudio) {
        expect(snapshots, isEmpty);
        return;
      }
      expect(snapshots, hasLength(1));
      final first = Map<String, dynamic>.from(snapshots!.single as Map);
      expect(first['slot'], 0);
      expect(first['json'], '{"slot":0,"transcript":"بسم الله"}');
      expect(first['wav_base64'], isNotEmpty);
    },
  );
}
