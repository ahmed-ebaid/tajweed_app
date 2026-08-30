import '../../core/models/tajweed_models.dart';

typedef AyahReference = ({int surah, int ayah});

class RuleExampleReferences {
  const RuleExampleReferences._();

  // Most references were selected by the shortest-example scanner.
  // `izhar`, `shaddah`, and `waqf` are manually curated because the upstream
  // tajweed span data does not expose those rules reliably enough to auto-pick.
  static const Map<TajweedRule, String> audioCodes = {
    TajweedRule.ghunnah: '055064',
    TajweedRule.qalqalah: '089001',
    TajweedRule.maddTabeei: '052001',
    TajweedRule.maddMuttasil: '078026',
    TajweedRule.maddMunfasil: '108001',
    TajweedRule.maddLazim: '036001',
    TajweedRule.maddSilahSughra: '018005',
    TajweedRule.maddSilahKubra: '002255',
    TajweedRule.idghamWithGhunnah: '078026',
    TajweedRule.idghamWithoutGhunnah: '056003',
    TajweedRule.idghamShafawi: '026060',
    TajweedRule.idghamMutajanisayn: '074014',
    TajweedRule.ikhfa: '074002',
    TajweedRule.ikhfaShafawi: '079014',
    TajweedRule.iqlab: '080016',
    TajweedRule.izhar: '101011',
    TajweedRule.shaddah: '001002',
    TajweedRule.waqf: '006036',
    TajweedRule.sajdah: '053062',
    TajweedRule.hamzatWasl: '052001',
    TajweedRule.laamShamsiyah: '052001',
    TajweedRule.silent: '020028',
  };

  // Multiple verified per-example audio references for standalone articles,
  // one entry per illustrative case (each verse checked directly against the
  // Quran.com Uthmani text before inclusion), mapped to the article's section
  // order (seven full letters / degrees / conditional cases, and light
  // letters / Ra / Lam+Alif respectively). Shortest available verse chosen
  // for each case so examples stay easy to read/hear:
  // tafkhim:
  //   1:7  — غَيْرِ ٱلْمَغْضُوبِ ... ٱلضَّآلِّينَ — the full letters غ and ض
  //          (shortest verse containing both).
  //   55:1 — ٱلرَّحْمَـٰنُ — Ra full with fathah before it (strongest degree),
  //          the shortest possible verse for this case.
  //   86:6 — خُلِقَ مِن مَّآءٍ دَافِقٍ — the full letter خ carrying dammah
  //          (lighter degree).
  // tarqiq:
  //   1:5  — إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ — ordinary light letters,
  //          none of the seven full letters present.
  //   51:22 — وَفِى ٱلسَّمَآءِ رِزْقُكُمْ وَمَا تُوعَدُونَ — Ra light because
  //          it carries dammah, shortest verse found for this case.
  //   1:1  — بِسْمِ ٱللَّهِ — the lam of Allah light because it follows the
  //          kasrah ending بِسْمِ (Lam and Alif conditional case).
  static const Map<String, List<String>> articleExampleCodes = {
    'tafkhim': ['001007', '055001', '086006'],
    'tarqiq': ['001005', '051022', '001001'],
  };

  // Short, verse-specific explanations shown under each example, one per
  // entry in articleExampleCodes, localized for every supported language, so
  // the reader knows exactly what to listen/look for in that particular
  // verse rather than only the generic section title.
  static const Map<String, Map<String, List<String>>> articleExampleCaptions =
      {
        'tafkhim': {
          'en': [
            'غ and ض are always full, no matter their vowel.',
            'الرَّحْمَـٰنُ: Ra is at its strongest — full letter with fathah before it.',
            'خُلِقَ: full letter خ carries dammah — a lighter, less forceful degree.',
          ],
          'ar': [
            'غ و ض مفخمتان دائماً مهما كانت حركتهما.',
            'الرَّحْمَـٰنُ: الراء في أعلى مراتب التفخيم، حرف مفخم قبله فتحة.',
            'خُلِقَ: حرف الخاء المفخم مضموم، وهي مرتبة أخف.',
          ],
          'ur': [
            'غ اور ض ہمیشہ بھاری ہوتے ہیں، چاہے حرکت کچھ بھی ہو۔',
            'الرَّحْمَـٰنُ: راء اپنے بلند ترین درجے پر ہے، فتحہ کے بعد بھاری حرف۔',
            'خُلِقَ: بھاری حرف خ پر ضمہ ہے، یہ ہلکا درجہ ہے۔',
          ],
          'tr': [
            'غ ve ض harekesi ne olursa olsun her zaman kalındır.',
            'الرَّحْمَـٰنُ: Ra en güçlü derecesinde, öncesinde fetha olan kalın harf.',
            'خُلِقَ: kalın خ harfi damme taşır, bu daha hafif bir derecedir.',
          ],
          'fr': [
            'غ et ض sont toujours emphatiques, quelle que soit leur voyelle.',
            'الرَّحْمَـٰنُ : le ra est à son degré le plus fort, lettre emphatique précédée d\'une fatha.',
            'خُلِقَ : la lettre emphatique خ porte une damma, un degré plus léger.',
          ],
          'id': [
            'غ dan ض selalu tebal, apa pun harakatnya.',
            'الرَّحْمَـٰنُ: Ra pada tingkat paling kuat, huruf tebal didahului fathah.',
            'خُلِقَ: huruf tebal خ berharakat dammah, tingkat yang lebih ringan.',
          ],
          'de': [
            'غ und ض werden immer voll ausgesprochen, unabhängig vom Vokal.',
            'الرَّحْمَـٰنُ: Ra ist auf seiner stärksten Stufe, voller Buchstabe mit vorausgehendem Fatha.',
            'خُلِقَ: der volle Buchstabe خ trägt Damma, eine leichtere Stufe.',
          ],
          'es': [
            'غ y ض siempre son gruesas, sea cual sea su vocal.',
            'الرَّحْمَـٰنُ: la ra está en su grado más fuerte, letra gruesa precedida de fatha.',
            'خُلِقَ: la letra gruesa خ lleva damma, un grado más ligero.',
          ],
        },
        'tarqiq': {
          'en': [
            'No full letters here — every letter stays light and thin.',
            'رِزْقُكُمْ: Ra is light here because it carries dammah after a light letter.',
            'بِسْمِ ٱللَّهِ: the lam of Allah stays light after the kasrah in بِسْمِ.',
          ],
          'ar': [
            'لا حروف تفخيم هنا، كل الحروف رقيقة خفيفة.',
            'رِزْقُكُمْ: الراء رقيقة لأنها مضمومة بعد حرف رقيق.',
            'بِسْمِ ٱللَّهِ: لام لفظ الجلالة رقيقة بعد كسرة بِسْمِ.',
          ],
          'ur': [
            'یہاں کوئی بھاری حرف نہیں، ہر حرف ہلکا اور رقیق ہے۔',
            'رِزْقُكُمْ: راء ہلکے حرف کے بعد ضمہ کی وجہ سے رقیق ہے۔',
            'بِسْمِ ٱللَّهِ: لفظ اللہ کا لام بِسْمِ کی کسرہ کے بعد ہلکا رہتا ہے۔',
          ],
          'tr': [
            'Burada kalın harf yok, her harf ince ve hafiftir.',
            'رِزْقُكُمْ: Ra, ince bir harften sonra damme taşıdığı için incedir.',
            'بِسْمِ ٱللَّهِ: Allah lafzındaki lam, بِسْمِ\'deki kesradan sonra ince kalır.',
          ],
          'fr': [
            'Aucune lettre emphatique ici, chaque lettre reste légère et fine.',
            'رِزْقُكُمْ : le ra est léger car il porte une damma après une lettre légère.',
            'بِسْمِ ٱللَّهِ : le lam d\'Allah reste léger après la kasra de بِسْمِ.',
          ],
          'id': [
            'Tidak ada huruf tebal di sini, setiap huruf tetap tipis dan ringan.',
            'رِزْقُكُمْ: Ra ringan karena berharakat dammah setelah huruf ringan.',
            'بِسْمِ ٱللَّهِ: lam pada lafaz Allah tetap ringan setelah kasrah pada بِسْمِ.',
          ],
          'de': [
            'Keine vollen Buchstaben hier, jeder Buchstabe bleibt leicht und dünn.',
            'رِزْقُكُمْ: Ra ist leicht, weil es nach einem leichten Buchstaben Damma trägt.',
            'بِسْمِ ٱللَّهِ: das Lam von Allah bleibt nach dem Kasra in بِسْمِ leicht.',
          ],
          'es': [
            'Aquí no hay letras gruesas, cada letra permanece ligera y fina.',
            'رِزْقُكُمْ: la ra es ligera porque lleva damma tras una letra ligera.',
            'بِسْمِ ٱللَّهِ: el lam de Allah permanece ligero tras la kasra de بِسْمِ.',
          ],
        },
      };

  static List<String> captionsForArticle(
    String articleId, {
    String languageCode = 'en',
  }) {
    final byLanguage = articleExampleCaptions[articleId];
    if (byLanguage == null) return const [];
    return byLanguage[languageCode] ?? byLanguage['en'] ?? const [];
  }

  // The exact substring(s) within each example's Arabic verse text that
  // demonstrate the rule, so the UI can bold/highlight them. Must match the
  // plain (diacritic-included) Uthmani text returned by the API for that
  // verse. Each example maps to a list of substrings to highlight (may be
  // empty if there's nothing specific to call out).
  static const Map<String, List<List<String>>> articleHighlightWords = {
    'tafkhim': [
      ['غَيْرِ', 'ٱلْمَغْضُوبِ', 'ٱلضَّآلِّينَ'],
      ['ٱلرَّحْمَـٰنُ'],
      ['خُلِقَ'],
    ],
    'tarqiq': [
      [],
      ['رِزْقُكُمْ'],
      ['ٱللَّهِ'],
    ],
  };

  static List<String> highlightWordsForExample(String articleId, int index) {
    final list = articleHighlightWords[articleId];
    if (list == null || index >= list.length) return const [];
    return list[index];
  }

  static List<AyahReference> referencesForArticle(String articleId) {
    final codes = articleExampleCodes[articleId];
    if (codes == null || codes.isEmpty) return const [];
    return codes
        .map((code) {
          if (code.length != 6) return null;
          final surah = int.tryParse(code.substring(0, 3));
          final ayah = int.tryParse(code.substring(3, 6));
          if (surah == null || ayah == null) return null;
          return (surah: surah, ayah: ayah);
        })
        .whereType<AyahReference>()
        .toList();
  }

  // Per-symbol audio references for the Waqf table, matching the excerpts
  // already curated in WaqfSymbols.examples (index -> surah/ayah), all from
  // Surah Al-Baqarah:
  // 0 م   (lazim)      -> 2:26
  // 1 لا  (la taqif)   -> 2:25
  // 2 ج   (ja'iz)      -> 2:19
  // 3 قلى (waqf awla)  -> 2:13
  // 4 صلى (wasl awla)  -> 2:5
  // 5 ∴   (mu'anaqah)  -> 2:2
  // 6 س   (sakta)      -> 2:245
  static const Map<int, String> waqfSymbolAudioCodes = {
    0: '002026',
    1: '002025',
    2: '002019',
    3: '002013',
    4: '002005',
    5: '002002',
    6: '002245',
  };

  static AyahReference? referenceForWaqfSymbol(int index) {
    final code = waqfSymbolAudioCodes[index];
    if (code == null || code.length != 6) return null;
    final surah = int.tryParse(code.substring(0, 3));
    final ayah = int.tryParse(code.substring(3, 6));
    if (surah == null || ayah == null) return null;
    return (surah: surah, ayah: ayah);
  }

  static const Map<TajweedRule, Set<int>> forcedHighlightWordIndices = {
    TajweedRule.izhar: {0},
    TajweedRule.shaddah: {2},
  };

  static const Map<TajweedRule, Map<int, String>>
  forcedMarkersAfterWordIndices = {
    TajweedRule.waqf: {3: 'ۘ'},
  };

  static AyahReference? referenceFor(TajweedRule rule) {
    final code = audioCodes[rule];
    if (code == null || code.length != 6) return null;

    final surah = int.tryParse(code.substring(0, 3));
    final ayah = int.tryParse(code.substring(3, 6));
    if (surah == null || ayah == null) return null;

    return (surah: surah, ayah: ayah);
  }

  static String codeForReference(AyahReference reference) {
    final surah = reference.surah.toString().padLeft(3, '0');
    final ayah = reference.ayah.toString().padLeft(3, '0');
    return '$surah$ayah';
  }
}
