import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocaleProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _localeKey = 'locale';

  /// Used only when the device language is not one of [supportedLocales].
  static const _fallbackLocaleCode = 'ar';

  // Supported locales: English, Arabic, Urdu, Turkish, French, Indonesian, German, Spanish
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('ur'),
    Locale('tr'),
    Locale('fr'),
    Locale('id'),
    Locale('de'),
    Locale('es'),
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'ar': 'العربية',
    'ur': 'اردو',
    'tr': 'Türkçe',
    'fr': 'Français',
    'id': 'Bahasa Indonesia',
    'de': 'Deutsch',
    'es': 'Español',
  };

  /// RTL languages — used to flip layout direction app-wide
  static const Set<String> rtlLanguages = {'ar', 'ur'};

  late Locale _locale;

  /// Injectable so tests can drive resolution: `PlatformDispatcher.instance` is
  /// the real dispatcher even under `TestWidgetsFlutterBinding`, so
  /// `localesTestValue` would not be observed here.
  final List<Locale> Function() _deviceLocales;

  LocaleProvider({List<Locale> Function()? deviceLocales})
    : _deviceLocales = deviceLocales ?? _platformLocales {
    _locale = _loadSaved();
  }

  static List<Locale> _platformLocales() => PlatformDispatcher.instance.locales;

  Locale get locale => _locale;

  bool get isRtl => rtlLanguages.contains(_locale.languageCode);

  /// True while the app is tracking the device language because the reader has
  /// never picked one explicitly.
  bool get followsDeviceLanguage => Hive.box(_boxKey).get(_localeKey) == null;

  /// An explicit choice always wins. Absent one, follow the device language —
  /// the key must be read as nullable rather than with a `defaultValue`, since
  /// "never chose" and "chose Arabic" are different states and the old code
  /// could not tell them apart.
  Locale _loadSaved() {
    final saved = Hive.box(_boxKey).get(_localeKey) as String?;
    if (saved != null && _isSupported(saved)) return Locale(saved);
    return _deviceLocale();
  }

  /// Defers to Flutter's standard locale resolution, so device preferences
  /// with country or script codes (`pt_BR`, `zh_Hant`) and the full ordered
  /// preference list are handled by the same rules the framework uses for its
  /// own localizations, rather than a hand-rolled match.
  ///
  /// `basicLocaleListResolution` falls back to `supportedLocales.first`, so
  /// the "nothing matched" case is detected up front to honour the app's own
  /// Arabic fallback instead.
  ///
  /// Read from the device rather than the binding so this works before
  /// `WidgetsBinding` is initialised. iOS and Android both relaunch the app
  /// when the system language changes, so resolving once at startup is enough.
  Locale _deviceLocale() {
    final preferred = _deviceLocales();
    if (!preferred.any((l) => _isSupported(l.languageCode))) {
      return const Locale(_fallbackLocaleCode);
    }
    return basicLocaleListResolution(preferred, supportedLocales);
  }

  static bool _isSupported(String languageCode) =>
      supportedLocales.any((l) => l.languageCode == languageCode);

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    _locale = locale;
    final box = Hive.box(_boxKey);
    await box.put(_localeKey, locale.languageCode);
    notifyListeners();
  }
}
