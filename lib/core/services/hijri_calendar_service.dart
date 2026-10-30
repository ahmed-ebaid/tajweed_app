import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HijriDate {
  final int year;
  final int month;
  final int day;

  const HijriDate(this.year, this.month, this.day);

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Uses the OS Umm al-Qura calendar and current device time zone.
class HijriCalendarService {
  static const channelName = 'com.ebaidllc.tajweed_practice/hijri_calendar';
  final MethodChannel channel;

  const HijriCalendarService({this.channel = const MethodChannel(channelName)});

  Future<HijriDate?> dateFor(DateTime date) async {
    try {
      final values = await channel.invokeMapMethod<String, int>('getDate', {
        'millisecondsSinceEpoch': date.millisecondsSinceEpoch,
      });
      final year = values?['year'];
      final month = values?['month'];
      final day = values?['day'];
      if (year == null ||
          year <= 0 ||
          month == null ||
          month < 1 ||
          month > 12 ||
          day == null ||
          day < 1 ||
          day > 30) {
        throw const FormatException('Invalid native Hijri date');
      }
      return HijriDate(year, month, day);
    } on PlatformException catch (error) {
      debugPrint('Could not read the system Hijri calendar: $error');
    } on MissingPluginException catch (error) {
      debugPrint('System Hijri calendar unavailable: $error');
    } on FormatException catch (error) {
      debugPrint('Could not read the system Hijri calendar: $error');
    }
    return null;
  }
}
