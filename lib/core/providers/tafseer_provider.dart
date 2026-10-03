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
    'ar': 16, // Tafsir Muyassar
    'ur': 160, // Tafsir Ibn Kathir (Urdu)
    'tr': 52, // Diyanet İşleri (Turkish - uses translation as tafsir)
    'fr': 31, // Muhammad Hamidullah (French)
    'id': 33, // Indonesian Ministry of Religious Affairs
    'de': 27, // German
    'es':
        169, // Temporary fallback (English Ibn Kathir) until Spanish default is configured
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
    final matching = sourceList
        .where((source) {
          final language = (source['language_name'] as String? ?? '')
              .toLowerCase();
          return language == targetLanguage;
        })
        .toList(growable: false);
    if (matching.isNotEmpty) return matching;

    return sourceList
        .where((source) {
          final language = (source['language_name'] as String? ?? '')
              .toLowerCase();
          return language == 'english';
        })
        .toList(growable: false);
  }

  /// Canonical works whose localized names already live in
  /// [_localizedTafsirNames] under a representative ID.
  static const Map<String, int> _canonicalWorkIds = {
    'ibn_kathir_abridged': 169,
    'ibn_kathir': 14,
    'muyassar': 16,
    'tabari': 15,
    'qurtubi': 90,
    'saadi': 91,
    'wasit': 93,
    'baghawi': 94,
  };

  /// Localized names for works the catalogue may serve under IDs that are not
  /// hard-coded above (the production catalogue differs from prelive).
  static const Map<String, Map<String, String>> _canonicalWorkNames = {
    'jalalayn': {
      'en': 'Tafsir al-Jalalayn',
      'ar': 'تفسير الجلالين',
      'ur': 'تفسیر جلالین',
      'tr': 'Celâleyn Tefsiri',
      'fr': 'Tafsir al-Jalalayn',
      'id': 'Tafsir Jalalain',
      'de': 'Tafsir al-Dschalalain',
      'es': 'Tafsir al-Yalalayn',
    },
    'tanweer': {
      'en': 'Al-Tahrir wa al-Tanwir (Ibn Ashur)',
      'ar': 'التحرير والتنوير (ابن عاشور)',
      'ur': 'التحریر والتنویر (ابن عاشور)',
      'tr': 'et-Tahrîr ve\'t-Tenvîr (İbn Âşûr)',
      'fr': 'Al-Tahrir wa al-Tanwir (Ibn Achour)',
      'id': 'At-Tahrir wa at-Tanwir (Ibnu Asyur)',
      'de': 'At-Tahrir wa at-Tanwir (Ibn Aschur)',
      'es': 'Al-Tahrir wa al-Tanwir (Ibn Ashur)',
    },
    'maarif': {
      'en': 'Ma\'arif al-Qur\'an',
      'ar': 'معارف القرآن',
      'ur': 'معارف القرآن',
      'tr': 'Meâriful-Kur\'ân',
      'fr': 'Ma\'arif al-Qur\'an',
      'id': 'Ma\'ariful Qur\'an',
      'de': 'Ma\'arif al-Qur\'an',
      'es': 'Ma\'arif al-Qur\'an',
    },
    'tazkir': {
      'en': 'Tazkirul Quran',
      'ar': 'تذكير القرآن',
      'ur': 'تذکیر القرآن',
      'tr': 'Tezkîru\'l-Kur\'ân',
      'fr': 'Tazkirul Quran',
      'id': 'Tadzkirul Quran',
      'de': 'Tazkirul Quran',
      'es': 'Tazkirul Quran',
    },
    'fi_zilal': {
      'en': 'Fi Zilal al-Quran',
      'ar': 'في ظلال القرآن',
      'ur': 'فی ظلال القرآن',
      'tr': 'Fî Zılâli\'l-Kur\'ân',
      'fr': 'Fi Zilal al-Quran',
      'id': 'Fi Zhilalil Quran',
      'de': 'Fi Zilal al-Quran',
      'es': 'Fi Zilal al-Quran',
    },
    'bayan_ul_quran': {
      'en': 'Bayan ul Quran',
      'ar': 'بيان القرآن',
      'ur': 'بیان القرآن',
      'tr': 'Beyânü\'l-Kur\'ân',
      'fr': 'Bayan ul Quran',
      'id': 'Bayan ul Quran',
      'de': 'Bayan ul Quran',
      'es': 'Bayan ul Quran',
    },
  };

  static final RegExp _arabicScript = RegExp(r'[\u0600-\u06FF]');

  static String? _canonicalWorkKey(Iterable<String?> labels) {
    final text = labels
        .whereType<String>()
        .join(' ')
        .toLowerCase()
        .replaceAll('’', '\'');
    if (text.trim().isEmpty) return null;
    bool has(List<String> needles) => needles.any(text.contains);

    if (has(['ahsanul', 'zakaria', 'fathul'])) return null;
    if (has(['jalal', 'جلال'])) return 'jalalayn';
    if (has(['tanw', 'tahrir', 'ashur', 'ashour', 'تنوير', 'عاشور'])) {
      return 'tanweer';
    }
    if (has(['muyassar', 'ميسر', 'میسر'])) return 'muyassar';
    if (has(['tabari', 'طبري'])) return 'tabari';
    if (has(['qurtubi', 'قرطبي'])) return 'qurtubi';
    if (has(['sa\'di', 'saadi', 'saddi', 'سعدي'])) return 'saadi';
    if (has(['wasit', 'waseet', 'tantawi', 'وسيط'])) return 'wasit';
    if (has(['baghaw', 'بغوي'])) return 'baghawi';
    if (has(['kathir', 'kaseer', 'كثير', 'کثیر'])) {
      return text.contains('abridged') ? 'ibn_kathir_abridged' : 'ibn_kathir';
    }
    if (has(['ma\'arif', 'maarif'])) return 'maarif';
    if (has(['tazkir'])) return 'tazkir';
    if (has(['zilal', 'zalul'])) return 'fi_zilal';
    if (has(['bayan ul quran', 'bayan-ul-quran'])) return 'bayan_ul_quran';
    return null;
  }

  static String? _canonicalWorkName(String langCode, String? key) {
    if (key == null) return null;
    final id = _canonicalWorkIds[key];
    if (id != null) return localizedTafsirName(langCode, id);
    return _canonicalWorkNames[key]?[langCode];
  }

  /// Resolves the name a tafsir is shown under in [langCode], so the UI never
  /// mixes the catalogue's English names into another language.
  static String sourceDisplayName(
    String langCode,
    Map<String, dynamic> source,
  ) {
    final id = source['id'] as int?;
    final name = source['name']?.toString().trim() ?? '';
    final translated = source['translated_name'];
    final translatedName = translated is Map
        ? translated['name']?.toString().trim()
        : null;

    final known =
        localizedTafsirName(langCode, id) ??
        _canonicalWorkName(
          langCode,
          _canonicalWorkKey([name, source['slug']?.toString(), translatedName]),
        );
    if (known != null) return known;

    if ((langCode == 'ar' || langCode == 'ur') &&
        translatedName != null &&
        _arabicScript.hasMatch(translatedName)) {
      return translatedName;
    }
    return name;
  }

  /// Localizes a persisted tafsir [name] for display in [langCode].
  static String displayNameFor(String langCode, int id, String name) {
    return localizedTafsirName(langCode, id) ??
        _canonicalWorkName(langCode, _canonicalWorkKey([name])) ??
        name;
  }

  /// Returns the localized display name for the selected tafsir.
  String get selectedTafsirName =>
      displayNameFor(_activeLangCode, _selectedTafsirId, _selectedTafsirName);

  TafseerProvider({String langCode = 'en'}) {
    final box = Hive.box(_boxKey);
    _activeLangCode = box.get(_tafsirLangKey, defaultValue: langCode) as String;
    _selectedTafsirId =
        box.get(
              _tafsirIdKey,
              defaultValue: _defaultTafsirByLang[_activeLangCode] ?? 169,
            )
            as int;
    _selectedTafsirName =
        box.get(
              _tafsirNameKey,
              defaultValue: _defaultTafsirNames[_selectedTafsirId] ?? '',
            )
            as String;
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
