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
