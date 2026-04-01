import 'package:flutter/material.dart';

/// Translation strings for all 7 supported languages.
/// In production, replace with ARB files generated via `flutter gen-l10n`.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('ur'),
    Locale('tr'),
    Locale('fr'),
    Locale('id'),
    Locale('de'),
  ];

  static final Map<String, Map<String, String>> _translations = {
    // ── English ──────────────────────────────────────────────────
    'en': {
      'app_name': 'Tajweed Practice',
      'greeting': 'Assalamu Alaikum',
      'continue_journey': 'Continue your journey',
      'day_streak': 'Day streak',
      'todays_lesson': "Today's lesson",
      'complete': 'complete',
      'practice': 'Practice',
      'read_with_tajweed': 'Read with tajweed',
      'colored_highlights': 'Colored highlights',
      'rule_quiz': 'Rule quiz',
      'test_knowledge': 'Test your knowledge',
      'record_review': 'Record & Review',
      'ai_feedback': 'AI feedback',
      'rules_library': 'Rules library',
      'all_tajweed_rules': 'All tajweed rules',
      'identify_the_rule': 'Identify the rule',
      'next_question': 'Next question',
      'correct': 'Correct!',
      'not_quite': 'Not quite.',
      'overall_score': 'overall score',
      'last_session': 'Last session',
      'tap_to_record': 'Tap to start recording',
      'recording': 'Recording... tap to stop',
      'all_rules': 'All rules',
      'search_rules': 'Search rules...',
      'tab_home': 'Home',
      'tab_reader': 'Reader',
      'tab_quiz': 'Quiz',
      'tab_rules': 'Rules',
      'full_details': 'Full details',
      'full_details_in_rules_library': 'Full details in rules library',
      'examples': 'Examples',
      'trigger_letters': 'Trigger Letters',
      'how_to_pronounce': 'How to Pronounce',
      'stop': 'Stop',
      'rules_category_madd': 'Madd (Elongation)',
      'rules_category_noon_meem': 'Noon/Meem Rules',
      'rules_category_merging': 'Merging & Concealment',
      'rules_category_stops_signs': 'Stops & Signs',
      'rules_category_orthographic': 'Orthographic Rules',
      'hear_pronunciation': 'Hear pronunciation',
      'settings': 'Settings',
      'language': 'Language',
      'select_language': 'Select language',
      'surah': 'Surah',
      'ayah': 'Ayah',
      'translation': 'Translation',
    },

    // ── Arabic ────────────────────────────────────────────────────
    'ar': {
      'app_name': 'تعلم التجويد',
      'greeting': 'السلام عليكم',
      'continue_journey': 'واصل رحلتك',
      'day_streak': 'سلسلة الأيام',
      'todays_lesson': 'درس اليوم',
      'complete': 'مكتمل',
      'practice': 'التدريب',
      'read_with_tajweed': 'اقرأ بالتجويد',
      'colored_highlights': 'تظليل ملون',
      'rule_quiz': 'اختبار القواعد',
      'test_knowledge': 'اختبر معلوماتك',
      'record_review': 'تسجيل ومراجعة',
      'ai_feedback': 'تغذية راجعة بالذكاء الاصطناعي',
      'rules_library': 'مكتبة القواعد',
      'all_tajweed_rules': 'جميع أحكام التجويد',
      'identify_the_rule': 'حدد الحكم',
      'next_question': 'السؤال التالي',
      'correct': 'صحيح!',
      'not_quite': 'ليس تماماً.',
      'overall_score': 'الدرجة الإجمالية',
      'last_session': 'آخر جلسة',
      'tap_to_record': 'اضغط لبدء التسجيل',
      'recording': 'يسجل... اضغط للإيقاف',
      'all_rules': 'جميع القواعد',
      'search_rules': 'ابحث عن قاعدة...',
      'tab_home': 'الرئيسية',
      'tab_reader': 'القراءة',
      'tab_quiz': 'اختبار',
      'tab_rules': 'القواعد',
      'full_details': 'تفاصيل كاملة',
      'full_details_in_rules_library': 'التفاصيل الكاملة في مكتبة القواعد',
      'examples': 'أمثلة',
      'trigger_letters': 'حروف الحكم',
      'how_to_pronounce': 'كيفية النطق',
      'stop': 'إيقاف',
      'rules_category_madd': 'أحكام المد',
      'rules_category_noon_meem': 'أحكام النون والميم',
      'rules_category_merging': 'الإدغام والإخفاء',
      'rules_category_stops_signs': 'علامات الوقف والسجدة',
      'rules_category_orthographic': 'أحكام الرسم',
      'hear_pronunciation': 'استمع إلى النطق',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'select_language': 'اختر اللغة',
      'surah': 'سورة',
      'ayah': 'آية',
      'translation': 'ترجمة',
    },

    // ── Urdu ──────────────────────────────────────────────────────
    'ur': {
      'app_name': 'تجوید مشق',
      'greeting': 'السلام علیکم',
      'continue_journey': 'اپنا سفر جاری رکھیں',
      'day_streak': 'روزانہ سلسلہ',
      'todays_lesson': 'آج کا سبق',
      'complete': 'مکمل',
      'practice': 'مشق',
      'read_with_tajweed': 'تجوید سے پڑھیں',
      'colored_highlights': 'رنگین روشنی',
      'rule_quiz': 'قواعد کا امتحان',
      'test_knowledge': 'اپنا علم آزمائیں',
      'record_review': 'ریکارڈ اور جائزہ',
      'ai_feedback': 'AI تاثرات',
      'rules_library': 'قواعد کی لائبریری',
      'all_tajweed_rules': 'تجوید کے تمام قواعد',
      'identify_the_rule': 'قاعدہ پہچانیں',
      'next_question': 'اگلا سوال',
      'correct': 'درست!',
      'not_quite': 'بالکل نہیں۔',
      'overall_score': 'مجموعی اسکور',
      'last_session': 'آخری سیشن',
      'tap_to_record': 'ریکارڈنگ شروع کرنے کے لیے دبائیں',
      'recording': 'ریکارڈنگ ہو رہی ہے...',
      'all_rules': 'تمام قواعد',
      'search_rules': 'قواعد تلاش کریں...',
      'tab_home': 'ہوم',
      'tab_reader': 'مطالعہ',
      'tab_quiz': 'کوئز',
      'tab_rules': 'قواعد',
      'full_details': 'مکمل تفصیل',
      'full_details_in_rules_library': 'قواعد کی لائبریری میں مکمل تفصیل',
      'examples': 'مثالیں',
      'trigger_letters': 'حروفِ قاعدہ',
      'how_to_pronounce': 'تلفظ کا طریقہ',
      'stop': 'روکیں',
      'rules_category_madd': 'مد کے احکام',
      'rules_category_noon_meem': 'نون/میم کے احکام',
      'rules_category_merging': 'ادغام اور اخفاء',
      'rules_category_stops_signs': 'وقف اور سجدہ کی علامات',
      'rules_category_orthographic': 'رسمِ عثمانی کے احکام',
      'hear_pronunciation': 'تلفظ سنیں',
      'settings': 'ترتیبات',
      'language': 'زبان',
      'select_language': 'زبان منتخب کریں',
      'surah': 'سورہ',
      'ayah': 'آیت',
      'translation': 'ترجمہ',
    },

    // ── Turkish ───────────────────────────────────────────────────
    'tr': {
      'app_name': 'Tecvit Pratiği',
      'greeting': 'Esselâmü Aleyküm',
      'continue_journey': 'Yolculuğuna devam et',
      'day_streak': 'Gün serisi',
      'todays_lesson': 'Bugünün dersi',
      'complete': 'tamamlandı',
      'practice': 'Pratik',
      'read_with_tajweed': 'Tecvitle oku',
      'colored_highlights': 'Renkli vurgular',
      'rule_quiz': 'Kural testi',
      'test_knowledge': 'Bilgini test et',
      'record_review': 'Kaydet ve İncele',
      'ai_feedback': 'AI geri bildirimi',
      'rules_library': 'Kurallar kütüphanesi',
      'all_tajweed_rules': 'Tüm tecvit kuralları',
      'identify_the_rule': 'Kuralı tanımla',
      'next_question': 'Sonraki soru',
      'correct': 'Doğru!',
      'not_quite': 'Pek değil.',
      'overall_score': 'genel puan',
      'last_session': 'Son oturum',
      'tap_to_record': 'Kaydetmeye başlamak için dokunun',
      'recording': 'Kaydediliyor...',
      'all_rules': 'Tüm kurallar',
      'search_rules': 'Kural ara...',
      'tab_home': 'Ana Sayfa',
      'tab_reader': 'Okuma',
      'tab_quiz': 'Quiz',
      'tab_rules': 'Kurallar',
      'full_details': 'Tam detaylar',
      'full_details_in_rules_library': 'Kurallar kitapliginda tam detaylar',
      'examples': 'Örnekler',
      'trigger_letters': 'Tetik Harfler',
      'how_to_pronounce': 'Nasıl Telaffuz Edilir',
      'stop': 'Durdur',
      'rules_category_madd': 'Med Kuralları',
      'rules_category_noon_meem': 'Nun/Mim Kuralları',
      'rules_category_merging': 'İdğam ve İhfa',
      'rules_category_stops_signs': 'Vakf ve Secde İşaretleri',
      'rules_category_orthographic': 'Yazım Kuralları',
      'hear_pronunciation': 'Telaffuzu dinle',
      'settings': 'Ayarlar',
      'language': 'Dil',
      'select_language': 'Dil seçin',
      'surah': 'Sure',
      'ayah': 'Ayet',
      'translation': 'Çeviri',
    },

    // ── French ────────────────────────────────────────────────────
    'fr': {
      'app_name': 'Pratique Tajweed',
      'greeting': 'Assalamu Alaikum',
      'continue_journey': 'Continuez votre parcours',
      'day_streak': 'Jours consécutifs',
      'todays_lesson': "Leçon d'aujourd'hui",
      'complete': 'complété',
      'practice': 'Pratique',
      'read_with_tajweed': 'Lire avec tajweed',
      'colored_highlights': 'Surlignage coloré',
      'rule_quiz': 'Quiz des règles',
      'test_knowledge': 'Testez vos connaissances',
      'record_review': 'Enregistrer et réviser',
      'ai_feedback': 'Retour IA',
      'rules_library': 'Bibliothèque des règles',
      'all_tajweed_rules': 'Toutes les règles de tajweed',
      'identify_the_rule': 'Identifier la règle',
      'next_question': 'Question suivante',
      'correct': 'Correct !',
      'not_quite': 'Pas tout à fait.',
      'overall_score': 'score global',
      'last_session': 'Dernière session',
      'tap_to_record': 'Appuyez pour enregistrer',
      'recording': 'Enregistrement...',
      'all_rules': 'Toutes les règles',
      'search_rules': 'Rechercher une règle...',
      'tab_home': 'Accueil',
      'tab_reader': 'Lecture',
      'tab_quiz': 'Quiz',
      'tab_rules': 'Règles',
      'full_details': 'Détails complets',
      'full_details_in_rules_library': 'Détails complets dans la bibliothèque des règles',
      'examples': 'Exemples',
      'trigger_letters': 'Lettres déclencheuses',
      'how_to_pronounce': 'Comment prononcer',
      'stop': 'Arrêter',
      'rules_category_madd': 'Règles de Madd',
      'rules_category_noon_meem': 'Règles de Noon/Meem',
      'rules_category_merging': 'Fusion et Dissimulation',
      'rules_category_stops_signs': 'Signes de Pause et Sajdah',
      'rules_category_orthographic': 'Règles Orthographiques',
      'hear_pronunciation': 'Écouter la prononciation',
      'settings': 'Paramètres',
      'language': 'Langue',
      'select_language': 'Choisir la langue',
      'surah': 'Sourate',
      'ayah': 'Verset',
      'translation': 'Traduction',
    },

    // ── Indonesian ────────────────────────────────────────────────
    'id': {
      'app_name': 'Latihan Tajwid',
      'greeting': 'Assalamu Alaikum',
      'continue_journey': 'Lanjutkan perjalananmu',
      'day_streak': 'Hari berturut-turut',
      'todays_lesson': 'Pelajaran hari ini',
      'complete': 'selesai',
      'practice': 'Latihan',
      'read_with_tajweed': 'Baca dengan tajwid',
      'colored_highlights': 'Sorotan warna',
      'rule_quiz': 'Kuis aturan',
      'test_knowledge': 'Uji pengetahuanmu',
      'record_review': 'Rekam & Tinjau',
      'ai_feedback': 'Umpan balik AI',
      'rules_library': 'Perpustakaan aturan',
      'all_tajweed_rules': 'Semua aturan tajwid',
      'identify_the_rule': 'Identifikasi aturan',
      'next_question': 'Pertanyaan berikutnya',
      'correct': 'Benar!',
      'not_quite': 'Belum tepat.',
      'overall_score': 'skor keseluruhan',
      'last_session': 'Sesi terakhir',
      'tap_to_record': 'Ketuk untuk mulai merekam',
      'recording': 'Merekam...',
      'all_rules': 'Semua aturan',
      'search_rules': 'Cari aturan...',
      'tab_home': 'Beranda',
      'tab_reader': 'Baca',
      'tab_quiz': 'Kuis',
      'tab_rules': 'Aturan',
      'full_details': 'Detail lengkap',
      'full_details_in_rules_library': 'Detail lengkap di pustaka aturan',
      'examples': 'Contoh',
      'trigger_letters': 'Huruf Pemicu',
      'how_to_pronounce': 'Cara Pengucapan',
      'stop': 'Berhenti',
      'rules_category_madd': 'Aturan Mad',
      'rules_category_noon_meem': 'Aturan Nun/Mim',
      'rules_category_merging': 'Idgham dan Ikhfa',
      'rules_category_stops_signs': 'Tanda Waqaf dan Sajdah',
      'rules_category_orthographic': 'Aturan Rasm',
      'hear_pronunciation': 'Dengarkan pengucapan',
      'settings': 'Pengaturan',
      'language': 'Bahasa',
      'select_language': 'Pilih bahasa',
      'surah': 'Surah',
      'ayah': 'Ayat',
      'translation': 'Terjemahan',
    },

    // ── German ────────────────────────────────────────────────────
    'de': {
      'app_name': 'Tajweed Übung',
      'greeting': 'Assalamu Alaikum',
      'continue_journey': 'Setze deine Reise fort',
      'day_streak': 'Tagessträhne',
      'todays_lesson': 'Heutige Lektion',
      'complete': 'abgeschlossen',
      'practice': 'Übung',
      'read_with_tajweed': 'Mit Tajweed lesen',
      'colored_highlights': 'Farbige Hervorhebungen',
      'rule_quiz': 'Regelquiz',
      'test_knowledge': 'Teste dein Wissen',
      'record_review': 'Aufnehmen & Überprüfen',
      'ai_feedback': 'KI-Feedback',
      'rules_library': 'Regelbibliothek',
      'all_tajweed_rules': 'Alle Tajweed-Regeln',
      'identify_the_rule': 'Regel identifizieren',
      'next_question': 'Nächste Frage',
      'correct': 'Richtig!',
      'not_quite': 'Nicht ganz.',
      'overall_score': 'Gesamtpunktzahl',
      'last_session': 'Letzte Sitzung',
      'tap_to_record': 'Tippen um aufzunehmen',
      'recording': 'Aufnahme läuft...',
      'all_rules': 'Alle Regeln',
      'search_rules': 'Regeln suchen...',
      'tab_home': 'Startseite',
      'tab_reader': 'Lesen',
      'tab_quiz': 'Quiz',
      'tab_rules': 'Regeln',
      'full_details': 'Vollständige Details',
      'full_details_in_rules_library': 'Vollständige Details in der Regelbibliothek',
      'examples': 'Beispiele',
      'trigger_letters': 'Auslöser-Buchstaben',
      'how_to_pronounce': 'Aussprache',
      'stop': 'Stoppen',
      'rules_category_madd': 'Madd-Regeln',
      'rules_category_noon_meem': 'Noon/Meem-Regeln',
      'rules_category_merging': 'Assimilation und Verbergen',
      'rules_category_stops_signs': 'Stopp- und Sajdah-Zeichen',
      'rules_category_orthographic': 'Orthographische Regeln',
      'hear_pronunciation': 'Aussprache anhören',
      'settings': 'Einstellungen',
      'language': 'Sprache',
      'select_language': 'Sprache auswählen',
      'surah': 'Sure',
      'ayah': 'Vers',
      'translation': 'Übersetzung',
    },
  };

  String get(String key) {
    final lang = locale.languageCode;
    return _translations[lang]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  // Convenience getters
  String get appName => get('app_name');
  String get greeting => get('greeting');
  String get continueJourney => get('continue_journey');
  String get dayStreak => get('day_streak');
  String get todaysLesson => get('todays_lesson');
  String get practice => get('practice');
  String get readWithTajweed => get('read_with_tajweed');
  String get ruleQuiz => get('rule_quiz');
  String get recordReview => get('record_review');
  String get rulesLibrary => get('rules_library');
  String get identifyTheRule => get('identify_the_rule');
  String get nextQuestion => get('next_question');
  String get tapToRecord => get('tap_to_record');
  String get allRules => get('all_rules');
  String get searchRules => get('search_rules');
  String get settings => get('settings');
  String get language => get('language');
  String get selectLanguage => get('select_language');
  String get hearPronunciation => get('hear_pronunciation');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
