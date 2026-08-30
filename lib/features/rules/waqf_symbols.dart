class WaqfSymbolExample {
  final int index;
  final String displaySymbol;
  final String quranSymbol;
  final String arabicText;

  const WaqfSymbolExample({
    required this.index,
    required this.displaySymbol,
    required this.quranSymbol,
    required this.arabicText,
  });
}

class WaqfSymbols {
  const WaqfSymbols._();

  static const examples = <WaqfSymbolExample>[
    WaqfSymbolExample(
      index: 0,
      displaySymbol: 'م',
      quranSymbol: 'ۘ',
      arabicText: 'بِهَٰذَا مَثَلًا ۘ يُضِلُّ بِهِ كَثِيرًا',
    ),
    WaqfSymbolExample(
      index: 1,
      displaySymbol: 'لا',
      quranSymbol: 'ۙ',
      arabicText: 'مِن ثَمَرَةٍ رِّزْقًا ۙ قَالُوا هَٰذَا',
    ),
    WaqfSymbolExample(
      index: 2,
      displaySymbol: 'ج',
      quranSymbol: 'ۚ',
      arabicText: 'حَذَرَ الْمَوْتِ ۚ وَاللَّهُ مُحِيطٌ',
    ),
    WaqfSymbolExample(
      index: 3,
      displaySymbol: 'قلى',
      quranSymbol: 'ۗ',
      arabicText: 'آمَنَ السُّفَهَاءُ ۗ أَلَا إِنَّهُمْ',
    ),
    WaqfSymbolExample(
      index: 4,
      displaySymbol: 'صلى',
      quranSymbol: 'ۖ',
      arabicText: 'عَلَىٰ هُدًى مِّن رَّبِّهِمْ ۖ وَأُولَٰئِكَ',
    ),
    WaqfSymbolExample(
      index: 5,
      displaySymbol: '∴',
      quranSymbol: 'ۛ',
      arabicText: 'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى',
    ),
    WaqfSymbolExample(
      index: 6,
      displaySymbol: 'س',
      quranSymbol: 'ۜ',
      arabicText: 'وَاللَّهُ يَقْبِضُ وَيَبْصُۜطُ وَإِلَيْهِ تُرْجَعُونَ',
    ),
  ];

  static List<String> shareLines(
    String languageCode, {
    required String examplesLabel,
  }) {
    final strings = WaqfRuleStrings(languageCode);
    return [
      '${strings.text('title')}:',
      for (final example in examples) ...[
        '',
        '${example.displaySymbol} — ${strings.text('name_${example.index}')}',
        strings.text('description_${example.index}'),
        '$examplesLabel: ${example.arabicText}',
      ],
    ];
  }
}

class WaqfRuleStrings {
  final String langCode;

  const WaqfRuleStrings(this.langCode);

  static const Map<String, Map<String, String>> _localized = {
    'en': {
      'title': 'Waqf symbols',
      'name_0': 'Obligatory stop',
      'description_0': 'Stop here to preserve the intended meaning.',
      'name_1': 'Do not stop',
      'description_1':
          'Continue reciting because stopping may alter the meaning.',
      'name_2': 'Permissible stop',
      'description_2': 'Both stopping and continuing are acceptable.',
      'name_3': 'Stopping is preferred',
      'description_3': 'Both are allowed, but stopping is better.',
      'name_4': 'Continuing is preferred',
      'description_4': 'Both are allowed, but continuing is better.',
      'name_5': 'Paired stop',
      'description_5': 'Stop at either paired symbol, but not at both.',
      'name_6': 'Brief pause',
      'description_6': 'Pause briefly without taking a new breath.',
    },
    'ar': {
      'title': 'علامات الوقف',
      'name_0': 'وقف لازم',
      'description_0': 'يلزم الوقف هنا للمحافظة على المعنى المقصود.',
      'name_1': 'لا تقف',
      'description_1': 'يُوصل الكلام لأن الوقف قد يغيّر المعنى.',
      'name_2': 'وقف جائز',
      'description_2': 'يجوز الوقف ويجوز الوصل.',
      'name_3': 'الوقف أولى',
      'description_3': 'يجوز الوقف والوصل، لكن الوقف أفضل.',
      'name_4': 'الوصل أولى',
      'description_4': 'يجوز الوقف والوصل، لكن الوصل أفضل.',
      'name_5': 'تعانق الوقف',
      'description_5': 'يُوقف على إحدى العلامتين المتقابلتين دون كلتيهما.',
      'name_6': 'سكتة لطيفة',
      'description_6': 'سكتة قصيرة من غير أخذ نفس جديد.',
    },
    'ur': {
      'title': 'وقف کی علامات',
      'name_0': 'وقف لازم',
      'description_0': 'مطلب محفوظ رکھنے کے لیے یہاں رکنا ضروری ہے۔',
      'name_1': 'نہ رکیں',
      'description_1': 'تلاوت جاری رکھیں کیونکہ رکنے سے معنی بدل سکتا ہے۔',
      'name_2': 'وقف جائز',
      'description_2': 'رکنا اور جاری رکھنا دونوں درست ہیں۔',
      'name_3': 'رکنا بہتر ہے',
      'description_3': 'دونوں جائز ہیں، لیکن رکنا بہتر ہے۔',
      'name_4': 'جاری رکھنا بہتر ہے',
      'description_4': 'دونوں جائز ہیں، لیکن جاری رکھنا بہتر ہے۔',
      'name_5': 'وقفِ معانقہ',
      'description_5': 'دو علامتوں میں سے کسی ایک پر رکیں، دونوں پر نہیں۔',
      'name_6': 'مختصر سکتہ',
      'description_6': 'نیا سانس لیے بغیر مختصر وقفہ کریں۔',
    },
    'tr': {
      'title': 'Vakf işaretleri',
      'name_0': 'Zorunlu durak',
      'description_0': 'Kastedilen anlamı korumak için burada durun.',
      'name_1': 'Durmayın',
      'description_1':
          'Durmak anlamı değiştirebileceği için okumaya devam edin.',
      'name_2': 'İzin verilen durak',
      'description_2': 'Durmak da devam etmek de uygundur.',
      'name_3': 'Durmak tercih edilir',
      'description_3': 'İkisi de uygundur, fakat durmak daha iyidir.',
      'name_4': 'Devam etmek tercih edilir',
      'description_4': 'İkisi de uygundur, fakat devam etmek daha iyidir.',
      'name_5': 'Eşli durak',
      'description_5':
          'Eşli işaretlerden birinde durun, ikisinde birden değil.',
      'name_6': 'Kısa duraklama',
      'description_6': 'Yeni nefes almadan kısa bir süre duraklayın.',
    },
    'fr': {
      'title': 'Signes de pause',
      'name_0': 'Arrêt obligatoire',
      'description_0': 'Arrêtez-vous ici afin de préserver le sens voulu.',
      'name_1': 'Ne pas s’arrêter',
      'description_1': 'Continuez, car l’arrêt pourrait modifier le sens.',
      'name_2': 'Arrêt permis',
      'description_2': 'L’arrêt et la continuation sont tous deux permis.',
      'name_3': 'Arrêt préférable',
      'description_3': 'Les deux sont permis, mais l’arrêt est préférable.',
      'name_4': 'Continuation préférable',
      'description_4': 'Les deux sont permis, mais continuer est préférable.',
      'name_5': 'Arrêt apparié',
      'description_5':
          'Arrêtez-vous à l’un des deux signes, mais pas aux deux.',
      'name_6': 'Pause brève',
      'description_6': 'Faites une courte pause sans reprendre votre souffle.',
    },
    'id': {
      'title': 'Tanda waqaf',
      'name_0': 'Berhenti wajib',
      'description_0': 'Berhentilah di sini untuk menjaga makna yang dimaksud.',
      'name_1': 'Jangan berhenti',
      'description_1': 'Lanjutkan bacaan karena berhenti dapat mengubah makna.',
      'name_2': 'Berhenti diperbolehkan',
      'description_2': 'Berhenti maupun melanjutkan sama-sama diperbolehkan.',
      'name_3': 'Berhenti lebih utama',
      'description_3': 'Keduanya boleh, tetapi berhenti lebih baik.',
      'name_4': 'Melanjutkan lebih utama',
      'description_4': 'Keduanya boleh, tetapi melanjutkan lebih baik.',
      'name_5': 'Waqaf berpasangan',
      'description_5':
          'Berhenti pada salah satu tanda pasangan, bukan keduanya.',
      'name_6': 'Jeda singkat',
      'description_6': 'Berhenti sejenak tanpa mengambil napas baru.',
    },
    'de': {
      'title': 'Waqf-Zeichen',
      'name_0': 'Verpflichtender Halt',
      'description_0':
          'Hier anhalten, um die beabsichtigte Bedeutung zu bewahren.',
      'name_1': 'Nicht anhalten',
      'description_1': 'Weiterlesen, da ein Halt die Bedeutung verändern kann.',
      'name_2': 'Erlaubter Halt',
      'description_2': 'Anhalten und Weiterlesen sind beide erlaubt.',
      'name_3': 'Anhalten ist vorzuziehen',
      'description_3': 'Beides ist erlaubt, aber Anhalten ist besser.',
      'name_4': 'Weiterlesen ist vorzuziehen',
      'description_4': 'Beides ist erlaubt, aber Weiterlesen ist besser.',
      'name_5': 'Gekoppelter Halt',
      'description_5': 'An einem der beiden Zeichen anhalten, nicht an beiden.',
      'name_6': 'Kurze Pause',
      'description_6': 'Kurz pausieren, ohne neu einzuatmen.',
    },
    'es': {
      'title': 'Signos de waqf',
      'name_0': 'Pausa obligatoria',
      'description_0': 'Detente aquí para conservar el significado previsto.',
      'name_1': 'No detenerse',
      'description_1':
          'Continúa, pues detenerse podría alterar el significado.',
      'name_2': 'Pausa permitida',
      'description_2': 'Tanto detenerse como continuar son aceptables.',
      'name_3': 'Es preferible detenerse',
      'description_3': 'Ambas opciones son válidas, pero es mejor detenerse.',
      'name_4': 'Es preferible continuar',
      'description_4': 'Ambas opciones son válidas, pero es mejor continuar.',
      'name_5': 'Pausa emparejada',
      'description_5': 'Detente en uno de los dos signos, pero no en ambos.',
      'name_6': 'Pausa breve',
      'description_6': 'Haz una pausa breve sin tomar un nuevo aliento.',
    },
  };

  String text(String key) =>
      _localized[langCode]?[key] ?? _localized['en']![key] ?? key;
}
