import '../../core/models/tajweed_models.dart';

/// Single source of truth for *which part* of a rule's example word actually
/// demonstrates that rule.
///
/// Entry `i` of each list corresponds to `TajweedRuleDefinition.exampleArabic[i]`.
/// Fragments follow the same convention as the mushaf renderer:
///
/// * madd rules highlight **only** the madd/lin letter — never the preceding
///   consonant, the harakah before it, or the cause (hamzah / shaddah / sukoon);
/// * noon- and meem-based rules (idgham, ikhfa, iqlab, izhar) highlight the
///   carrier together with the letter that triggers the rule, matching the
///   spans the reader draws.
class RuleExampleHighlight {
  const RuleExampleHighlight._();

  static const Map<TajweedRule, List<String>> fragments = {
    TajweedRule.ghunnah: ['نَّ', 'مَّ', 'نَّ'],
    TajweedRule.qalqalah: ['دْ', 'بْ', 'جْ'],
    TajweedRule.maddTabeei: ['ا', 'و', 'ي'],
    TajweedRule.maddMuttasil: ['ا', 'ا', 'ا'],
    TajweedRule.maddMunfasil: ['ي', 'و', 'ا'],
    TajweedRule.maddSilahSughra: ['هِۦ', 'هُۥ'],
    TajweedRule.maddSilahKubra: ['هِۦٓ', 'هُۥٓ'],
    TajweedRule.idghamWithGhunnah: ['ن يَّ', 'ن نِّ'],
    TajweedRule.idghamWithoutGhunnah: ['ن رَّ', 'ًى لِّ'],
    TajweedRule.ikhfa: ['ن ك', 'نك', 'نت'],
    TajweedRule.iqlab: ['نْ ب', 'ٌ ب'],
    TajweedRule.izhar: ['نْ آ', 'ٌ ح'],
    TajweedRule.shaddah: ['يَّ', 'رَّ', 'مَّ'],
    TajweedRule.waqf: ['ۘ', 'ۙ', 'ۚ', 'ۗ', 'ۖ', 'ۛ', 'ۜ'],
    TajweedRule.sajdah: ['۩'],
    TajweedRule.maddLazimKalimiMuthaqqal: ['آ'],
    TajweedRule.maddLazimKalimiMukhaffaf: ['آ'],
    TajweedRule.maddLazimHarfiMuthaqqal: ['لٓ'],
    TajweedRule.maddLazimHarfiMukhaffaf: ['سٓ'],
    TajweedRule.maddAridLissukun: ['و', 'ي'],
    TajweedRule.maddLin: ['يْ', 'وْ'],
    TajweedRule.idghamShafawi: ['م مَّ'],
    TajweedRule.idghamMutajanisayn: ['د تَّ'],
    TajweedRule.ikhfaShafawi: ['م ب'],
    TajweedRule.hamzatWasl: ['ٱ', 'ٱ', 'ٱ'],
    TajweedRule.hamzatQat: ['أ', 'إ', 'أ'],
    TajweedRule.laamShamsiyah: ['ل', 'ل'],
    TajweedRule.silent: ['و', 'ٰ'],
  };

  /// The fragment that demonstrates [rule] inside `exampleArabic[exampleIndex]`.
  static String? fragmentFor(TajweedRule rule, int exampleIndex) {
    final list = fragments[rule];
    if (list == null || list.isEmpty) return null;
    return list[exampleIndex % list.length];
  }

  /// Character range of the rule inside [arabic], or `null` when it cannot be
  /// located. UI callers fall back to tinting the whole word.
  static ({int start, int end})? rangeIn(
    TajweedRule rule,
    String arabic,
    int exampleIndex,
  ) {
    final fragment = fragmentFor(rule, exampleIndex);
    if (fragment == null || fragment.isEmpty) return null;
    final start = arabic.indexOf(fragment);
    if (start < 0) return null;
    return (start: start, end: start + fragment.length);
  }
}
