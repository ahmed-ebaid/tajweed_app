import '../../core/models/tajweed_models.dart';

/// Static database of all tajweed rule definitions.
/// Descriptions are available in all 7 supported languages.
/// Used by the rules library screen and word-detail sheets.
class RulesRepository {
  static const List<TajweedRuleDefinition> all = [
    TajweedRuleDefinition(
      rule: TajweedRule.ghunnah,
      names: {
        'en': 'Ghunnah',
        'ar': 'غُنَّة',
        'ur': 'غُنَّہ',
        'tr': 'Ğunne',
        'fr': 'Ghounna',
        'id': 'Ghunnah',
        'de': 'Ghunna',
      },
      descriptions: {
        'en': 'A nasal resonance produced from the nasal passage when noon or meem carries a shaddah. Duration: 2 counts (harakaat).',
        'ar': 'صوت أنفي يخرج من الخيشوم عند النطق بالنون أو الميم المشددتين. مقداره حركتان.',
        'ur': 'ناک کی گہرائی سے نکلنے والی آواز جب نون یا میم پر تشدید ہو۔ مقدار: دو حرکات۔',
        'tr': 'Şeddeli nun veya mim harflerinin okunuşunda geniz yolundan çıkan ses. Süresi 2 hareke.',
        'fr': 'Son nasal produit par les fosses nasales lors de la prononciation de noon ou meem avec shaddah. Durée: 2 temps.',
        'id': 'Suara dengung yang keluar dari rongga hidung saat mengucapkan nun atau mim bertasydid. Ukuran: 2 harakat.',
        'de': 'Ein nasaler Klang aus der Nasenhöhle bei Nun oder Mim mit Shaddah. Dauer: 2 Zählzeiten.',
      },
      exampleArabic: ['إِنَّ', 'ثُمَّ', 'مِنَّا'],
      triggerLetters: ['ن', 'م'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.qalqalah,
      names: {
        'en': 'Qalqalah',
        'ar': 'قَلْقَلَة',
        'ur': 'قلقلہ',
        'tr': 'Kalkale',
        'fr': 'Qalqala',
        'id': 'Qalqalah',
        'de': 'Qalqala',
      },
      descriptions: {
        'en': 'An echoing/bouncing sound applied to the letters ق ط ب ج د when they have sukoon or appear at the end of a word. Minor (sughra) when mid-word, major (kubra) at the end.',
        'ar': 'اضطراب وتقلقل في المخرج عند النطق بحروف (قطبجد) ساكنة. صغرى في الوقف وكبرى في الوصل.',
        'ur': 'حروف (ق ط ب ج د) پر سکون یا وقف کی حالت میں آواز میں ارتعاش۔ لفظ کے درمیان میں صغریٰ اور آخر میں کبریٰ۔',
        'tr': 'ق ط ب ج د harfleri sükûnlu veya vakıf halindeyken çıkan sarsıntılı ses. Kelime ortasında küçük, sonda büyük kalkale.',
        'fr': 'Son vibrant/rebondissant pour les lettres ق ط ب ج د quand elles portent un sukoon ou sont en fin de mot.',
        'id': 'Suara memantul/bergema pada huruf ق ط ب ج د ketika bersukun atau berada di akhir kata.',
        'de': 'Ein hallender/vibrierender Laut bei den Buchstaben ق ط ب ج د mit Sukoon oder am Wortende.',
      },
      exampleArabic: ['قَدْ', 'يَبْسُطُ', 'بَعْدَ'],
      triggerLetters: ['ق', 'ط', 'ب', 'ج', 'د'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.maddTabeei,
      names: {
        'en': 'Madd Tabee\'i',
        'ar': 'مَدّ طَبِيعِيّ',
        'ur': 'مد طبعی',
        'tr': 'Meddi Tabii',
        'fr': 'Madd Tabii',
        'id': 'Mad Thabi\'i',
        'de': 'Madd Tabii',
      },
      descriptions: {
        'en': 'Natural elongation of a long vowel for exactly 2 counts. Triggered by alif after fathah, waw after dammah, or ya after kasrah.',
        'ar': 'مد الحرف مقدار حركتين لوجود حرف المد (الألف أو الواو أو الياء) دون سبب يوجب زيادة المد.',
        'ur': 'طبعی مد جو فتحہ کے بعد الف، ضمہ کے بعد واو، یا کسرہ کے بعد یاء آنے پر دو حرکات کا ہوتا ہے۔',
        'tr': 'Fethalı eliften, zammalı vavdan veya kesreli yadan önce gelen uzun ünlünün 2 hareke uzatılması.',
        'fr': 'Allongement naturel d\'une longue voyelle pendant exactement 2 temps. Déclenché par alif après fathah, waw après dammah, ou ya après kasrah.',
        'id': 'Pemanjangan vokal panjang selama tepat 2 harakat. Dipicu oleh alif setelah fathah, waw setelah dhammah, atau ya setelah kasrah.',
        'de': 'Natürliche Verlängerung eines langen Vokals für genau 2 Zählzeiten. Ausgelöst durch Alif nach Fathah, Waw nach Dammah oder Ya nach Kasrah.',
      },
      exampleArabic: ['قَالَ', 'يَقُولُ', 'قِيلَ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.maddMuttasil,
      names: {
        'en': 'Madd Muttasil',
        'ar': 'مَدّ مُتَّصِل',
        'ur': 'مد متصل',
        'tr': 'Meddi Muttasıl',
        'fr': 'Madd Muttasil',
        'id': 'Mad Wajib Muttasil',
        'de': 'Madd Muttasil',
      },
      descriptions: {
        'en': 'Obligatory connected madd: a madd letter followed by hamza in the same word. Duration: 4–5 counts.',
        'ar': 'مد واجب يحدث عندما يأتي حرف المد وبعده همزة في كلمة واحدة. مقداره أربع إلى خمس حركات.',
        'ur': 'واجب متصل مد: جب حرف مد اور ہمزہ ایک ہی لفظ میں ہوں۔ مقدار: چار سے پانچ حرکات۔',
        'tr': 'Vacip muttasıl med: Med harfinden sonra aynı kelimede hemze gelir. Süresi 4–5 hareke.',
        'fr': 'Madd muttasil obligatoire: lettre de madd suivie de hamza dans le même mot. Durée: 4–5 temps.',
        'id': 'Mad wajib muttasil: huruf mad diikuti hamzah dalam satu kata. Ukuran: 4–5 harakat.',
        'de': 'Obligatorisches verbundenes Madd: Madd-Buchstabe gefolgt von Hamza im selben Wort. Dauer: 4–5 Zählzeiten.',
      },
      exampleArabic: ['جَاءَ', 'سَاءَ', 'شَاءَ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.maddMunfasil,
      names: {
        'en': 'Madd Munfasil',
        'ar': 'مَدّ مُنْفَصِل',
        'ur': 'مد منفصل',
        'tr': 'Meddi Munfasıl',
        'fr': 'Madd Munfasil',
        'id': 'Mad Jaiz Munfasil',
        'de': 'Madd Munfasil',
      },
      descriptions: {
        'en': 'Permissible separated madd: a madd letter at the end of one word followed by hamza at the start of the next word. Duration: 2–5 counts (reader\'s choice).',
        'ar': 'مد جائز يحدث عندما يأتي حرف المد في آخر كلمة وهمزة في أول الكلمة التالية. مقداره من حركتين إلى خمس.',
        'ur': 'جائز منفصل مد: جب حرف مد ایک لفظ کے آخر میں اور ہمزہ اگلے لفظ کے شروع میں ہو۔ مقدار: دو سے پانچ حرکات۔',
        'tr': 'Caiz munfasıl med: Med harfi kelimenin sonunda, hemze bir sonraki kelimenin başında olur. Süresi 2–5 hareke.',
        'fr': 'Madd munfasil permis: lettre de madd en fin de mot suivie de hamza au début du mot suivant. Durée: 2–5 temps.',
        'id': 'Mad jaiz munfasil: huruf mad di akhir kata diikuti hamzah di awal kata berikutnya. Ukuran: 2–5 harakat.',
        'de': 'Erlaubtes getrenntes Madd: Madd-Buchstabe am Wortende gefolgt von Hamza am Anfang des nächsten Wortes. Dauer: 2–5 Zählzeiten.',
      },
      exampleArabic: ['فِي أَنفُسِكُمْ', 'قَالُوا آمَنَّا', 'بِمَا أُنزِلَ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.idghamWithGhunnah,
      names: {
        'en': 'Idgham with Ghunnah',
        'ar': 'إِدْغَام بِغُنَّة',
        'ur': 'ادغام بغنہ',
        'tr': 'Günne ile İdğam',
        'fr': 'Idgham avec Ghounna',
        'id': 'Idgham Bighunnah',
        'de': 'Idgham mit Ghunna',
      },
      descriptions: {
        'en': 'Merging of noon sakinah or tanween into one of the letters ي ن م و, pronounced with nasalization (ghunnah). Duration of ghunnah: 2 counts.',
        'ar': 'إدغام النون الساكنة أو التنوين في أحد حروف (ينمو) مع بقاء الغنة. مقدار الغنة حركتان.',
        'ur': 'نون ساکن یا تنوین کو حروف (ی ن م و) میں غنہ کے ساتھ ضم کرنا۔ غنہ کی مقدار دو حرکات۔',
        'tr': 'Sükûnlu nun veya tenvinin ي ن م و harflerine günneli olarak idğam edilmesi.',
        'fr': 'Fusion du noon sakinah ou tanween dans l\'un des lettres ي ن م و avec nasalisation.',
        'id': 'Memasukkan nun sukun atau tanwin ke dalam salah satu huruf ي ن م و dengan dengung.',
        'de': 'Verschmelzung von Noon Sakinah oder Tanween in einen der Buchstaben ي ن م و mit Nasalklang.',
      },
      exampleArabic: ['مِن يَّقُولُ', 'مِن نِّعْمَةٍ'],
      triggerLetters: ['ي', 'ن', 'م', 'و'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.idghamWithoutGhunnah,
      names: {
        'en': 'Idgham without Ghunnah',
        'ar': 'إِدْغَام بِلَا غُنَّة',
        'ur': 'ادغام بلا غنہ',
        'tr': 'Günnesiz İdğam',
        'fr': 'Idgham sans Ghounna',
        'id': 'Idgham Bilaghunnah',
        'de': 'Idgham ohne Ghunna',
      },
      descriptions: {
        'en': 'Merging of noon sakinah or tanween into the letters ل or ر without any nasalization. The noon disappears completely.',
        'ar': 'إدغام النون الساكنة أو التنوين في حرفي (ل ر) بدون غنة، تذوب النون كاملاً.',
        'ur': 'نون ساکن یا تنوین کو حروف ل یا ر میں بغیر غنہ کے ضم کرنا۔',
        'tr': 'Sükûnlu nun veya tenvinin ل veya ر harflerine günnesiz olarak idğam edilmesi.',
        'fr': 'Fusion du noon sakinah ou tanween dans ل ou ر sans nasalisation.',
        'id': 'Memasukkan nun sukun atau tanwin ke dalam huruf ل atau ر tanpa dengung.',
        'de': 'Verschmelzung von Noon Sakinah oder Tanween in ل oder ر ohne Nasalklang.',
      },
      exampleArabic: ['مِن رَّبِّكَ', 'هُدًى لِّلْمُتَّقِينَ'],
      triggerLetters: ['ل', 'ر'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.ikhfa,
      names: {
        'en': 'Ikhfa',
        'ar': 'إِخْفَاء',
        'ur': 'اخفاء',
        'tr': 'İhfa',
        'fr': 'Ikhfa',
        'id': 'Ikhfa',
        'de': 'Ikhfa',
      },
      descriptions: {
        'en': 'Concealment of noon sakinah or tanween before 15 letters. The noon is neither fully pronounced nor fully merged — held between the two with ghunnah for 2 counts.',
        'ar': 'إخفاء النون الساكنة أو التنوين عند 15 حرفاً مع بقاء الغنة، بحيث لا تكون النون مظهرة ولا مدغمة.',
        'ur': 'نون ساکن یا تنوین کو 15 حروف کے قریب اخفاء کرنا۔ غنہ کے ساتھ نہ پوری طرح ظاہر نہ پوری طرح ادغام۔',
        'tr': '15 harf önünde sükûnlu nun veya tenvinin gizlenerek günneli okunması.',
        'fr': 'Dissimulation du noon sakinah ou tanween devant 15 lettres avec nasalisation maintenue.',
        'id': 'Menyembunyikan nun sukun atau tanwin di hadapan 15 huruf dengan tetap mempertahankan dengung.',
        'de': 'Verbergen von Noon Sakinah oder Tanween vor 15 Buchstaben. Das Noon wird weder vollständig ausgesprochen noch vollständig verschmolzen.',
      },
      exampleArabic: ['مِن كُلِّ', 'عَنكَبُوتٌ', 'أَنتُمْ'],
      triggerLetters: ['ص', 'ذ', 'ث', 'ك', 'ج', 'ش', 'ق', 'س', 'د', 'ط', 'ز', 'ف', 'ت', 'ض', 'ظ'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.iqlab,
      names: {
        'en': 'Iqlab',
        'ar': 'إِقْلَاب',
        'ur': 'اقلاب',
        'tr': 'İklab',
        'fr': 'Iqlab',
        'id': 'Iqlab',
        'de': 'Iqlab',
      },
      descriptions: {
        'en': 'Transformation of noon sakinah or tanween into a meem sound before the letter ب, accompanied by ghunnah. The small م in the Quran marks this rule.',
        'ar': 'قلب النون الساكنة أو التنوين ميماً مخفاة عند حرف الباء مع الغنة.',
        'ur': 'نون ساکن یا تنوین کو حرف ب سے پہلے میم میں بدلنا، غنہ کے ساتھ۔',
        'tr': 'Sükûnlu nun veya tenvinin ب harfi önünde mim sesi olarak okunması ve gizlenmesi.',
        'fr': 'Transformation du noon sakinah ou tanween en son meem avant la lettre ب avec nasalisation.',
        'id': 'Mengubah nun sukun atau tanwin menjadi suara mim di hadapan huruf ب disertai dengung.',
        'de': 'Verwandlung von Noon Sakinah oder Tanween in einen Meem-Laut vor dem Buchstaben ب mit Ghunna.',
      },
      exampleArabic: ['مِنْ بَعْدِ', 'سَمِيعٌ بَصِيرٌ'],
      triggerLetters: ['ب'],
    ),

    TajweedRuleDefinition(
      rule: TajweedRule.izhar,
      names: {
        'en': 'Izhar Halqi',
        'ar': 'إِظْهَار حَلْقِيّ',
        'ur': 'اظہار حلقی',
        'tr': 'İzhar-ı Halkî',
        'fr': 'Izhar Halqi',
        'id': 'Izhar Halqi',
        'de': 'Izhar Halqi',
      },
      descriptions: {
        'en': 'Clear, distinct pronunciation of noon sakinah or tanween before the six throat letters (ء ه ع ح غ خ), with no ghunnah.',
        'ar': 'إظهار النون الساكنة أو التنوين عند حروف الحلق الستة (ء ه ع ح غ خ) بلا غنة.',
        'ur': 'نون ساکن یا تنوین کو حلقی حروف (ء ہ ع ح غ خ) کے سامنے صاف اور واضح پڑھنا بغیر غنہ کے۔',
        'tr': 'Sükûnlu nun veya tenvinin halk harfleri (ء ه ع ح غ خ) önünde günnésiz ve açık okunması.',
        'fr': 'Prononciation claire du noon sakinah ou tanween avant les six lettres gutturales sans nasalisation.',
        'id': 'Pengucapan nun sukun atau tanwin secara jelas dan terang di hadapan 6 huruf halq tanpa dengung.',
        'de': 'Klare, deutliche Aussprache von Noon Sakinah oder Tanween vor den sechs Kehlbuchstaben ohne Ghunna.',
      },
      exampleArabic: ['مَنْ آمَنَ', 'عَلِيمٌ حَكِيمٌ'],
      triggerLetters: ['ء', 'ه', 'ع', 'ح', 'غ', 'خ'],
    ),
  ];

  static TajweedRuleDefinition? findByRule(TajweedRule rule) {
    try {
      return all.firstWhere((d) => d.rule == rule);
    } catch (_) {
      return null;
    }
  }
}
