import 'package:flutter/material.dart';

// ─── Tajweed Rule Types ────────────────────────────────────────────────────

enum TajweedRule {
  ghunnah,
  qalqalah,
  maddTabeei,
  maddMuttasil,
  maddMunfasil,
  idghamWithGhunnah,
  idghamWithoutGhunnah,
  ikhfa,
  iqlab,
  izhar,
  shaddah,
  waqf,
  sajdah,
  maddLazim,
  idghamShafawi,
  idghamMutajanisayn,
  ikhfaShafawi,
  hamzatWasl,
  laamShamsiyah,
  silent,
}

extension TajweedRuleExtension on TajweedRule {
  Color get color {
    switch (this) {
      // ── Madd / elongation ── Blues (light → dark by duration) ──────────────
      case TajweedRule.maddTabeei:
        return const Color(0xFF42A5F5);   // blue 400  – 2 counts
      case TajweedRule.maddMuttasil:
        return const Color(0xFF1565C0);   // blue 800  – 4–5 counts, connected
      case TajweedRule.maddMunfasil:
        return const Color(0xFF1976D2);   // blue 700  – 4–5 counts, separated
      case TajweedRule.maddLazim:
        return const Color(0xFF283593);   // indigo 900 – 6 counts, obligatory

      // ── Idgham / merging ── Greens ──────────────────────────────────────────
      case TajweedRule.idghamWithGhunnah:
        return const Color(0xFF388E3C);   // green 700
      case TajweedRule.idghamWithoutGhunnah:
        return const Color(0xFF33691E);   // light-green 900
      case TajweedRule.idghamShafawi:
        return const Color(0xFF00695C);   // teal 800
      case TajweedRule.idghamMutajanisayn:
        return const Color(0xFF1B5E20);   // green 900

      // ── Ikhfa / concealment ── Purples ──────────────────────────────────────
      case TajweedRule.ikhfa:
        return const Color(0xFF6A1B9A);   // purple 900
      case TajweedRule.ikhfaShafawi:
        return const Color(0xFF880E4F);   // pink 900 (distinct shade)

      // ── Nasalization ── Warm oranges ────────────────────────────────────────
      case TajweedRule.ghunnah:
        return const Color(0xFFE65100);   // deep orange 900
      case TajweedRule.iqlab:
        return const Color(0xFFBF360C);   // deep orange / burnt-red

      // ── Qalqalah ── Red ─────────────────────────────────────────────────────
      case TajweedRule.qalqalah:
        return const Color(0xFFC62828);   // red 800

      // ── Izhar ── Dark teal (replaces jarring pure cyan) ─────────────────────
      case TajweedRule.izhar:
        return const Color(0xFF00838F);   // cyan 800

      // ── Shaddah ── Brown ─────────────────────────────────────────────────────
      case TajweedRule.shaddah:
        return const Color(0xFF4E342E);   // brown 800

      // ── Structural / light letters ── Grays ─────────────────────────────────
      case TajweedRule.waqf:
        return const Color(0xFF616161);   // grey 700
      case TajweedRule.sajdah:
        return const Color(0xFF455A64);   // blue-grey 700
      case TajweedRule.hamzatWasl:
        return const Color(0xFF546E7A);   // blue-grey 600
      case TajweedRule.laamShamsiyah:
        return const Color(0xFF795548);   // brown 600
      case TajweedRule.silent:
        return const Color(0xFF9E9E9E);   // grey 500
    }
  }

  /// Translatable name keys — look up via AppLocalizations
  String get nameKey {
    switch (this) {
      case TajweedRule.ghunnah:          return 'rule_ghunnah';
      case TajweedRule.qalqalah:         return 'rule_qalqalah';
      case TajweedRule.maddTabeei:       return 'rule_madd_tabeei';
      case TajweedRule.maddMuttasil:     return 'rule_madd_muttasil';
      case TajweedRule.maddMunfasil:     return 'rule_madd_munfasil';
      case TajweedRule.idghamWithGhunnah:    return 'rule_idgham_ghunnah';
      case TajweedRule.idghamWithoutGhunnah: return 'rule_idgham_no_ghunnah';
      case TajweedRule.ikhfa:            return 'rule_ikhfa';
      case TajweedRule.iqlab:            return 'rule_iqlab';
      case TajweedRule.izhar:            return 'rule_izhar';
      case TajweedRule.shaddah:            return 'rule_shaddah';
      case TajweedRule.waqf:               return 'rule_waqf';
      case TajweedRule.sajdah:             return 'rule_sajdah';
      case TajweedRule.maddLazim:          return 'rule_madd_lazim';
      case TajweedRule.idghamShafawi:      return 'rule_idgham_shafawi';
      case TajweedRule.idghamMutajanisayn: return 'rule_idgham_mutajanisayn';
      case TajweedRule.ikhfaShafawi:       return 'rule_ikhfa_shafawi';
      case TajweedRule.hamzatWasl:         return 'rule_hamzat_wasl';
      case TajweedRule.laamShamsiyah:      return 'rule_laam_shamsiyah';
      case TajweedRule.silent:             return 'rule_silent';
    }
  }

  String get arabicName {
    switch (this) {
      case TajweedRule.ghunnah:               return 'غُنَّة';
      case TajweedRule.qalqalah:              return 'قَلْقَلَة';
      case TajweedRule.maddTabeei:            return 'مَدّ طَبِيعِيّ';
      case TajweedRule.maddMuttasil:          return 'مَدّ مُتَّصِل';
      case TajweedRule.maddMunfasil:          return 'مَدّ مُنْفَصِل';
      case TajweedRule.idghamWithGhunnah:     return 'إِدْغَام بِغُنَّة';
      case TajweedRule.idghamWithoutGhunnah:  return 'إِدْغَام بِلَا غُنَّة';
      case TajweedRule.ikhfa:                 return 'إِخْفَاء';
      case TajweedRule.iqlab:                 return 'إِقْلَاب';
      case TajweedRule.izhar:                 return 'إِظْهَار';
      case TajweedRule.shaddah:               return 'شَدَّة';
      case TajweedRule.waqf:                  return 'وَقْف';
      case TajweedRule.sajdah:                return 'سَجْدَة';
      case TajweedRule.maddLazim:             return 'مَدّ لَازِم';
      case TajweedRule.idghamShafawi:         return 'إِدْغَام شَفَوِيّ';
      case TajweedRule.idghamMutajanisayn:    return 'إِدْغَام مُتَجَانِسَيْن';
      case TajweedRule.ikhfaShafawi:          return 'إِخْفَاء شَفَوِيّ';
      case TajweedRule.hamzatWasl:            return 'هَمْزَة وَصْل';
      case TajweedRule.laamShamsiyah:         return 'لَام شَمْسِيَّة';
      case TajweedRule.silent:                return 'حَرْف سَاكِن';
    }
  }
}

// ─── Word-level tajweed annotation ───────────────────────────────────────────

class TajweedWord {
  final String arabic;
  final List<TajweedSpan> spans;
  final String? audioUrl;

  const TajweedWord({required this.arabic, required this.spans, this.audioUrl});
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

// ─── Ayah model ───────────────────────────────────────────────────────────────

class Ayah {
  final int surahNumber;
  final int ayahNumber;
  final int pageNumber;
  final String arabic;
  final Map<String, String> translations; // langCode → translation
  final List<TajweedWord> words;
  final String? audioUrl;
  final List<TajweedSegment> tajweedSegments;

  const Ayah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.pageNumber,
    required this.arabic,
    required this.translations,
    required this.words,
    this.audioUrl,
    this.tajweedSegments = const [],
  });

  String translation(String langCode) =>
      translations[langCode] ?? translations['en'] ?? '';
}

// ─── Tajweed Rule definition (for the rules library) ─────────────────────────

class TajweedRuleDefinition {
  final TajweedRule rule;
  final Map<String, String> names;         // langCode → translated name
  final Map<String, String> descriptions;  // langCode → translated description
  final List<String> exampleArabic;        // Arabic words demonstrating the rule
  final List<String> triggerLetters;       // Arabic letters that trigger this rule

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
  final Map<String, String> questionText;  // langCode → question
  final List<Map<String, String>> options; // each: { langCode: option text }
  final int correctIndex;
  final Map<String, String> explanation;  // langCode → explanation

  const QuizQuestion({
    required this.rule,
    required this.arabicText,
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
