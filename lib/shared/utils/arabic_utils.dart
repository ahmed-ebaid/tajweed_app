import 'package:characters/characters.dart';

/// Utilities for working with Arabic and Quranic text.
class ArabicUtils {
  /// The 28 Arabic letters used to identify tajweed trigger letters.
  static const arabicLetters = [
    'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز',
    'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك',
    'ل', 'م', 'ن', 'ه', 'و', 'ي',
  ];

  /// Qalqalah letters — echoing/bouncing sound.
  static const qalqalahLetters = ['ق', 'ط', 'ب', 'ج', 'د'];

  /// Idgham with ghunnah letters.
  static const idghamGhunnahLetters = ['ي', 'ن', 'م', 'و'];

  /// Idgham without ghunnah letters.
  static const idghamNoGhunnahLetters = ['ل', 'ر'];

  /// Izhar (throat) letters.
  static const izharLetters = ['ء', 'ه', 'ع', 'ح', 'غ', 'خ'];

  /// Ikhfa letters (15 letters).
  static const ikhfaLetters = [
    'ص', 'ذ', 'ث', 'ك', 'ج', 'ش', 'ق', 'س', 'د', 'ط',
    'ز', 'ف', 'ت', 'ض', 'ظ',
  ];

  /// Removes all Arabic diacritics (tashkeel) from text.
  /// Useful for search/comparison without vowel marks.
  static String removeTashkeel(String text) {
    // Unicode range for Arabic diacritics: U+0610–U+061A, U+064B–U+065F
    return text.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F]'), '');
  }

  /// Normalizes Arabic text for search: removes tashkeel and
  /// normalizes different forms of alif (أ إ آ ٱ → ا).
  static String normalizeForSearch(String text) {
    var result = removeTashkeel(text);
    result = result
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
    return result;
  }

  /// Returns true if [text] contains Arabic characters.
  static bool containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  /// Wraps an Arabic number string in Arabic-Indic numerals.
  /// e.g. 1 → ١, 2 → ٢, etc.
  static String toArabicNumerals(int number) {
    const western = ['0','1','2','3','4','5','6','7','8','9'];
    const eastern = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return number.toString().characters.map((c) {
      final i = western.indexOf(c);
      return i >= 0 ? eastern[i] : c;
    }).join();
  }
}
