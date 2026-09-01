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
        'en':
            'A nasal resonance produced from the nasal passage when noon or meem carries a shaddah. Duration: 2 counts (harakaat).',
        'ar':
            'صوت أنفي يخرج من الخيشوم عند النطق بالنون أو الميم المشددتين. مقداره حركتان.',
        'ur':
            'ناک کی گہرائی سے نکلنے والی آواز جب نون یا میم پر تشدید ہو۔ مقدار: دو حرکات۔',
        'tr':
            'Şeddeli nun veya mim harflerinin okunuşunda geniz yolundan çıkan ses. Süresi 2 hareke.',
        'fr':
            'Son nasal produit par les fosses nasales lors de la prononciation de noon ou meem avec shaddah. Durée: 2 temps.',
        'id':
            'Suara dengung yang keluar dari rongga hidung saat mengucapkan nun atau mim bertasydid. Ukuran: 2 harakat.',
        'de':
            'Ein nasaler Klang aus der Nasenhöhle bei Nun oder Mim mit Shaddah. Dauer: 2 Zählzeiten.',
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
        'en':
            'An echoing/bouncing sound applied to the letters ق ط ب ج د when they have sukoon or appear at the end of a word. Minor (sughra) when mid-word, major (kubra) at the end.',
        'ar':
            'اضطراب وتقلقل في المخرج عند النطق بحروف (قطبجد) ساكنة. تكون صغرى في وسط الكلمة، وكبرى عند الوقف في آخر الكلمة.',
        'ur':
            'حروف (ق ط ب ج د) پر سکون یا وقف کی حالت میں آواز میں ارتعاش۔ لفظ کے درمیان میں صغریٰ اور آخر میں کبریٰ۔',
        'tr':
            'ق ط ب ج د harfleri sükûnlu veya vakıf halindeyken çıkan sarsıntılı ses. Kelime ortasında küçük, sonda büyük kalkale.',
        'fr':
            'Son vibrant/rebondissant pour les lettres ق ط ب ج د quand elles portent un sukoon ou sont en fin de mot.',
        'id':
            'Suara memantul/bergema pada huruf ق ط ب ج د ketika bersukun atau berada di akhir kata.',
        'de':
            'Ein hallender/vibrierender Laut bei den Buchstaben ق ط ب ج د mit Sukoon oder am Wortende.',
      },
      exampleArabic: ['قَدْ', 'يَبْسُطُ', 'تَجْرِى'],
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
        'en':
            'Natural elongation of a madd letter for exactly 2 counts: alif after a fatha, waw after a damma, or ya after a kasra, with no hamzah and no sukoon following it.',
        'ar':
            'أن يأتي حرف المد — الألف الساكنة المفتوح ما قبلها، أو الواو الساكنة المضموم ما قبلها، أو الياء الساكنة المكسور ما قبلها — ولا يأتي بعده همز ولا سكون. مقداره: ٢ حركة (حركتان).',
        'ur':
            'حرف مد کو دو حرکات تک کھینچنا: الف جس سے پہلے فتحہ، واو جس سے پہلے ضمہ، یا یاء جس سے پہلے کسرہ ہو، اور اس کے بعد نہ ہمزہ ہو نہ سکون۔',
        'tr':
            'Med harfinin tam 2 hareke uzatılması: öncesinde fetha bulunan elif, ötre bulunan vav veya esre bulunan ya; ardından hemze de sükûn da gelmez.',
        'fr':
            'Prolongation naturelle de 2 temps d\'une lettre de madd: alif après une fatha, waw après une damma, ou ya après une kasra, sans hamza ni soukoun à sa suite.',
        'id':
            'Pemanjangan alami huruf mad selama tepat 2 harakat: alif setelah fathah, wau setelah dhammah, atau ya setelah kasrah, tanpa diikuti hamzah maupun sukun.',
        'de':
            'Natürliche Dehnung eines Madd-Buchstabens um genau 2 Zählzeiten: Alif nach Fatha, Waw nach Damma oder Ya nach Kasra, ohne folgendes Hamza und ohne Sukun.',
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
        'en':
            'Obligatory connected madd: a madd letter followed by hamza in the same word. Duration: 4–5 counts.',
        'ar':
            'مد واجب يحدث عندما يأتي حرف المد وبعده همزة في كلمة واحدة. مقداره: ٤–٥ حركات.',
        'ur':
            'واجب متصل مد: جب حرف مد اور ہمزہ ایک ہی لفظ میں ہوں۔ مقدار: چار سے پانچ حرکات۔',
        'tr':
            'Vacip muttasıl med: Med harfinden sonra aynı kelimede hemze gelir. Süresi 4–5 hareke.',
        'fr':
            'Madd muttasil obligatoire: lettre de madd suivie de hamza dans le même mot. Durée: 4–5 temps.',
        'id':
            'Mad wajib muttasil: huruf mad diikuti hamzah dalam satu kata. Ukuran: 4–5 harakat.',
        'de':
            'Obligatorisches verbundenes Madd: Madd-Buchstabe gefolgt von Hamza im selben Wort. Dauer: 4–5 Zählzeiten.',
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
        'en':
            'Permissible separated madd: a madd letter at the end of one word followed by hamza at the start of the next word. Duration: 2–5 counts (reader\'s choice).',
        'ar':
            'مد جائز يحدث عندما يأتي حرف المد في آخر كلمة وهمزة في أول الكلمة التالية. مقداره: ٢–٥ حركات.',
        'ur':
            'جائز منفصل مد: جب حرف مد ایک لفظ کے آخر میں اور ہمزہ اگلے لفظ کے شروع میں ہو۔ مقدار: دو سے پانچ حرکات۔',
        'tr':
            'Caiz munfasıl med: Med harfi kelimenin sonunda, hemze bir sonraki kelimenin başında olur. Süresi 2–5 hareke.',
        'fr':
            'Madd munfasil permis: lettre de madd en fin de mot suivie de hamza au début du mot suivant. Durée: 2–5 temps.',
        'id':
            'Mad jaiz munfasil: huruf mad di akhir kata diikuti hamzah di awal kata berikutnya. Ukuran: 2–5 harakat.',
        'de':
            'Erlaubtes getrenntes Madd: Madd-Buchstabe am Wortende gefolgt von Hamza am Anfang des nächsten Wortes. Dauer: 2–5 Zählzeiten.',
      },
      exampleArabic: ['فِي أَنفُسِكُمْ', 'قَالُوا آمَنَّا', 'بِمَا أُنزِلَ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.maddSilahSughra,
      names: {
        'en': 'Madd Silah Sughra',
        'ar': 'مَدّ صِلَة صُغْرَى',
        'ur': 'مد صلہ صغریٰ',
        'tr': 'Medd-i Sıla Suğra',
        'fr': 'Madd Silah Sughra',
        'id': 'Mad Silah Sughra',
        'de': 'Madd Silah Sughra',
      },
      descriptions: {
        'en':
            'Minor connecting elongation of the pronoun ha when it falls between two vowelled letters and is not followed by hamza. Duration: 2 counts.',
        'ar':
            'مد هاء الضمير الواقعة بين متحركين إذا لم يأت بعدها همز. مقداره: ٢ حركة.',
        'ur':
            'ضمیر کی ہاء دو متحرک حروف کے درمیان ہو اور اس کے بعد ہمزہ نہ ہو تو اسے دو حرکات کھینچا جاتا ہے۔',
        'tr':
            'İki harekeli harf arasındaki zamir hâsı, ardından hemze gelmezse 2 hareke uzatılır.',
        'fr':
            'Allongement du ha pronominal entre deux lettres vocalisées lorsqu’il n’est pas suivi d’une hamza. Durée : 2 temps.',
        'id':
            'Pemanjangan ha dhamir di antara dua huruf berharakat bila tidak diikuti hamzah. Panjang: 2 harakat.',
        'de':
            'Verlängerung des Pronomen-Ha zwischen zwei vokalisierten Buchstaben, wenn kein Hamza folgt. Dauer: 2 Zählzeiten.',
      },
      exampleArabic: ['بِهِۦ عِلْمٌ', 'إِنَّهُۥ كَانَ'],
      triggerLetters: ['ه'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.maddSilahKubra,
      names: {
        'en': 'Madd Silah Kubra',
        'ar': 'مَدّ صِلَة كُبْرَى',
        'ur': 'مد صلہ کبریٰ',
        'tr': 'Medd-i Sıla Kübra',
        'fr': 'Madd Silah Kubra',
        'id': 'Mad Silah Kubra',
        'de': 'Madd Silah Kubra',
      },
      descriptions: {
        'en':
            'Major connecting elongation of the pronoun ha when it falls between two vowelled letters and is followed by hamza. Duration: 4–5 counts.',
        'ar':
            'مد هاء الضمير الواقعة بين متحركين إذا جاء بعدها همز. مقداره: ٤–٥ حركات.',
        'ur':
            'ضمیر کی ہاء دو متحرک حروف کے درمیان ہو اور اس کے بعد ہمزہ آئے تو اسے چار سے پانچ حرکات کھینچا جاتا ہے۔',
        'tr':
            'İki harekeli harf arasındaki zamir hâsından sonra hemze gelirse 4–5 hareke uzatılır.',
        'fr':
            'Allongement du ha pronominal entre deux lettres vocalisées lorsqu’il est suivi d’une hamza. Durée : 4–5 temps.',
        'id':
            'Pemanjangan ha dhamir di antara dua huruf berharakat bila diikuti hamzah. Panjang: 4–5 harakat.',
        'de':
            'Verlängerung des Pronomen-Ha zwischen zwei vokalisierten Buchstaben, wenn ein Hamza folgt. Dauer: 4–5 Zählzeiten.',
      },
      exampleArabic: ['بِهِۦٓ إِلَّا', 'لَهُۥٓ أَجْرٌ'],
      triggerLetters: ['ه'],
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
        'en':
            'Merging of noon sakinah or tanween into one of the letters ي ن م و, pronounced with nasalization (ghunnah). Duration of ghunnah: 2 counts.',
        'ar':
            'إدغام النون الساكنة أو التنوين في أحد حروف (ينمو) مع بقاء الغنة. مقدار الغنة حركتان.',
        'ur':
            'نون ساکن یا تنوین کو حروف (ی ن م و) میں غنہ کے ساتھ ضم کرنا۔ غنہ کی مقدار دو حرکات۔',
        'tr':
            'Sükûnlu nun veya tenvinin ي ن م و harflerine günneli olarak idğam edilmesi.',
        'fr':
            'Fusion du noon sakinah ou tanween dans l\'un des lettres ي ن م و avec nasalisation.',
        'id':
            'Memasukkan nun sukun atau tanwin ke dalam salah satu huruf ي ن م و dengan dengung.',
        'de':
            'Verschmelzung von Noon Sakinah oder Tanween in einen der Buchstaben ي ن م و mit Nasalklang.',
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
        'en':
            'Merging of noon sakinah or tanween into the letters ل or ر without any nasalization. The noon disappears completely.',
        'ar':
            'إدغام النون الساكنة أو التنوين في حرفي (ل ر) بدون غنة، تذوب النون كاملاً.',
        'ur': 'نون ساکن یا تنوین کو حروف ل یا ر میں بغیر غنہ کے ضم کرنا۔',
        'tr':
            'Sükûnlu nun veya tenvinin ل veya ر harflerine günnesiz olarak idğam edilmesi.',
        'fr':
            'Fusion du noon sakinah ou tanween dans ل ou ر sans nasalisation.',
        'id':
            'Memasukkan nun sukun atau tanwin ke dalam huruf ل atau ر tanpa dengung.',
        'de':
            'Verschmelzung von Noon Sakinah oder Tanween in ل oder ر ohne Nasalklang.',
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
        'en':
            'Concealment of noon sakinah or tanween before 15 letters. The noon is neither fully pronounced nor fully merged — held between the two with ghunnah for 2 counts.',
        'ar':
            'إخفاء النون الساكنة أو التنوين عند 15 حرفاً مع بقاء الغنة، بحيث لا تكون النون مظهرة ولا مدغمة.',
        'ur':
            'نون ساکن یا تنوین کو 15 حروف کے قریب اخفاء کرنا۔ غنہ کے ساتھ نہ پوری طرح ظاہر نہ پوری طرح ادغام۔',
        'tr':
            '15 harf önünde sükûnlu nun veya tenvinin gizlenerek günneli okunması.',
        'fr':
            'Dissimulation du noon sakinah ou tanween devant 15 lettres avec nasalisation maintenue.',
        'id':
            'Menyembunyikan nun sukun atau tanwin di hadapan 15 huruf dengan tetap mempertahankan dengung.',
        'de':
            'Verbergen von Noon Sakinah oder Tanween vor 15 Buchstaben. Das Noon wird weder vollständig ausgesprochen noch vollständig verschmolzen.',
      },
      exampleArabic: ['مِن كُلِّ', 'عَنكَبُوتٌ', 'أَنتُمْ'],
      triggerLetters: [
        'ص',
        'ذ',
        'ث',
        'ك',
        'ج',
        'ش',
        'ق',
        'س',
        'د',
        'ط',
        'ز',
        'ف',
        'ت',
        'ض',
        'ظ',
      ],
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
        'en':
            'Transformation of noon sakinah or tanween into a meem sound before the letter ب, accompanied by ghunnah. The small م in the Quran marks this rule.',
        'ar':
            'قلب النون الساكنة أو التنوين ميماً مخفاة عند حرف الباء مع الغنة.',
        'ur': 'نون ساکن یا تنوین کو حرف ب سے پہلے میم میں بدلنا، غنہ کے ساتھ۔',
        'tr':
            'Sükûnlu nun veya tenvinin ب harfi önünde mim sesi olarak okunması ve gizlenmesi.',
        'fr':
            'Transformation du noon sakinah ou tanween en son meem avant la lettre ب avec nasalisation.',
        'id':
            'Mengubah nun sukun atau tanwin menjadi suara mim di hadapan huruf ب disertai dengung.',
        'de':
            'Verwandlung von Noon Sakinah oder Tanween in einen Meem-Laut vor dem Buchstaben ب mit Ghunna.',
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
        'en':
            'Clear, distinct pronunciation of noon sakinah or tanween before the six throat letters (ء ه ع ح غ خ), with no ghunnah.',
        'ar':
            'إظهار النون الساكنة أو التنوين عند حروف الحلق الستة (ء ه ع ح غ خ) بلا غنة.',
        'ur':
            'نون ساکن یا تنوین کو حلقی حروف (ء ہ ع ح غ خ) کے سامنے صاف اور واضح پڑھنا بغیر غنہ کے۔',
        'tr':
            'Sükûnlu nun veya tenvinin halk harfleri (ء ه ع ح غ خ) önünde günnésiz ve açık okunması.',
        'fr':
            'Prononciation claire du noon sakinah ou tanween avant les six lettres gutturales sans nasalisation.',
        'id':
            'Pengucapan nun sukun atau tanwin secara jelas dan terang di hadapan 6 huruf halq tanpa dengung.',
        'de':
            'Klare, deutliche Aussprache von Noon Sakinah oder Tanween vor den sechs Kehlbuchstaben ohne Ghunna.',
      },
      exampleArabic: ['مَنْ آمَنَ', 'عَلِيمٌ حَكِيمٌ'],
      triggerLetters: ['ء', 'ه', 'ع', 'ح', 'غ', 'خ'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.shaddah,
      names: {
        'en': 'Shaddah',
        'ar': 'شَدَّة',
        'ur': 'تشدید',
        'tr': 'Şedde',
        'fr': 'Shadda',
        'id': 'Tasydid',
        'de': 'Schadda',
      },
      descriptions: {
        'en':
            'A doubling mark over a letter indicating that it is pronounced with emphasis as two merged letters.',
        'ar': 'علامة تدل على تضعيف الحرف، فيُنطق الحرف مشددًا كحرفين مدغمين.',
        'ur': 'یہ علامت حرف کو دُگنا پڑھنے پر دلالت کرتی ہے۔',
        'tr':
            'Harfin şeddeli yani iki harf gibi kuvvetli okunacağını gösterir.',
        'fr': 'Signe qui indique le redoublement de la consonne.',
        'id': 'Tanda untuk menggandakan pelafalan huruf.',
        'de': 'Zeichen zur Verdopplung eines Buchstabens in der Aussprache.',
      },
      exampleArabic: ['إِيَّاكَ', 'الرَّحْمَٰنِ', 'ثُمَّ'],
      triggerLetters: [],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.waqf,
      names: {
        'en': 'Waqf',
        'ar': 'وَقْف',
        'ur': 'وقف',
        'tr': 'Vakf',
        'fr': 'Waqf',
        'id': 'Waqaf',
        'de': 'Waqf',
      },
      descriptions: {
        'en':
            'Pause marks that guide where to stop, continue, or avoid stopping during recitation.',
        'ar': 'علامات الوقف التي تُبيّن مواضع التوقف أو الوصل أثناء التلاوة.',
        'ur': 'وقف کی علامات جو تلاوت میں رکنے یا ملانے کی جگہ بتاتی ہیں۔',
        'tr':
            'Tilavette durulacak veya geçilecek yerleri gösteren vakıf işaretleri.',
        'fr':
            'Signes de pause indiquant où s’arrêter ou continuer dans la récitation.',
        'id':
            'Tanda waqaf yang menunjukkan tempat berhenti atau menyambung bacaan.',
        'de': 'Pausenzeichen, die Stellen für Halt oder Weiterlesen anzeigen.',
      },
      exampleArabic: ['ۘ', 'ۙ', 'ۚ', 'ۗ', 'ۖ', 'ۛ', 'ۜ'],
      triggerLetters: [],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.sajdah,
      names: {
        'en': 'Sajdah Sign',
        'ar': 'عَلَامَة السَّجْدَة',
        'ur': 'علامتِ سجدہ',
        'tr': 'Secde İşareti',
        'fr': 'Signe de Sajdah',
        'id': 'Tanda Sajdah',
        'de': 'Sajdah-Zeichen',
      },
      descriptions: {
        'en': 'The prostration sign (۩) marks verses of sajdah in recitation.',
        'ar': 'علامة السجدة (۩) تدل على مواضع سجود التلاوة.',
        'ur': 'سجدہ کی علامت (۩) تلاوتِ سجدہ کی آیت کو ظاہر کرتی ہے۔',
        'tr': 'Secde işareti (۩), tilavet secdesi yapılan ayeti gösterir.',
        'fr': 'Le signe de sajdah (۩) indique les versets de prosternation.',
        'id': 'Tanda sajdah (۩) menandai ayat-ayat sajdah tilawah.',
        'de': 'Das Sajdah-Zeichen (۩) markiert Verse der Niederwerfung.',
      },
      exampleArabic: ['۩'],
      triggerLetters: [],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.maddLazimKalimiMuthaqqal,
      names: {
        'en': 'Madd Lazim Kalimi Muthaqqal',
        'ar': 'مَدّ لَازِم كَلِمِيّ مُثَقَّل',
        'ur': 'مد لازم کلمی مثقل',
        'tr': 'Meddi Lazım Kelimi Müsakkal',
        'fr': 'Madd Lazim Kalimi Muthaqqal',
        'id': 'Mad Lazim Kilmi Mutsaqqal',
        'de': 'Madd Lazim Kalimi Muthaqqal',
      },
      descriptions: {
        'en':
            'Within a word, a madd letter is followed by a letter carrying shaddah. Prolong 6 counts. Example: ٱلضَّآلِّينَ.',
        'ar':
            'أن يأتي بعد حرف المد حرف مشدد في كلمة واحدة، ويمد ٦ حركات. مثاله: ٱلضَّآلِّينَ.',
        'ur':
            'ایک ہی کلمے میں حرفِ مد کے بعد مشدد حرف آئے تو چھ حرکات کھینچا جاتا ہے۔ مثال: ٱلضَّآلِّينَ۔',
        'tr':
            'Bir kelimede med harfinden sonra şeddeli harf gelirse 6 hareke uzatılır. Örnek: ٱلضَّآلِّينَ.',
        'fr':
            'Dans un mot, la lettre de madd est suivie d\'une lettre portant une shadda. Allongez 6 temps. Exemple : ٱلضَّآلِّينَ.',
        'id':
            'Dalam satu kata, huruf mad diikuti huruf bertasydid. Dibaca 6 harakat. Contoh: ٱلضَّآلِّينَ.',
        'de':
            'Innerhalb eines Wortes folgt der Madd-Buchstabe ein Buchstabe mit Schadda. 6 Zählzeiten. Beispiel: ٱلضَّآلِّينَ.',
      },
      exampleArabic: ['ٱلضَّآلِّينَ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.maddLazimKalimiMukhaffaf,
      names: {
        'en': 'Madd Lazim Kalimi Mukhaffaf',
        'ar': 'مَدّ لَازِم كَلِمِيّ مُخَفَّف',
        'ur': 'مد لازم کلمی مخفف',
        'tr': 'Meddi Lazım Kelimi Muhaffef',
        'fr': 'Madd Lazim Kalimi Mukhaffaf',
        'id': 'Mad Lazim Kilmi Mukhaffaf',
        'de': 'Madd Lazim Kalimi Mukhaffaf',
      },
      descriptions: {
        'en':
            'Within a word, a madd letter is followed by a letter with a plain sukoon. Prolong 6 counts. It occurs only twice in the Qur’an: 10:51 and 10:91 (ءَآلْـَٔـٰنَ).',
        'ar':
            'أن يأتي بعد حرف المد حرف ساكن سكونًا أصليًا في كلمة واحدة، ويمد ٦ حركات. ولم يقع إلا في موضعين: يونس ٥١ و٩١ (ءَآلْـَٔـٰنَ).',
        'ur':
            'ایک ہی کلمے میں حرفِ مد کے بعد ساکن حرف آئے تو چھ حرکات۔ قرآن میں صرف دو مقامات پر: یونس ۵۱ اور ۹۱۔',
        'tr':
            'Bir kelimede med harfinden sonra sükûnlu harf gelir; 6 hareke uzatılır. Kur’an’da sadece iki yerde: Yûnus 51 ve 91.',
        'fr':
            'Dans un mot, la lettre de madd est suivie d\'une lettre portant un soukoun. 6 temps. Seulement deux fois dans le Coran : 10:51 et 10:91.',
        'id':
            'Dalam satu kata, huruf mad diikuti huruf bersukun asli. Dibaca 6 harakat. Hanya dua tempat: Yunus 51 dan 91.',
        'de':
            'Innerhalb eines Wortes folgt dem Madd-Buchstaben ein Buchstabe mit Sukoon. 6 Zählzeiten. Nur zweimal im Koran: 10:51 und 10:91.',
      },
      exampleArabic: ['ءَآلْـَٔـٰنَ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.maddLazimHarfiMuthaqqal,
      names: {
        'en': 'Madd Lazim Harfi Muthaqqal',
        'ar': 'مَدّ لَازِم حَرْفِيّ مُثَقَّل',
        'ur': 'مد لازم حرفی مثقل',
        'tr': 'Meddi Lazım Harfi Müsakkal',
        'fr': 'Madd Lazim Harfi Muthaqqal',
        'id': 'Mad Lazim Harfi Mutsaqqal',
        'de': 'Madd Lazim Harfi Muthaqqal',
      },
      descriptions: {
        'en':
            'In the disjointed letters opening some surahs, a spelled letter ends in a consonant that merges into the next letter. Prolong 6 counts. Example: the ل of الٓمٓ.',
        'ar':
            'في فواتح السور، يكون حرف المد في اسم الحرف مدغمًا آخره فيما بعده، ويمد ٦ حركات. مثاله: اللام في الٓمٓ.',
        'ur':
            'حروفِ مقطعات میں حرف کا آخری حصہ اگلے حرف میں مدغم ہو تو چھ حرکات۔ مثال: الٓمٓ کا لام۔',
        'tr':
            'Sûre başlarındaki hurûf-ı mukattaada harfin sonu sonrakine idgam olur; 6 hareke. Örnek: الٓمٓ’deki lâm.',
        'fr':
            'Dans les lettres isolées en début de sourate, la fin de la lettre épelée s\'assimile à la suivante. 6 temps. Exemple : le ل de الٓمٓ.',
        'id':
            'Pada huruf muqatha’ah, akhir nama huruf diidghamkan ke huruf berikutnya. 6 harakat. Contoh: lam pada الٓمٓ.',
        'de':
            'Bei den Einzelbuchstaben am Surenanfang verschmilzt der Endlaut mit dem nächsten Buchstaben. 6 Zählzeiten. Beispiel: das ل in الٓمٓ.',
      },
      exampleArabic: ['الٓمٓ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.maddLazimHarfiMukhaffaf,
      names: {
        'en': 'Madd Lazim Harfi Mukhaffaf',
        'ar': 'مَدّ لَازِم حَرْفِيّ مُخَفَّف',
        'ur': 'مد لازم حرفی مخفف',
        'tr': 'Meddi Lazım Harfi Muhaffef',
        'fr': 'Madd Lazim Harfi Mukhaffaf',
        'id': 'Mad Lazim Harfi Mukhaffaf',
        'de': 'Madd Lazim Harfi Mukhaffaf',
      },
      descriptions: {
        'en':
            'In the disjointed letters opening some surahs, a spelled letter ends in a plain sukoon with no merging. Prolong 6 counts. Example: the س of يسٓ.',
        'ar':
            'في فواتح السور، يكون آخر اسم الحرف ساكنًا من غير إدغام، ويمد ٦ حركات. مثاله: السين في يسٓ.',
        'ur':
            'حروفِ مقطعات میں حرف کا آخر ساکن ہو اور ادغام نہ ہو تو چھ حرکات۔ مثال: يسٓ کا سین۔',
        'tr':
            'Hurûf-ı mukattaada harfin sonu idgamsız sâkin olur; 6 hareke. Örnek: يسٓ’deki sîn.',
        'fr':
            'Dans les lettres isolées, la lettre épelée se termine par un soukoun sans assimilation. 6 temps. Exemple : le س de يسٓ.',
        'id':
            'Pada huruf muqatha’ah, akhir nama huruf bersukun tanpa idgham. 6 harakat. Contoh: sin pada يسٓ.',
        'de':
            'Bei den Einzelbuchstaben endet der Buchstabe auf Sukoon ohne Verschmelzung. 6 Zählzeiten. Beispiel: das س in يسٓ.',
      },
      exampleArabic: ['يسٓ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.maddAridLissukun,
      names: {
        'en': 'Madd Arid Lissukun',
        'ar': 'مَدّ عَارِض لِلسُّكُون',
        'ur': 'مد عارض للسکون',
        'tr': 'Meddi Ârız',
        'fr': 'Madd Arid Lissoukoun',
        'id': 'Mad Arid Lissukun',
        'de': 'Madd Arid Lissukun',
      },
      descriptions: {
        'en':
            'A madd letter — alif after a fatha, waw after a damma, or ya after a kasra — followed by a letter that becomes sakin only because you stop on it. When stopping, prolong 2, 4, or 6 counts and keep the same length throughout a passage; if you continue it reverts to a natural 2-count madd.',
        'ar':
            'أن يأتي بعد حرف المد حرفّ متحرك يسكن للوقف عليه. وحرف المد هو: الألف الساكنة المفتوح ما قبلها، أو الواو الساكنة المضموم ما قبلها، أو الياء الساكنة المكسور ما قبلها. مقداره عند الوقف: ٢ أو ٤ أو ٦ حركات، والأولى الالتزام بمقدار واحد. فإن وصلت زال السكون وعاد مدًا طبيعيًا بحركتين.',
        'ur':
            'حرف مد (الف جس سے پہلے فتحہ، واو جس سے پہلے ضمہ، یا یاء جس سے پہلے کسرہ) کے بعد ایسا حرف آئے جو صرف وقف کی وجہ سے ساکن ہو۔ وقف پر ۲، ۴ یا ۶ حرکات؛ وصل کی صورت میں دو حرکات کا مد طبعی رہ جاتا ہے۔',
        'tr':
            'Med harfinden (öncesinde fetha bulunan elif, ötre bulunan vav veya esre bulunan ya) sonra, yalnızca durduğunuz için sakin olan bir harf gelir. Durulduğunda 2, 4 veya 6 hareke uzatılır ve aynı ölçü korunur; geçildiğinde 2 harekelik tabii med olur.',
        'fr':
            'Une lettre de prolongation (alif précédé d\'une fatha, waw précédé d\'une damma, ya précédé d\'une kasra) suivie d\'une lettre qui ne devient quiescente que parce qu\'on s\'arrête dessus. À l\'arrêt: 2, 4 ou 6 temps, en gardant la même longueur; en continuant, il redevient un madd naturel de 2 temps.',
        'id':
            'Huruf mad (alif setelah fathah, wau setelah dhammah, atau ya setelah kasrah) diikuti huruf yang menjadi sukun hanya karena diwaqafkan. Saat berhenti: 2, 4, atau 6 harakat dengan ukuran yang konsisten; bila diteruskan kembali menjadi mad thabi\'i 2 harakat.',
        'de':
            'Ein Madd-Buchstabe (Alif nach Fatha, Waw nach Damma oder Ya nach Kasra), gefolgt von einem Buchstaben, der nur durch das Anhalten sakin wird. Beim Anhalten 2, 4 oder 6 Zählzeiten in gleichbleibender Länge; beim Weiterlesen wird daraus ein natürliches Madd von 2 Zählzeiten.',
      },
      exampleArabic: ['يَعْمَهُونَ', 'نَسْتَعِينُ'],
      triggerLetters: ['ا', 'و', 'ي'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.maddLin,
      names: {
        'en': 'Madd Lin',
        'ar': 'مَدّ لِين',
        'ur': 'مد لین',
        'tr': 'Meddi Lîn',
        'fr': 'Madd Lin',
        'id': 'Mad Lin',
        'de': 'Madd Lin',
      },
      descriptions: {
        'en':
            'A lin letter — waw or ya carrying sukoon and preceded by a fatha, so the vowel before it does not match it — followed by a letter you stop on. When stopping, prolong 2, 4, or 6 counts; there is no elongation at all when you continue.',
        'ar':
            'الواو أو الياء الساكنة المفتوح ما قبلها، وتسمى حرف لين لأن حركة ما قبلها لا تجانسها، ويأتي بعدها حرف يوقف عليه. مقداره عند الوقف: ٢ أو ٤ أو ٦ حركات، ولا يمد عند الوصل.',
        'ur':
            'واو یا یاء ساکن ہو اور اس سے پہلے فتحہ ہو — یہ حرف لین کہلاتا ہے کیونکہ پچھلی حرکت اس کے موافق نہیں — اور اس کے بعد وہ حرف آئے جس پر وقف کیا جائے۔ وقف پر ۲، ۴ یا ۶ حرکات؛ وصل میں بالکل مد نہیں۔',
        'tr':
            'Sakin vav veya ya olup öncesinde fetha bulunur — önceki hareke kendisine uymadığı için lîn harfi denir — ve ardından üzerinde durulan bir harf gelir. Durulduğunda 2, 4 veya 6 hareke uzatılır; geçildiğinde hiç uzatılmaz.',
        'fr':
            'Une lettre de lin — waw ou ya portant un soukoun et précédé d\'une fatha, la voyelle précédente ne lui correspondant pas — suivie d\'une lettre sur laquelle on s\'arrête. À l\'arrêt: 2, 4 ou 6 temps; aucune prolongation en liaison.',
        'id':
            'Huruf lin — wau atau ya bersukun yang didahului fathah, sehingga harakat sebelumnya tidak sejenis dengannya — diikuti huruf yang diwaqafkan. Saat berhenti: 2, 4, atau 6 harakat; tidak ada pemanjangan sama sekali bila diteruskan.',
        'de':
            'Ein Lin-Buchstabe — Waw oder Ya mit Sukun und einem vorangehenden Fatha, das nicht zu ihm passt — gefolgt von einem Buchstaben, auf dem angehalten wird. Beim Anhalten 2, 4 oder 6 Zählzeiten; beim Weiterlesen keine Dehnung.',
      },
      exampleArabic: ['قُرَيْشٍ', 'خَوْفٍ'],
      triggerLetters: ['و', 'ي'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.idghamShafawi,
      names: {
        'en': 'Idgham Shafawi',
        'ar': 'إِدْغَام شَفَوِيّ',
        'ur': 'ادغام شفوی',
        'tr': 'İdğam-ı Şefevî',
        'fr': 'Idgham Shafawi',
        'id': 'Idgham Syafawi',
        'de': 'Idgham Shafawi',
      },
      descriptions: {
        'en': 'Meem sakinah merges into the following meem with ghunnah.',
        'ar': 'إدغام الميم الساكنة في ميم بعدها مع غنة.',
        'ur': 'میم ساکن کو اگلی میم میں غنہ کے ساتھ ادغام کیا جاتا ہے۔',
        'tr':
            'Sakin mim, kendisinden sonraki mime günneli şekilde idğam edilir.',
        'fr': 'Le meem sakinah fusionne dans le meem suivant avec ghounna.',
        'id': 'Mim sukun dilebur ke mim berikutnya dengan dengung.',
        'de': 'Meem Sakinah verschmilzt mit folgendem Meem mit Ghunna.',
      },
      exampleArabic: ['لَكُم مَّا'],
      triggerLetters: ['م'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.idghamMutajanisayn,
      names: {
        'en': 'Idgham Mutajanisayn',
        'ar': 'إِدْغَام مُتَجَانِسَيْن',
        'ur': 'ادغام متجانسین',
        'tr': 'İdğam-ı Mütecaniseyn',
        'fr': 'Idgham Mutajanisayn',
        'id': 'Idgham Mutajanisain',
        'de': 'Idgham Mutajanisayn',
      },
      descriptions: {
        'en':
            'Assimilation between two letters with the same articulation point but different attributes.',
        'ar': 'إدغام حرفين من مخرج واحد مع اختلاف في بعض الصفات.',
        'ur': 'دو متجانس حروف میں ادغام جو ایک ہی مخرج سے ادا ہوں۔',
        'tr': 'Mahreci aynı, sıfatları farklı iki harfin idğam edilmesi.',
        'fr':
            'Assimilation entre deux lettres de même point d’articulation avec attributs différents.',
        'id': 'Idgham dua huruf yang makhrajnya sama namun sifatnya berbeda.',
        'de':
            'Assimilation zweier Buchstaben mit gleichem Artikulationsort und unterschiedlichen Eigenschaften.',
      },
      exampleArabic: ['قَد تَّبَيَّنَ'],
      triggerLetters: [],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.ikhfaShafawi,
      names: {
        'en': 'Ikhfa Shafawi',
        'ar': 'إِخْفَاء شَفَوِيّ',
        'ur': 'اخفاء شفوی',
        'tr': 'İhfa-ı Şefevî',
        'fr': 'Ikhfa Shafawi',
        'id': 'Ikhfa Syafawi',
        'de': 'Ikhfa Shafawi',
      },
      descriptions: {
        'en': 'Concealment of meem sakinah before the letter ba with ghunnah.',
        'ar':
            'إذا وقعت الميم الساكنة قبل حرف الباء تُخفى مع غنة مقدارها حركتان، مع إطباق الشفتين إطباقًا خفيفًا من غير ضغط.',
        'ur': 'میم ساکن کو باء سے پہلے غنہ کے ساتھ مخفی پڑھا جاتا ہے۔',
        'tr': 'Sakin mim, ب harfinden önce günneli şekilde ihfa edilir.',
        'fr': 'Dissimulation du meem sakinah devant la lettre ب avec ghounna.',
        'id': 'Mim sukun disamarkan sebelum huruf ba dengan dengung.',
        'de': 'Verbergen von Meem Sakinah vor dem Buchstaben ب mit Ghunna.',
      },
      exampleArabic: ['تَرْمِيهِم بِحِجَارَةٍ'],
      triggerLetters: ['ب'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.hamzatWasl,
      names: {
        'en': 'Hamzat Wasl',
        'ar': 'هَمْزَة وَصْل',
        'ur': 'ہمزہ وصل',
        'tr': 'Hemze-i Vasl',
        'fr': 'Hamzat Wasl',
        'id': 'Hamzat Wasl',
        'de': 'Hamzat Wasl',
        'es': 'Hamzat Wasl',
      },
      descriptions: {
        'en':
            'A connecting hamza that is pronounced at the start of recitation and dropped in continuous reading.',
        'ar': 'همزة تُنطق في ابتداء الكلام وتسقط في حال الوصل.',
        'ur': 'یہ ہمزہ ابتداء میں پڑھا جاتا ہے اور وصل میں ساقط ہو جاتا ہے۔',
        'tr': 'Başlangıçta okunan, vasl halinde düşen bağlayıcı hemzedir.',
        'fr':
            'Hamza de liaison prononcée en début de lecture et élidée en continuation.',
        'id': 'Hamzah sambung: dibaca saat memulai, gugur saat washal.',
        'de':
            'Verbindungs-Hamza: am Anfang gesprochen, beim Verbinden ausgelassen.',
        'es':
            'Hamza de enlace que se pronuncia al comenzar y se omite al unir la palabra con la anterior.',
      },
      exampleArabic: ['ٱهْدِنَا', 'ٱلْحَمْدُ', 'ٱسْتَغْفِرُوا'],
      triggerLetters: [],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.hamzatQat,
      names: {
        'en': 'Hamzat al-Qat',
        'ar': 'هَمْزَةُ الْقَطْعِ',
        'ur': 'ہمزۂ قطع',
        'tr': 'Hemze-i Kat',
        'fr': 'Hamzat al-Qat',
        'id': 'Hamzat Qat',
        'de': 'Hamzat al-Qat',
        'es': 'Hamzat al-Qat',
      },
      descriptions: {
        'en':
            'A fixed hamza that is always pronounced, whether beginning with the word or connecting it to the word before it.',
        'ar':
            'همزة ثابتة تُنطق في الابتداء والوصل، وتُرسم في أول الكلمة فوق الألف أو تحتها.',
        'ur':
            'یہ مستقل ہمزہ ابتدا اور وصل دونوں حالتوں میں پڑھا جاتا ہے، اور لفظ کے شروع میں الف کے اوپر یا نیچے لکھا جاتا ہے۔',
        'tr':
            'Kelimeye başlarken de önceki kelimeye bağlarken de her zaman okunan sabit hemzedir.',
        'fr':
            'Hamza fixe toujours prononcée, au début du mot comme en liaison avec le mot précédent.',
        'id':
            'Hamzah tetap yang selalu dibaca, baik saat memulai kata maupun menyambungkannya dengan kata sebelumnya.',
        'de':
            'Ein festes Hamza, das sowohl am Wortanfang als auch bei der Verbindung mit dem vorherigen Wort gesprochen wird.',
        'es':
            'Hamza fija que siempre se pronuncia, tanto al comenzar la palabra como al unirla con la palabra anterior.',
      },
      exampleArabic: ['أَنْعَمْتَ', 'إِيَّاكَ', 'أُنزِلَ'],
      triggerLetters: ['أ', 'إ'],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.laamShamsiyah,
      names: {
        'en': 'Laam Shamsiyah',
        'ar': 'لَام شَمْسِيَّة',
        'ur': 'لام شمسیہ',
        'tr': 'Lâm-ı Şemsiyye',
        'fr': 'Lam Shamsiyah',
        'id': 'Lam Syamsiyah',
        'de': 'Laam Shamsiyah',
      },
      descriptions: {
        'en':
            'The lam of "al-" is assimilated into the following sun letter and is not pronounced.',
        'ar': 'تُدغم لام "ال" في الحرف الشمسي بعدها فلا تُنطق.',
        'ur': 'لامِ تعریف اگلے حرفِ شمسی میں مدغم ہو جاتی ہے۔',
        'tr': '"El-" takısındaki lam, ardından gelen şemsi harfe idğam edilir.',
        'fr': 'Le lam de "al-" est assimilé à la lettre solaire suivante.',
        'id': 'Lam pada "al-" dilebur ke huruf syamsiyah sesudahnya.',
        'de':
            'Das Laam von "al-" wird in den folgenden Sonnenbuchstaben assimiliert.',
      },
      exampleArabic: ['الشَّمْسِ', 'النَّاسِ'],
      triggerLetters: [
        'ت',
        'ث',
        'د',
        'ذ',
        'ر',
        'ز',
        'س',
        'ش',
        'ص',
        'ض',
        'ط',
        'ظ',
        'ل',
        'ن',
      ],
    ),
    TajweedRuleDefinition(
      rule: TajweedRule.silent,
      names: {
        'en': 'Silent Letter',
        'ar': 'حَرْف سَاكِن',
        'ur': 'خاموش حرف',
        'tr': 'Sessiz Harf',
        'fr': 'Lettre Muette',
        'id': 'Huruf Diam',
        'de': 'Stummer Buchstabe',
      },
      descriptions: {
        'en':
            'A script letter that is written in Uthmani script but not pronounced in recitation.',
        'ar': 'حرف يُكتب في الرسم العثماني ولا يُنطق في التلاوة.',
        'ur': 'ایسا حرف جو لکھا جاتا ہے مگر تلاوت میں ادا نہیں کیا جاتا۔',
        'tr': 'Mushaf yazısında bulunan ancak tilavette okunmayan harf.',
        'fr': 'Lettre écrite dans le rasm uthmani mais non prononcée.',
        'id': 'Huruf dalam rasm Utsmani yang ditulis tetapi tidak dilafalkan.',
        'de':
            'Ein im uthmanischen Schriftbild geschriebener, aber nicht ausgesprochener Buchstabe.',
      },
      exampleArabic: ['أُولَٰئِكَ', 'هَٰذَا'],
      triggerLetters: [],
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
