import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tajweed_practice/core/services/memorization_speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late MemorizationSpeechService service;
  var available = true;
  var locales = ['en_US:English', 'ar_EG:Arabic Egypt', 'ar_SA:Arabic Saudi'];
  Completer<bool>? initialize;

  Future<void> send(String method, dynamic arguments) async {
    final complete = Completer<void>();
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) => complete.complete(),
    );
    await complete.future;
  }

  Future<void> start({
    void Function(String, bool)? result,
    void Function()? done,
    void Function(String)? error,
  }) => service.start(
    onResult: result ?? (_, _) {},
    onDone: done ?? () {},
    onError: error ?? (_) {},
  );

  setUp(() {
    service = MemorizationSpeechService(
      speech: SpeechToText.withMethodChannel(),
    );
    available = true;
    initialize = null;
    locales = ['en_US:English', 'ar_EG:Arabic Egypt', 'ar_SA:Arabic Saudi'];
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return initialize == null ? available : await initialize!.future;
        case 'locales':
          return locales;
        case 'listen':
          await send('notifyStatus', 'listening');
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    await service.cancel();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('selects Arabic explicitly and avoids Bluetooth permission', () async {
    await start();
    final initialization = calls.singleWhere(
      (call) => call.method == 'initialize',
    );
    expect((initialization.arguments as Map)['noBluetooth'], isTrue);
    final listen = calls.singleWhere((call) => call.method == 'listen');
    expect((listen.arguments as Map)['localeId'], 'ar_SA');
    // Reference Quran text is not fed to the recognizer as a completion hint.
    expect((listen.arguments as Map).containsKey('contextualStrings'), isFalse);
  });

  test('cannot fall back to English when Arabic is unavailable', () async {
    locales = ['en_US:English'];
    await expectLater(start(), throwsA(isA<MemorizationSpeechException>()));
    expect(calls.where((call) => call.method == 'listen'), isEmpty);
  });

  test('permission or native unavailability cannot start recording', () async {
    available = false;
    await expectLater(start(), throwsA(isA<MemorizationSpeechException>()));
    expect(calls.where((call) => call.method == 'listen'), isEmpty);
  });

  test(
    'late shutdown status cannot end Resume before native listening starts',
    () async {
      var done = 0;
      await start();
      await service.cancel();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'locales') {
          await send('notifyStatus', 'doneNoResult');
          return locales;
        }
        if (call.method == 'listen') {
          await send('notifyStatus', 'listening');
          return true;
        }
        return true;
      });
      await start(done: () => done++);
      expect(done, 0);
      await send('notifyStatus', 'doneNoResult');
      expect(done, 1);
    },
  );

  test(
    'cancel during initialization prevents a later microphone start',
    () async {
      initialize = Completer<bool>();
      final starting = start();
      await Future<void>.delayed(Duration.zero);
      await service.cancel();
      initialize!.complete(true);
      await starting;
      expect(calls.where((call) => call.method == 'listen'), isEmpty);
    },
  );

  test('stop while initializing cannot start the microphone later', () async {
    initialize = Completer<bool>();
    var done = 0;
    final starting = start(done: () => done++);
    await Future<void>.delayed(Duration.zero);
    await service.stop();
    initialize!.complete(true);
    await starting;
    expect(done, 1);
    expect(calls.where((call) => call.method == 'listen'), isEmpty);
  });

  test(
    'native done before final still delivers complete letter transcript',
    () async {
      final events = <String>[];
      await start(
        result: (text, finalResult) =>
            events.add('${finalResult ? 'final' : 'partial'}:$text'),
        done: () => events.add('done'),
      );
      await send(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': '1000', 'confidence': 0.95},
          ],
          'resultType': 0,
        }),
      );
      await send('notifyStatus', 'done');
      expect(events, ['partial:1000']);
      await send(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': '1000 لام ميم', 'confidence': 0.95},
          ],
          'resultType': 2,
        }),
      );
      expect(events, ['partial:1000', 'final:1000 لام ميم', 'done']);
    },
  );

  test(
    'routes partial and final callbacks without promoting partial text',
    () async {
      final results = <(String, bool)>[];
      await start(
        result: (text, finalResult) => results.add((text, finalResult)),
      );
      final words = {
        'alternates': [
          {'recognizedWords': 'بسم الله', 'confidence': 0.95},
        ],
        'resultType': 0,
      };
      await send('textRecognition', jsonEncode(words));
      expect(results, [('بسم الله', false)]);
      words['resultType'] = 2;
      await send('textRecognition', jsonEncode(words));
      expect(results.last, ('بسم الله', true));
      await service.cancel();
      await send('textRecognition', jsonEncode(words));
      expect(results, hasLength(2));
    },
  );
}
