import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'hijri_calendar_service.dart';

enum SeasonalIcon {
  standard(null),
  ramadan('AppIcon-Ramadan'),
  eidAlFitr('AppIcon-EidAlFitr'),
  eidAlAdha('AppIcon-EidAlAdha');

  const SeasonalIcon(this.iosIconName);

  /// Alternate icon name registered in the iOS asset catalog; null is the
  /// primary icon.
  final String? iosIconName;
}

class SeasonalIconService {
  static const settingsBoxName = 'settings';
  static const enabledKey = 'seasonal_icon_enabled';
  static const channelName = 'com.ebaidllc.tajweed_practice/app_icon';

  static const _ramadan = 9;
  static const _shawwal = 10;
  static const _dhulHijjah = 12;

  final Box<dynamic> _settingsBox;
  final MethodChannel _channel;
  final bool _platformSupported;

  SeasonalIconService({
    Box<dynamic>? settingsBox,
    MethodChannel? channel,
    bool? platformSupported,
  }) : _settingsBox = settingsBox ?? Hive.box(settingsBoxName),
       _channel = channel ?? const MethodChannel(channelName),
       _platformSupported =
           platformSupported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  /// Android is intentionally excluded: switching launcher activity-aliases
  /// removes the home-screen shortcut on many launchers.
  bool get isPlatformSupported => _platformSupported;

  bool get isEnabled =>
      _settingsBox.get(enabledKey, defaultValue: true) != false;

  static SeasonalIcon iconFor(HijriDate hijri) {
    if (hijri.month == _ramadan) return SeasonalIcon.ramadan;
    if (hijri.month == _shawwal && hijri.day <= 3) {
      return SeasonalIcon.eidAlFitr;
    }
    if (hijri.month == _dhulHijjah && hijri.day >= 8 && hijri.day <= 13) {
      return SeasonalIcon.eidAlAdha;
    }
    return SeasonalIcon.standard;
  }

  Future<bool> isSupported() async {
    if (!_platformSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('supportsAlternateIcons') ??
          false;
    } on PlatformException catch (error) {
      debugPrint('Alternate icons unavailable: $error');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled, {DateTime? now}) async {
    await _settingsBox.put(enabledKey, enabled);
    await applyForDate(now: now);
  }

  /// Applies the expected icon, calling the platform only when it differs
  /// from the current one so iOS shows its change alert at most once.
  /// Returns true when the icon was changed.
  Future<bool> applyForDate({DateTime? now}) async {
    if (!await isSupported()) return false;
    var desired = SeasonalIcon.standard;
    if (isEnabled) {
      final hijri = await const HijriCalendarService().dateFor(
        now ?? DateTime.now(),
      );
      if (hijri == null) return false;
      desired = iconFor(hijri);
    }
    try {
      final current = await _channel.invokeMethod<String>('getIconName');
      if (current == desired.iosIconName) return false;
      await _channel.invokeMethod<void>('setIconName', {
        'name': desired.iosIconName,
      });
      return true;
    } on PlatformException catch (error) {
      debugPrint('Could not change the app icon: $error');
      return false;
    }
  }
}
