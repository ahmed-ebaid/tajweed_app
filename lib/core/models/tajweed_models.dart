import 'package:flutter/material.dart';

// ─── Tajweed Rule Types ────────────────────────────────────────────────────

enum TajweedRule {
  ghunnah,
  qalqalah,
  maddTabeei,
  maddMuttasil,
  maddMunfasil,
  maddAridLissukun,
  maddLin,
  maddSilahSughra,
  maddSilahKubra,
  idghamWithGhunnah,
  idghamWithoutGhunnah,
  ikhfa,
  iqlab,
  izhar,
  shaddah,
  waqf,
  sajdah,
  maddLazimKalimiMuthaqqal,
  maddLazimKalimiMukhaffaf,
  maddLazimHarfiMuthaqqal,
  maddLazimHarfiMukhaffaf,
  idghamShafawi,
  idghamMutajanisayn,
  ikhfaShafawi,
  hamzatWasl,
  hamzatQat,
  laamShamsiyah,
  silent,
}

extension TajweedRuleExtension on TajweedRule {
  Color get color {
    switch (this) {
      // Every rule has a unique palette color shared by the legend and reader.
      case TajweedRule.ghunnah:
        return const Color(0xFFB35C00);
      case TajweedRule.qalqalah:
        return const Color(0xFFC73E1D);
      case TajweedRule.maddTabeei:
        return const Color(0xFF0072B2);
      case TajweedRule.maddMuttasil:
        return const Color(0xFF3B5BA9);
      case TajweedRule.maddMunfasil:
        return const Color(0xFF6A4C93);
      case TajweedRule.maddAridLissukun:
        return const Color(0xFF1F6F5C);
      case TajweedRule.maddLin:
        return const Color(0xFFB3003C);
      case TajweedRule.maddLazimKalimiMuthaqqal:
        return const Color(0xFF5A189A);
      case TajweedRule.maddLazimKalimiMukhaffaf:
        return const Color(0xFF000078);
      case TajweedRule.maddLazimHarfiMuthaqqal:
        return const Color(0xFF0000E4);
      case TajweedRule.maddLazimHarfiMukhaffaf:
        return const Color(0xFFA800E4);
      case TajweedRule.maddSilahSughra:
        return const Color(0xFF007A82);
      case TajweedRule.maddSilahKubra:
        return const Color(0xFFA23B72);
      case TajweedRule.idghamWithGhunnah:
        return const Color(0xFF007A5E);
      case TajweedRule.idghamWithoutGhunnah:
        return const Color(0xFF4D7C0F);
      case TajweedRule.idghamShafawi:
        return const Color(0xFF006D77);
      case TajweedRule.idghamMutajanisayn:
        return const Color(0xFF8A6D1D);
      case TajweedRule.ikhfa:
        return const Color(0xFF8E4A75);
      case TajweedRule.ikhfaShafawi:
        return const Color(0xFFB24592);
      case TajweedRule.iqlab:
        return const Color(0xFF9C4A00);
      case TajweedRule.izhar:
        return const Color(0xFF007C91);
      case TajweedRule.shaddah:
        return const Color(0xFF6B4C3B);
      case TajweedRule.waqf:
        return const Color(0xFF9A6700);
      case TajweedRule.sajdah:
        return const Color(0xFF37474F);
      case TajweedRule.hamzatWasl:
        return const Color(0xFF8C564B);
      case TajweedRule.hamzatQat:
        return const Color(0xFFAA3377);
      case TajweedRule.laamShamsiyah:
        return const Color(0xFF7A6E00);
      case TajweedRule.silent:
        return const Color(0xFF606060);
    }
  }

  /// Translatable name keys — look up via AppLocalizations
  String get nameKey {
    switch (this) {
      case TajweedRule.ghunnah:
        return 'rule_ghunnah';
      case TajweedRule.qalqalah:
        return 'rule_qalqalah';
      case TajweedRule.maddTabeei:
        return 'rule_madd_tabeei';
      case TajweedRule.maddMuttasil:
        return 'rule_madd_muttasil';
      case TajweedRule.maddMunfasil:
        return 'rule_madd_munfasil';
      case TajweedRule.maddAridLissukun:
        return 'rule_madd_arid_lissukun';
      case TajweedRule.maddLin:
        return 'rule_madd_lin';
      case TajweedRule.maddSilahSughra:
        return 'rule_madd_silah_sughra';
      case TajweedRule.maddSilahKubra:
        return 'rule_madd_silah_kubra';
      case TajweedRule.idghamWithGhunnah:
        return 'rule_idgham_ghunnah';
      case TajweedRule.idghamWithoutGhunnah:
        return 'rule_idgham_no_ghunnah';
      case TajweedRule.ikhfa:
        return 'rule_ikhfa';
      case TajweedRule.iqlab:
        return 'rule_iqlab';
      case TajweedRule.izhar:
        return 'rule_izhar';
      case TajweedRule.shaddah:
        return 'rule_shaddah';
      case TajweedRule.waqf:
        return 'rule_waqf';
      case TajweedRule.sajdah:
        return 'rule_sajdah';
      case TajweedRule.maddLazimKalimiMuthaqqal:
        return 'rule_madd_lazim_kalimi_muthaqqal';
      case TajweedRule.maddLazimKalimiMukhaffaf:
        return 'rule_madd_lazim_kalimi_mukhaffaf';
      case TajweedRule.maddLazimHarfiMuthaqqal:
        return 'rule_madd_lazim_harfi_muthaqqal';
      case TajweedRule.maddLazimHarfiMukhaffaf:
        return 'rule_madd_lazim_harfi_mukhaffaf';
      case TajweedRule.idghamShafawi:
        return 'rule_idgham_shafawi';
      case TajweedRule.idghamMutajanisayn:
        return 'rule_idgham_mutajanisayn';
      case TajweedRule.ikhfaShafawi:
        return 'rule_ikhfa_shafawi';
      case TajweedRule.hamzatWasl:
        return 'rule_hamzat_wasl';
      case TajweedRule.hamzatQat:
        return 'rule_hamzat_qat';
      case TajweedRule.laamShamsiyah:
        return 'rule_laam_shamsiyah';
      case TajweedRule.silent:
        return 'rule_silent';
    }
  }

  String get arabicName {
    switch (this) {
      case TajweedRule.ghunnah:
        return 'غُنَّة';
      case TajweedRule.qalqalah:
        return 'قَلْقَلَة';
      case TajweedRule.maddTabeei:
        return 'مَدّ طَبِيعِيّ';
      case TajweedRule.maddMuttasil:
        return 'مَدّ مُتَّصِل';
      case TajweedRule.maddMunfasil:
        return 'مَدّ مُنْفَصِل';
      case TajweedRule.maddAridLissukun:
        return 'مَدّ عَارِض لِلسُّكُون';
      case TajweedRule.maddLin:
        return 'مَدّ لِين';
      case TajweedRule.maddSilahSughra:
        return 'مَدّ صِلَة صُغْرَى';
      case TajweedRule.maddSilahKubra:
        return 'مَدّ صِلَة كُبْرَى';
      case TajweedRule.idghamWithGhunnah:
        return 'إِدْغَام بِغُنَّة';
      case TajweedRule.idghamWithoutGhunnah:
        return 'إِدْغَام بِلَا غُنَّة';
      case TajweedRule.ikhfa:
        return 'إِخْفَاء';
      case TajweedRule.iqlab:
        return 'إِقْلَاب';
      case TajweedRule.izhar:
        return 'إِظْهَار';
      case TajweedRule.shaddah:
        return 'شَدَّة';
      case TajweedRule.waqf:
        return 'وَقْف';
      case TajweedRule.sajdah:
        return 'سَجْدَة';
      case TajweedRule.maddLazimKalimiMuthaqqal:
        return 'مَدّ لَازِم كَلِمِيّ مُثَقَّل';
      case TajweedRule.maddLazimKalimiMukhaffaf:
        return 'مَدّ لَازِم كَلِمِيّ مُخَفَّف';
      case TajweedRule.maddLazimHarfiMuthaqqal:
        return 'مَدّ لَازِم حَرْفِيّ مُثَقَّل';
      case TajweedRule.maddLazimHarfiMukhaffaf:
        return 'مَدّ لَازِم حَرْفِيّ مُخَفَّف';
      case TajweedRule.idghamShafawi:
        return 'إِدْغَام شَفَوِيّ';
      case TajweedRule.idghamMutajanisayn:
        return 'إِدْغَام مُتَجَانِسَيْن';
      case TajweedRule.ikhfaShafawi:
        return 'إِخْفَاء شَفَوِيّ';
      case TajweedRule.hamzatWasl:
        return 'هَمْزَة وَصْل';
      case TajweedRule.hamzatQat:
        return 'هَمْزَة قَطْع';
      case TajweedRule.laamShamsiyah:
        return 'لَام شَمْسِيَّة';
      case TajweedRule.silent:
        return 'حَرْف سَاكِن';
    }
  }
}

// ─── Word-level tajweed annotation ───────────────────────────────────────────

class TajweedWord {
  final String arabic;
  final List<TajweedSpan> spans;
  final String? audioUrl;
  final int? lineNumber;

  const TajweedWord({
    required this.arabic,
    required this.spans,
    this.audioUrl,
    this.lineNumber,
  });
}

class TajweedSpan {
  final int start;
  final int end;
  final TajweedRule rule;

  const TajweedSpan({
    required this.start,
    required this.end,
    required this.rule,
  });
}

class TajweedSegment {
  final String text;
  final TajweedRule? rule;
  const TajweedSegment({required this.text, this.rule});
}

class AyahAudioWordTiming {
  final int wordIndex;
  final int startMs;
  final int endMs;

  const AyahAudioWordTiming({
    required this.wordIndex,
    required this.startMs,
    required this.endMs,
  });

  static int activeWordIndexAt(
    List<AyahAudioWordTiming> timings,
    Duration position,
  ) {
    var activeWordIndex = -1;
    for (final timing in timings) {
      if (position.inMilliseconds < timing.startMs) break;
      activeWordIndex = timing.wordIndex;
      if (position.inMilliseconds <= timing.endMs) break;
    }
    return activeWordIndex;
  }
}

class AyahAudioFile {
  final String url;
  final List<AyahAudioWordTiming> wordTimings;

  const AyahAudioFile({required this.url, required this.wordTimings});
}

// ─── Ayah model ───────────────────────────────────────────────────────────────

class Ayah {
  final int surahNumber;
  final int ayahNumber;
  final int pageNumber;
  final int? juzNumber;
  final int? hizbNumber;
  final int? rubElHizbNumber;
  final int? sajdahNumber;
  final String arabic;
  final Map<String, String> translations; // langCode → translation
  final List<TajweedWord> words;
  final int? endLineNumber;
  final String? audioUrl;
  final List<TajweedSegment> tajweedSegments;

  const Ayah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.pageNumber,
    this.juzNumber,
    this.hizbNumber,
    this.rubElHizbNumber,
    this.sajdahNumber,
    required this.arabic,
    required this.translations,
    required this.words,
    this.endLineNumber,
    this.audioUrl,
    this.tajweedSegments = const [],
  });

  String translation(String langCode) {
    final localized = translations[langCode]?.trim();
    if (localized != null && localized.isNotEmpty) {
      return localized;
    }

    final english = translations['en']?.trim();
    if (english != null && english.isNotEmpty) {
      return english;
    }

    return '';
  }

  String plainArabicText() {
    final verseText = arabic.trim();
    if (verseText.isNotEmpty) return verseText;

    if (words.isNotEmpty) {
      return words
          .map((word) => word.arabic.trim())
          .where((word) => word.isNotEmpty)
          .join(' ');
    }

    return tajweedSegments
        .map((segment) => segment.text)
        .join()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }
}

// ─── Tajweed Rule definition (for the rules library) ─────────────────────────

class TajweedRuleDefinition {
  final TajweedRule rule;
  final Map<String, String> names; // langCode → translated name
  final Map<String, String> descriptions; // langCode → translated description
  final List<String> exampleArabic; // Arabic words demonstrating the rule
  final List<String> triggerLetters; // Arabic letters that trigger this rule

  const TajweedRuleDefinition({
    required this.rule,
    required this.names,
    required this.descriptions,
    required this.exampleArabic,
    required this.triggerLetters,
  });

  String name(String langCode) => names[langCode] ?? names['en'] ?? '';
  String description(String langCode) =>
      descriptions[langCode] ?? descriptions['en'] ?? '';
}

// ─── Quiz model ───────────────────────────────────────────────────────────────

class QuizQuestion {
  final TajweedRule rule;
  final String arabicText;
  final List<QuizHighlightRange> highlightRanges;
  final Map<String, String> questionText; // langCode → question
  final List<Map<String, String>> options; // each: { langCode: option text }
  final int correctIndex;
  final Map<String, String> explanation; // langCode → explanation

  const QuizQuestion({
    required this.rule,
    required this.arabicText,
    required this.highlightRanges,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  String question(String langCode) =>
      questionText[langCode] ?? questionText['en'] ?? '';

  String optionText(int index, String langCode) =>
      options[index][langCode] ?? options[index]['en'] ?? '';

  String explain(String langCode) =>
      explanation[langCode] ?? explanation['en'] ?? '';
}

class QuizHighlightRange {
  final int start;
  final int end;

  const QuizHighlightRange({required this.start, required this.end});
}

// ─── Recitation feedback model ────────────────────────────────────────────────

class RecitationFeedback {
  final int overallScore;
  final Map<TajweedRule, double> ruleScores; // rule → 0.0–1.0
  final String audioPath;
  final DateTime timestamp;

  const RecitationFeedback({
    required this.overallScore,
    required this.ruleScores,
    required this.audioPath,
    required this.timestamp,
  });
}
