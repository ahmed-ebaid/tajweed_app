import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TafseerProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _tafsirIdKey = 'tafsir_id';

  late int _selectedTafsirId;

  /// Default tafsir IDs by language — Ibn Kathir (English), Tafsir Muyassar (Arabic) etc.
  static const Map<String, int> _defaultTafsirByLang = {
    'en': 169, // Ibn Kathir (Abridged)
    'ar': 16,  // Tafsir Muyassar
    'ur': 160, // Tafsir Ibn Kathir (Urdu)
    'tr': 52,  // Diyanet İşleri (Turkish - uses translation as tafsir)
    'fr': 31,  // Muhammad Hamidullah (French)
    'id': 33,  // Indonesian Ministry of Religious Affairs
    'de': 27,  // German
  };

  int get selectedTafsirId => _selectedTafsirId;

  TafseerProvider({String langCode = 'en'}) {
    final box = Hive.box(_boxKey);
    _selectedTafsirId = box.get(_tafsirIdKey,
        defaultValue: _defaultTafsirByLang[langCode] ?? 169) as int;
  }

  Future<void> setTafsir(int id) async {
    _selectedTafsirId = id;
    final box = Hive.box(_boxKey);
    await box.put(_tafsirIdKey, id);
    notifyListeners();
  }

  /// Returns a sensible default tafsir ID for the given language.
  static int defaultForLang(String langCode) =>
      _defaultTafsirByLang[langCode] ?? 169;
}
