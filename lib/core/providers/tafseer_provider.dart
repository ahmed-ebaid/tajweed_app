import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TafseerProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _tafsirIdKey = 'tafsir_id';
  static const _tafsirLangKey = 'tafsir_lang';

  late int _selectedTafsirId;
  late String _activeLangCode;

  /// Default tafsir IDs by language — Ibn Kathir (English), Tafsir Muyassar (Arabic) etc.
  static const Map<String, int> _defaultTafsirByLang = {
    'en': 169, // Ibn Kathir (Abridged)
    'ar': 16,  // Tafsir Muyassar
    'ur': 160, // Tafsir Ibn Kathir (Urdu)
    'tr': 52,  // Diyanet İşleri (Turkish - uses translation as tafsir)
    'fr': 31,  // Muhammad Hamidullah (French)
    'id': 33,  // Indonesian Ministry of Religious Affairs
    'de': 27,  // German
    'es': 169, // Temporary fallback (English Ibn Kathir) until Spanish default is configured
  };

  int get selectedTafsirId => _selectedTafsirId;
  String get activeLangCode => _activeLangCode;

  TafseerProvider({String langCode = 'en'}) {
    final box = Hive.box(_boxKey);
    _activeLangCode = box.get(_tafsirLangKey, defaultValue: langCode) as String;
    _selectedTafsirId = box.get(_tafsirIdKey,
      defaultValue: _defaultTafsirByLang[_activeLangCode] ?? 169) as int;
  }

  Future<void> setTafsir(int id) async {
    _selectedTafsirId = id;
    final box = Hive.box(_boxKey);
    await box.put(_tafsirIdKey, id);
    notifyListeners();
  }

  /// Syncs tafseer language with app locale.
  void syncLanguage(String langCode) {
    if (langCode == _activeLangCode) return;
    _activeLangCode = langCode;
    _selectedTafsirId = defaultForLang(langCode);

    final box = Hive.box(_boxKey);
    box.put(_tafsirLangKey, langCode);
    box.put(_tafsirIdKey, _selectedTafsirId);

    notifyListeners();
  }

  /// Returns a sensible default tafsir ID for the given language.
  static int defaultForLang(String langCode) =>
      _defaultTafsirByLang[langCode] ?? 169;
}
