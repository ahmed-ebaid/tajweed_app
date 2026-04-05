import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocaleProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _localeKey = 'locale';

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

  LocaleProvider() {
    _locale = _loadSaved();
  }

  Locale get locale => _locale;

  bool get isRtl => rtlLanguages.contains(_locale.languageCode);

  Locale _loadSaved() {
    final box = Hive.box(_boxKey);
    final saved = box.get(_localeKey, defaultValue: 'en') as String;
    return Locale(saved);
  }

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    _locale = locale;
    final box = Hive.box(_boxKey);
    await box.put(_localeKey, locale.languageCode);
    notifyListeners();
  }
}
