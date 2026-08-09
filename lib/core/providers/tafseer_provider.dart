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

  static const Map<String, String> _apiLanguageByCode = {
    'en': 'english',
    'ar': 'arabic',
    'ur': 'urdu',
    'tr': 'turkish',
    'fr': 'french',
    'id': 'indonesian',
    'de': 'german',
    'es': 'spanish',
  };

  /// Localized display names for known tafsir IDs, keyed by language code.
  static const Map<String, Map<int, String>> _localizedTafsirNames = {
    'en': {
      169: 'Ibn Kathir (Abridged)',
      16: 'Tafsir Muyassar',
      160: 'Tafsir Ibn Kathir',
      14: 'Tafsir Ibn Kathir',
      15: 'Tafsir al-Tabari',
      90: 'Al-Qurtubi',
      91: 'Al-Sa\'di',
      93: 'Al-Wasit (Tantawi)',
      94: 'Al-Baghawi',
      52: 'Diyanet İşleri',
      31: 'Muhammad Hamidullah',
      33: 'Kemenag',
      27: 'Bubenheim & Elyas',
    },
    'ar': {
      169: 'تفسير ابن كثير (مختصر)',
      16: 'التفسير الميسر',
      160: 'تفسير ابن كثير',
      14: 'تفسير ابن كثير',
      15: 'تفسير الطبري',
      90: 'تفسير القرطبي',
      91: 'تفسير السعدي',
      93: 'التفسير الوسيط (الطنطاوي)',
      94: 'تفسير البغوي',
      52: 'ديانت إشلري',
      31: 'محمد حميد الله',
      33: 'كيميناغ',
      27: 'بوبنهايم وإلياس',
    },
    'ur': {
      169: 'تفسیر ابن کثیر (مختصر)',
      16: 'تفسیر میسر',
      160: 'تفسیر ابن کثیر',
      14: 'تفسیر ابن کثیر',
      15: 'تفسیر الطبری',
      90: 'تفسیر القرطبی',
      91: 'تفسیر السعدی',
      93: 'التفسیر الوسیط (طنطاوی)',
      94: 'تفسیر البغوی',
      52: 'دیانت اشلری',
      31: 'محمد حمید اللہ',
      33: 'کیمیناغ',
      27: 'بوبنہائم اور الیاس',
    },
    'tr': {
      169: 'İbn Kesir (Kısaltılmış)',
      16: 'Tefsîrü\'l-Müyesser',
      160: 'İbn Kesir Tefsiri',
      14: 'İbn Kesir Tefsiri',
      15: 'Taberi Tefsiri',
      90: 'Kurtubi Tefsiri',
      91: 'Sa\'di Tefsiri',
      93: 'El-Vasît (Tantâvî)',
      94: 'Begavî Tefsiri',
      52: 'Diyanet İşleri',
      31: 'Muhammad Hamidullah',
      33: 'Kemenag',
      27: 'Bubenheim & Elyas',
    },
    'fr': {
      169: 'Ibn Kathir (Abrégé)',
      16: 'Tafsir Muyassar',
      160: 'Tafsir Ibn Kathir',
      14: 'Tafsir Ibn Kathir',
      15: 'Tafsir al-Tabari',
      90: 'Al-Qurtubi',
      91: 'Al-Sa\'di',
      93: 'Al-Wasit (Tantawi)',
      94: 'Al-Baghawi',
      52: 'Diyanet İşleri',
      31: 'Muhammad Hamidullah',
      33: 'Kemenag',
      27: 'Bubenheim & Elyas',
    },
    'id': {
      169: 'Ibn Kathir (Ringkas)',
      16: 'Tafsir Muyassar',
      160: 'Tafsir Ibn Kathir',
      14: 'Tafsir Ibn Kathir',
      15: 'Tafsir al-Tabari',
      90: 'Al-Qurtubi',
      91: 'Al-Sa\'di',
      93: 'Al-Wasit (Tantawi)',
      94: 'Al-Baghawi',
      52: 'Diyanet İşleri',
      31: 'Muhammad Hamidullah',
      33: 'Kemenag',
      27: 'Bubenheim & Elyas',
    },
    'de': {
      169: 'Ibn Kathir (Kurzfassung)',
      16: 'Tafsir Muyassar',
      160: 'Tafsir Ibn Kathir',
      14: 'Tafsir Ibn Kathir',
      15: 'Tafsir al-Tabari',
      90: 'Al-Qurtubi',
      91: 'Al-Sa\'di',
      93: 'Al-Wasit (Tantawi)',
      94: 'Al-Baghawi',
      52: 'Diyanet İşleri',
      31: 'Muhammad Hamidullah',
      33: 'Kemenag',
      27: 'Bubenheim & Elyas',
    },
    'es': {
      169: 'Ibn Kathir (Abreviado)',
      16: 'Tafsir Muyassar',
      160: 'Tafsir Ibn Kathir',
      14: 'Tafsir Ibn Kathir',
      15: 'Tafsir al-Tabari',
      90: 'Al-Qurtubi',
      91: 'Al-Sa\'di',
      93: 'Al-Wasit (Tantawi)',
      94: 'Al-Baghawi',
      52: 'Diyanet İşleri',
      31: 'Muhammad Hamidullah',
      33: 'Kemenag',
      27: 'Bubenheim & Elyas',
    },
  };

  /// Fallback names (language-neutral) for default tafsir IDs.
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

  /// Returns the localized name for a given tafsir ID and language code, or null.
  static String? localizedTafsirName(String langCode, int? id) {
    if (id == null) return null;
    return _localizedTafsirNames[langCode]?[id];
  }

  static List<Map<String, dynamic>> sourcesForLanguage(
    Iterable<Map<String, dynamic>> sources,
    String langCode,
  ) {
    final sourceList = sources.toList(growable: false);
    final targetLanguage = _apiLanguageByCode[langCode] ?? 'english';
    final matching = sourceList.where((source) {
      final language =
          (source['language_name'] as String? ?? '').toLowerCase();
      return language == targetLanguage;
    }).toList(growable: false);
    if (matching.isNotEmpty) return matching;

    return sourceList.where((source) {
      final language =
          (source['language_name'] as String? ?? '').toLowerCase();
      return language == 'english';
    }).toList(growable: false);
  }

  static String sourceDisplayName(
    String langCode,
    Map<String, dynamic> source,
  ) {
    final id = source['id'] as int?;
    return localizedTafsirName(langCode, id) ??
        source['name']?.toString().trim() ??
        '';
  }

  /// Returns the localized display name for the selected tafsir.
  /// Uses the localized map first, then falls back to the persisted name.
  String get selectedTafsirName {
    final localized = _localizedTafsirNames[_activeLangCode]?[_selectedTafsirId];
    if (localized != null) return localized;
    return _selectedTafsirName;
  }

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
