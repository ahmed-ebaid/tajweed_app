import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TafseerProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _tafsirIdKey = 'tafsir_id';
  static const _tafsirLangKey = 'tafsir_lang';
  static const _tafsirNameKey = 'tafsir_name';

  late int _selectedTafsirId;
  late String _activeLangCode;
  late String _selectedTafsirName;

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

  /// Known names for default tafsir IDs (used when no name has been persisted yet).
  static const Map<int, String> _defaultTafsirNames = {
    169: 'Ibn Kathir (Abridged)',
    16: 'التفسير الميسر',
    160: 'تفسير ابن كثير',
    52: 'Diyanet İşleri',
    31: 'Muhammad Hamidullah',
    33: 'Kemenag',
    27: 'Bubenheim & Elyas',
  };

  int get selectedTafsirId => _selectedTafsirId;
  String get activeLangCode => _activeLangCode;
  String get selectedTafsirName => _selectedTafsirName;

  TafseerProvider({String langCode = 'en'}) {
    final box = Hive.box(_boxKey);
    _activeLangCode = box.get(_tafsirLangKey, defaultValue: langCode) as String;
    _selectedTafsirId = box.get(_tafsirIdKey,
      defaultValue: _defaultTafsirByLang[_activeLangCode] ?? 169) as int;
    _selectedTafsirName = box.get(_tafsirNameKey,
      defaultValue: _defaultTafsirNames[_selectedTafsirId] ?? '') as String;
  }

  Future<void> setTafsir(int id, {String? name}) async {
    _selectedTafsirId = id;
    _selectedTafsirName = name ?? _defaultTafsirNames[id] ?? '';
    final box = Hive.box(_boxKey);
    await box.put(_tafsirIdKey, id);
    await box.put(_tafsirNameKey, _selectedTafsirName);
    notifyListeners();
  }

  /// Syncs tafseer language with app locale.
  void syncLanguage(String langCode) {
    if (langCode == _activeLangCode) return;
    _activeLangCode = langCode;
    _selectedTafsirId = defaultForLang(langCode);
    _selectedTafsirName = _defaultTafsirNames[_selectedTafsirId] ?? '';

    final box = Hive.box(_boxKey);
    box.put(_tafsirLangKey, langCode);
    box.put(_tafsirIdKey, _selectedTafsirId);
    box.put(_tafsirNameKey, _selectedTafsirName);

    notifyListeners();
  }

  /// Returns a sensible default tafsir ID for the given language.
  static int defaultForLang(String langCode) =>
      _defaultTafsirByLang[langCode] ?? 169;
}
