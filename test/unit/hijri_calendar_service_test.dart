import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/hijri_calendar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(HijriCalendarService.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'passes the instant unchanged for native time-zone conversion',
    () async {
      final instant = DateTime.parse('2024-03-10T21:30:00Z');
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getDate');
        expect(call.arguments, {
          'millisecondsSinceEpoch': instant.millisecondsSinceEpoch,
        });
        return {'year': 1445, 'month': 9, 'day': 1};
      });
      expect(
        await const HijriCalendarService().dateFor(instant),
        const HijriDate(1445, 9, 1),
      );
    },
  );

  test(
    'rejects malformed dates instead of displaying a guessed date',
    () async {
      for (final values in [
        null,
        {'year': 1445, 'month': 0, 'day': 1},
        {'year': 1445, 'month': 13, 'day': 1},
        {'year': 1445, 'month': 9, 'day': 31},
        {'month': 9, 'day': 1},
      ]) {
        messenger.setMockMethodCallHandler(channel, (_) async => values);
        expect(
          await const HijriCalendarService().dateFor(DateTime.now()),
          isNull,
        );
      }
    },
  );

  test(
    'reports native failures without falling back to another calendar',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'calendar_failed');
      });
      expect(
        await const HijriCalendarService().dateFor(DateTime.now()),
        isNull,
      );
    },
  );
}
