import 'package:flutter/foundation.dart';

import '../models/tajweed_models.dart';
import 'quran_api_service.dart';

class _PronouncedLetterPosition {
  final int wordIndex;
  final String letter;

  const _PronouncedLetterPosition({
    required this.wordIndex,
    required this.letter,
  });
}

/// Maps raw Quran.com API v4 JSON responses into typed [Ayah] models
/// with word-level tajweed annotations.
class AyahMapper {
  static final RegExp _shaddaBeforeShortVowelPattern = RegExp(
    '\u0651([\u064B-\u0650])',
  );
  static const String _canonicalMarkerGlyph = '\u06DE';
  static const String _sajdahGlyph = '\u06E9';
  static const int _rubElHizbRune = 0x06DE;
  static const Set<int> _sajdahAyahKeys = {
    7 * 1000 + 206,
    13 * 1000 + 15,
    16 * 1000 + 50,
    17 * 1000 + 109,
    19 * 1000 + 58,
    22 * 1000 + 18,
    22 * 1000 + 77,
    25 * 1000 + 60,
    27 * 1000 + 26,
    32 * 1000 + 15,
    38 * 1000 + 24,
    41 * 1000 + 38,
    53 * 1000 + 62,
    84 * 1000 + 21,
    96 * 1000 + 19,
  };
  static const bool _debugMarkerAyahs = true;

  /// Converts a single verse JSON object from the API into an [Ayah].
  /// Optionally accepts [tajweedHtml] from the uthmani_tajweed endpoint.
  static Ayah fromApi(
    Map<String, dynamic> json, {
    String? tajweedHtml,
    String? requestedLangCode,
  }) {
    final verseKey = json['verse_key'] as String? ?? '1:1';
    final parts = verseKey.split(':');
    final surahNumber = int.tryParse(parts[0]) ?? 1;
    final ayahNumber = int.tryParse(parts[1]) ?? 1;
    final pageNumber = json['page_number'] as int? ?? 1;
    final juzNumber = json['juz_number'] as int?;
    final hizbNumber = json['hizb_number'] as int?;
    final rubElHizbNumber = json['rub_el_hizb_number'] as int?;
    final sajdahNumber = json['sajdah_number'] as int?;
    final forceRubElHizb =
        surahNumber == 2 && (ayahNumber == 142 || ayahNumber == 177);
    final forceSajdahGlyph = _isSajdahAyah(surahNumber, ayahNumber);

    // Preserve the source glyphs exactly, but reorder combining marks into
    // canonical form so shaddah + kasrah render correctly across font stacks.
    final arabic = _normalizeArabicText(
      json['text_uthmani'] as String? ?? '',
      forceRubElHizb: forceRubElHizb,
      forceSajdahGlyph: forceSajdahGlyph,
    );

    // Translations — API may return as a list of translation objects
    final translations = <String, String>{};
    final rawTranslations = json['translations'] as List<dynamic>? ?? [];
    for (final t in rawTranslations) {
      if (t is Map) {
        final map = Map<String, dynamic>.from(t);
        final langCode =
            _langCodeFromResourceId(map['resource_id']) ??
            _langCodeFromName(map['language_name']) ??
            requestedLangCode;
        final text = _stripHtml(map['text'] as String? ?? '');
        if (langCode != null && text.isNotEmpty) {
          translations[langCode] = text;
        }
      }
    }

    // Words with tajweed spans
    final rawWords = json['words'] as List<dynamic>? ?? [];
    final endLineNumber = rawWords
        .whereType<Map>()
        .map((word) => Map<String, dynamic>.from(word))
        .where((word) => word['char_type_name'] == 'end')
        .map((word) => word['line_number'])
        .whereType<int>()
        .firstOrNull;
    final adjustedWords = _applyEndTokenShiftFix(rawWords);
    final hasSajdahInNonEndWord = adjustedWords
        .whereType<Map>()
        .map((w) => Map<String, dynamic>.from(w))
        .where((w) => (w['char_type_name'] as String?) != 'end')
        .any(
          (w) => _containsSajdahInWordDisplaySource(
            w,
            forceRubElHizb: forceRubElHizb,
            forceSajdahGlyph: forceSajdahGlyph,
          ),
        );
    final words = adjustedWords
        .where((w) {
          if (w['char_type_name'] != 'end') return true;
          // Keep end-marker words that carry the sajdah sign so it renders,
          // even when shifted tajweed payload overwrote end-token tajweed text.
          // If a non-end word already contains sajdah, drop this end token to
          // avoid rendering a duplicate ۩ symbol.
          if (hasSajdahInNonEndWord) {
            return false;
          }
          return _containsSajdahInEndToken(Map<String, dynamic>.from(w));
        })
        .whereType<Map>()
        .map<TajweedWord>((w) {
          final mapped = Map<String, dynamic>.from(w);
          if ((mapped['char_type_name'] as String?) == 'end') {
            final tajweedText =
                (mapped['text_uthmani_tajweed'] as String? ?? '');
            final uthmaniText =
                (mapped['text_uthmani'] as String? ??
                mapped['text'] as String? ??
                '');
            if (!tajweedText.contains('\u06E9') &&
                uthmaniText.contains('\u06E9')) {
              mapped['text_uthmani_tajweed'] = uthmaniText;
            }
          }
          return _mapWord(
            mapped,
            forceRubElHizb: forceRubElHizb,
            forceSajdahGlyph: forceSajdahGlyph,
          );
        })
        .toList();
    final wordsWithCorrectedMadd = _correctMaddMuttasilRules(words);
    final wordsWithMaddSilah = _applyMaddSilahRules(wordsWithCorrectedMadd);

    if (_debugMarkerAyahs &&
        surahNumber == 2 &&
        (ayahNumber == 142 || ayahNumber == 177)) {
      final markerWords = words
          .where((w) => _containsPotentialMarker(w.arabic))
          .map((w) => '${w.arabic} => ${_toCodepoints(w.arabic)}')
          .join(' | ');
      if (kDebugMode) {
        print(
          '🔎 MARKER DEBUG $surahNumber:$ayahNumber ayah=${_toCodepoints(arabic)} words=$markerWords',
        );
      }
    }

    // Audio URL
    final audioRaw = json['audio'];
    final audio = audioRaw is Map ? Map<String, dynamic>.from(audioRaw) : null;
    final audioUrl = audio?['url'] as String?;

    // Parse verse-level tajweed segments from uthmani_tajweed HTML
    final tajweedSegments = tajweedHtml != null
        ? parseTajweedHtml(tajweedHtml)
        : <TajweedSegment>[];

    return Ayah(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      pageNumber: pageNumber,
      juzNumber: juzNumber,
      hizbNumber: hizbNumber,
      rubElHizbNumber: rubElHizbNumber,
      sajdahNumber: sajdahNumber,
      arabic: arabic,
      translations: translations,
      words: wordsWithMaddSilah,
      endLineNumber: endLineNumber,
      audioUrl: audioUrl,
      tajweedSegments: tajweedSegments,
    );
  }

  /// Converts a list of verse JSON objects into [Ayah] models.
  static List<Ayah> fromApiList(
    List<Map<String, dynamic>> verses, {
    Map<String, String>? tajweedMap,
    String? requestedLangCode,
  }) {
    return verses.map((v) {
      final key = v['verse_key'] as String? ?? '';
      return fromApi(
        v,
        tajweedHtml: tajweedMap?[key],
        requestedLangCode: requestedLangCode,
      );
    }).toList();
  }

  static String? langCodeFromResourceId(dynamic resourceId) {
    return _langCodeFromResourceId(resourceId);
  }

  // Quran.com sometimes shifts word-level `text_uthmani_tajweed` into the next
  // token and places the last real word's tajweed on the `end` token.
  // Detect this by checking whether the end-token tajweed differs from its
  // ayah-number glyph text, then realign per token order.
  static List<Map<String, dynamic>> _applyEndTokenShiftFix(
    List<dynamic> rawWords,
  ) {
    final words = rawWords
        .whereType<Map>()
        .map((w) => Map<String, dynamic>.from(w))
        .toList(growable: false);

    if (words.isEmpty) return words;

    int endIndex = -1;
    for (int i = words.length - 1; i >= 0; i--) {
      if ((words[i]['char_type_name'] as String?) == 'end') {
        endIndex = i;
        break;
      }
    }
    if (endIndex < 0) return words;

    final endToken = words[endIndex];
    final endText =
        (endToken['text_uthmani'] as String? ??
                endToken['text'] as String? ??
                '')
            .trim();
    final endTajweed = (endToken['text_uthmani_tajweed'] as String? ?? '')
        .trim();

    // Sajdah/rub-el-hizb markers can legitimately appear on the end token and
    // make `endTajweed != endText` even when there is no shifted payload.
    // In that case, do not realign words or we risk dropping the first word.
    if (endTajweed.contains(_sajdahGlyph) ||
        endTajweed.contains(_canonicalMarkerGlyph) ||
        endTajweed.contains('۝')) {
      return words;
    }

    // Case 1 (clean): tajweed equals glyph text, no correction needed.
    if (endText.isEmpty || endTajweed.isEmpty || endTajweed == endText) {
      return words;
    }

    final fixed = words.map((w) => Map<String, dynamic>.from(w)).toList();
    final nonEndIndices = <int>[];
    for (int i = 0; i < fixed.length; i++) {
      if ((fixed[i]['char_type_name'] as String?) != 'end') {
        nonEndIndices.add(i);
      }
    }
    if (nonEndIndices.isEmpty) return fixed;

    for (final idx in nonEndIndices) {
      if (idx + 1 >= words.length) continue;
      final nextTajweed = words[idx + 1]['text_uthmani_tajweed'] as String?;
      if (nextTajweed == null || nextTajweed.isEmpty) continue;
      fixed[idx]['text_uthmani_tajweed'] = nextTajweed;
    }

    // Ensure the last real word always receives the end token tajweed.
    fixed[nonEndIndices.last]['text_uthmani_tajweed'] =
        endToken['text_uthmani_tajweed'];
    return fixed;
  }

  static TajweedWord _mapWord(
    Map<String, dynamic> w, {
    bool forceRubElHizb = false,
    bool forceSajdahGlyph = false,
  }) {
    // Keep display text and span positions aligned by deriving both from the
    // same source (`text_uthmani_tajweed`) when available.
    final wordTajweedHtml = w['text_uthmani_tajweed'] as String?;
    final sourceText = (wordTajweedHtml != null && wordTajweedHtml.isNotEmpty)
        ? _stripHtmlPreserveSpacing(wordTajweedHtml)
        : (w['text_uthmani'] as String? ?? '');
    final textForDisplay = _normalizeArabicText(
      sourceText,
      forceRubElHizb: forceRubElHizb,
      forceSajdahGlyph: forceSajdahGlyph,
    );
    final spans = <TajweedSpan>[];

    // Parse modern per-word rule tags first.
    if (wordTajweedHtml != null && wordTajweedHtml.isNotEmpty) {
      spans.addAll(_parseRuleTagTajweed(textForDisplay, wordTajweedHtml));
    }

    // Fallback: legacy compact tajweed code format.
    if (spans.isEmpty) {
      final tajweedRaw = w['tajweed'];
      if (tajweedRaw is String && tajweedRaw.isNotEmpty) {
        spans.addAll(_parseTajweedCodes(textForDisplay, tajweedRaw));
      }
    }

    // Detect ۩ (U+06E9 Arabic place of sajdah) embedded directly in text.
    // The API uses a plain Unicode character — no HTML class is emitted.
    const sajdahChar = '\u06E9';
    var sajdahIdx = textForDisplay.indexOf(sajdahChar);
    while (sajdahIdx >= 0) {
      spans.add(
        TajweedSpan(
          start: sajdahIdx,
          end: sajdahIdx + 1,
          rule: TajweedRule.sajdah,
        ),
      );
      sajdahIdx = textForDisplay.indexOf(sajdahChar, sajdahIdx + 1);
    }

    return TajweedWord(
      arabic: textForDisplay,
      spans: spans,
      audioUrl: w['audio_url'] as String?,
      lineNumber: w['line_number'] as int?,
    );
  }

  static List<TajweedWord> _applyMaddSilahRules(List<TajweedWord> words) {
    const silahMarkers = {'\u06E5', '\u06E6'};
    const hamzaLetters = {'ء', 'أ', 'إ', 'آ', 'ٱ'};
    final result = <TajweedWord>[];

    for (int wordIndex = 0; wordIndex < words.length; wordIndex++) {
      final word = words[wordIndex];
      final spans = List<TajweedSpan>.from(word.spans);

      for (
        int markerIndex = 0;
        markerIndex < word.arabic.length;
        markerIndex++
      ) {
        if (!silahMarkers.contains(word.arabic[markerIndex])) continue;

        var start = markerIndex - 1;
        while (start >= 0 &&
            _isArabicCombiningMark(word.arabic.codeUnitAt(start))) {
          start--;
        }
        if (start < 0 || word.arabic[start] != 'ه') continue;

        final nextLetter = _nextPronouncedLetter(
          words,
          wordIndex: wordIndex,
          characterIndex: markerIndex + 1,
        );
        final rule = nextLetter != null && hamzaLetters.contains(nextLetter)
            ? TajweedRule.maddSilahKubra
            : TajweedRule.maddSilahSughra;
        final end = _extendOverCombining(word.arabic, markerIndex + 1);

        spans.removeWhere((span) => span.start < end && span.end > start);
        spans.add(TajweedSpan(start: start, end: end, rule: rule));
      }

      spans.sort((a, b) => a.start.compareTo(b.start));
      result.add(
        TajweedWord(
          arabic: word.arabic,
          spans: spans,
          audioUrl: word.audioUrl,
          lineNumber: word.lineNumber,
        ),
      );
    }

    return result;
  }

  static List<TajweedWord> _correctMaddMuttasilRules(List<TajweedWord> words) {
    const hamzaLetters = {'ء', 'أ', 'إ', 'آ', 'ٱ'};

    return [
      for (int wordIndex = 0; wordIndex < words.length; wordIndex++)
        TajweedWord(
          arabic: words[wordIndex].arabic,
          audioUrl: words[wordIndex].audioUrl,
          lineNumber: words[wordIndex].lineNumber,
          spans: [
            for (final span in words[wordIndex].spans)
              if (span.rule == TajweedRule.maddMuttasil)
                TajweedSpan(
                  start: span.start,
                  end: span.end,
                  rule: switch (_nextPronouncedLetterPosition(
                    words,
                    wordIndex: wordIndex,
                    characterIndex: span.end,
                  )) {
                    final position?
                        when position.wordIndex > wordIndex &&
                            hamzaLetters.contains(position.letter) =>
                      TajweedRule.maddMunfasil,
                    _ => TajweedRule.maddMuttasil,
                  },
                )
              else
                span,
          ],
        ),
    ];
  }

  static _PronouncedLetterPosition? _nextPronouncedLetterPosition(
    List<TajweedWord> words, {
    required int wordIndex,
    required int characterIndex,
  }) {
    for (
      int currentWord = wordIndex;
      currentWord < words.length;
      currentWord++
    ) {
      final word = words[currentWord];
      final start = currentWord == wordIndex ? characterIndex : 0;
      for (int i = start; i < word.arabic.length; i++) {
        final codeUnit = word.arabic.codeUnitAt(i);
        if (_isArabicCombiningMark(codeUnit) ||
            word.arabic[i].trim().isEmpty ||
            _isWaqfMark(codeUnit) ||
            _isCoveredByRule(word.spans, i, TajweedRule.silent)) {
          continue;
        }
        return _PronouncedLetterPosition(
          wordIndex: currentWord,
          letter: word.arabic[i],
        );
      }
    }
    return null;
  }

  static bool _isCoveredByRule(
    List<TajweedSpan> spans,
    int characterIndex,
    TajweedRule rule,
  ) {
    return spans.any(
      (span) =>
          span.rule == rule &&
          span.start <= characterIndex &&
          characterIndex < span.end,
    );
  }

  static bool _isWaqfMark(int codeUnit) {
    return codeUnit >= 0x06D6 && codeUnit <= 0x06DC;
  }

  static String? _nextPronouncedLetter(
    List<TajweedWord> words, {
    required int wordIndex,
    required int characterIndex,
  }) {
    for (
      int currentWord = wordIndex;
      currentWord < words.length;
      currentWord++
    ) {
      final text = words[currentWord].arabic;
      final start = currentWord == wordIndex ? characterIndex : 0;
      for (int i = start; i < text.length; i++) {
        final codeUnit = text.codeUnitAt(i);
        if (_isArabicCombiningMark(codeUnit) || text[i].trim().isEmpty) {
          continue;
        }
        return text[i];
      }
    }
    return null;
  }

  static bool _isArabicCombiningMark(int codeUnit) {
    return (codeUnit >= 0x0610 && codeUnit <= 0x061A) ||
        (codeUnit >= 0x064B && codeUnit <= 0x065F) ||
        (codeUnit >= 0x06D6 && codeUnit <= 0x06ED);
  }

  // ─── Madd 'arid lil-sukun vs madd lin ──────────────────────────────────────
  // Quran.com collapses both into the single class `madda_permissible`, but the
  // two are distinguishable from the text alone:
  //   * madd letter is an alif form                        → 'arid lil-sukun
  //   * damma + waw, or kasra + ya  (homogeneous vowel)     → 'arid lil-sukun
  //   * fatha + waw/ya             (heterogeneous vowel)    → lin
  // Verified against all 4543 `madda_permissible` spans in the mushaf: 4535
  // resolve to 'arid and 8 to lin (55:17, 90:8-10, 106:1-4), with no leftovers.
  static const int _fatha = 0x064E;
  static const int _damma = 0x064F;
  static const int _kasra = 0x0650;
  static const int _waw = 0x0648;
  static const int _ya = 0x064A;
  static const int _tatweel = 0x0640;

  /// Alif-family madd letters, including the dagger alif (U+0670), alif
  /// maqsura (U+0649), alif wasla (U+0671) and the small waw/ya madd glyphs.
  static bool _isAlifFormMaddLetter(int cp) {
    return cp == 0x0627 ||
        cp == 0x0649 ||
        cp == 0x0670 ||
        cp == 0x0671 ||
        cp == 0x0672 ||
        cp == 0x06E5 ||
        cp == 0x06E6;
  }

  static bool _isMaddLetter(int cp) {
    return _isAlifFormMaddLetter(cp) || cp == _waw || cp == _ya;
  }

  /// Index of the madd letter inside [start, end), or -1.
  static int _findMaddLetter(String text, int start, int end) {
    for (int i = end - 1; i >= start; i--) {
      if (_isMaddLetter(text.codeUnitAt(i))) return i;
    }
    return -1;
  }

  /// Resolves the ambiguous `madda_permissible` class into either
  /// [TajweedRule.maddLin] or [TajweedRule.maddAridLissukun].
  static TajweedRule _resolvePermissibleMadd(String text, int start, int end) {
    final maddIdx = _findMaddLetter(text, start, end);
    if (maddIdx < 0) return TajweedRule.maddAridLissukun;

    final letter = text.codeUnitAt(maddIdx);
    if (_isAlifFormMaddLetter(letter)) return TajweedRule.maddAridLissukun;

    // Walk back to the harakah sitting on the preceding consonant.
    for (int i = maddIdx - 1; i >= 0 && i >= maddIdx - 3; i--) {
      final cp = text.codeUnitAt(i);
      if (cp == _tatweel) continue;
      if (cp == _fatha) {
        return (letter == _waw || letter == _ya)
            ? TajweedRule.maddLin
            : TajweedRule.maddAridLissukun;
      }
      if (cp == _damma || cp == _kasra) return TajweedRule.maddAridLissukun;
      if (_isArabicCombiningMark(cp)) continue;
      break;
    }
    return TajweedRule.maddAridLissukun;
  }

  /// Advances [startIdx] past leading Arabic combining marks so a span begins
  /// on a base letter. A combining mark renders on the *preceding* base letter,
  /// which sits outside the span — without this, highlighting `ُو` in
  /// يَعْمَهُونَ (15:72) tints the damma sitting on the ه and makes the ه look
  /// highlighted, when only the و should be. Never returns an empty span.
  static int _trimLeadingCombining(String text, int startIdx, int endIdx) {
    int i = startIdx;
    while (i < endIdx && _isArabicCombiningMark(text.codeUnitAt(i))) {
      i++;
    }
    return i < endIdx ? i : startIdx;
  }

  /// Muqatta'at letters that carry a six-count madd when spelled out, mapped
  /// to the final consonant of their spelled name (e.g. ل -> لام ends in م).
  static const Map<int, int> _muqattaatFinalConsonant = {
    0x0644: 0x0645, // ل  لام  -> م
    0x0645: 0x0645, // م  ميم  -> م
    0x0646: 0x0646, // ن  نون  -> ن
    0x0642: 0x0641, // ق  قاف  -> ف
    0x0635: 0x062F, // ص  صاد  -> د
    0x0639: 0x0646, // ع  عين  -> ن
    0x0633: 0x0646, // س  سين  -> ن
    0x0643: 0x0641, // ك  كاف  -> ف
  };

  /// Letters that ن assimilates into (يرملون). م only assimilates into م.
  static const Set<int> _nunIdghamTargets = {
    0x064A, 0x0631, 0x0645, 0x0644, 0x0648, 0x0646,
  };

  static bool _isArabicLetter(int cp) =>
      (cp >= 0x0621 && cp <= 0x064A) || cp == 0x0671 || cp == 0x0649;

  /// True for characters that end the current word for classification
  /// purposes: whitespace, ZWNJ, and the Quranic waqf marks.
  static bool _isWordBreak(int cp) =>
      cp == 0x20 ||
      cp == 0x09 ||
      cp == 0x0A ||
      cp == 0x200C ||
      (cp >= 0x06D6 && cp <= 0x06ED);

  static bool _consonantAssimilates(int finalCp, int nextCp) {
    if (finalCp == 0x0645) return nextCp == 0x0645;
    if (finalCp == 0x0646) return _nunIdghamTargets.contains(nextCp);
    return finalCp == nextCp;
  }

  static bool _isNecessaryMaddClass(String className) {
    return className == 'madda_necessary' ||
        className == 'madd_lazim' ||
        className == 'madda_obligatory_lazim';
  }

  /// Splits the upstream `madda_necessary` class into the four classical
  /// Madd Lazim types.
  ///
  /// Verified against the complete tajweed mushaf: all 143 `madda_necessary`
  /// spans classify with zero leftovers — كلمي مثقل 97, كلمي مخفف 2
  /// (10:51 and 10:91, the only two in the Qur'an), حرفي مثقل 10,
  /// حرفي مخفف 34.
  ///
  /// The split is derived from the text alone — no surah/ayah table — so it
  /// behaves identically in the ayah-by-ayah and Mushaf page views, which
  /// both render spans produced here.
  static TajweedRule _resolveNecessaryMadd(String text, int start, int end) {
    // حرفي: the span is a single muqatta'at letter carrying a maddah with no
    // short vowel (e.g. لٓ, مٓ, صٓ). Anything else is كلمي.
    int letterCp = -1;
    var letterCount = 0;
    var hasMaddah = false;
    var hasHarakah = false;
    for (var i = start; i < end; i++) {
      final cp = text.codeUnitAt(i);
      if (_isArabicLetter(cp)) {
        letterCount++;
        letterCp = cp;
      } else if (cp == 0x0653) {
        hasMaddah = true;
      } else if ((cp >= 0x064B && cp <= 0x0650) || cp == 0x0652) {
        hasHarakah = true;
      }
    }

    // Scan the remainder of the *same word* only; a following word never
    // decides the type (e.g. نٓ وَٱلْقَلَمِ in 68:1 stays مخفف).
    int nextLetter = -1;
    var sawShaddah = false;
    var scanned = 0;
    for (var i = end; i < text.length; i++) {
      final cp = text.codeUnitAt(i);
      if (_isWordBreak(cp)) break;
      if (cp == 0x0651 && scanned < 3) sawShaddah = true;
      if (nextLetter < 0 && _isArabicLetter(cp)) nextLetter = cp;
      scanned++;
    }

    final isHarfi = letterCount == 1 &&
        hasMaddah &&
        !hasHarakah &&
        _muqattaatFinalConsonant.containsKey(letterCp);

    if (isHarfi) {
      final finalCp = _muqattaatFinalConsonant[letterCp]!;
      final heavy =
          nextLetter >= 0 && _consonantAssimilates(finalCp, nextLetter);
      return heavy
          ? TajweedRule.maddLazimHarfiMuthaqqal
          : TajweedRule.maddLazimHarfiMukhaffaf;
    }

    return sawShaddah
        ? TajweedRule.maddLazimKalimiMuthaqqal
        : TajweedRule.maddLazimKalimiMukhaffaf;
  }

  static bool _isPermissibleMaddClass(String className) {
    return className == 'madda_permissible' ||
        className == 'madd_arid' ||
        className == 'madd_arid_lissukun';
  }

  static List<TajweedSpan> _parseRuleTagTajweed(
    String arabicText,
    String tajweedHtml,
  ) {
    final spans = <TajweedSpan>[];
    final pattern = RegExp(r'<rule\s+class="?([\w-]+)"?>([\s\S]*?)</rule>');
    int searchFrom = 0;

    for (final match in pattern.allMatches(tajweedHtml)) {
      final className = match.group(1) ?? '';
      final rule =
          _ruleFromTajweedClass(className) ?? _ruleFromClassName(className);
      if (rule == null) continue;

      final inner = match.group(2) ?? '';
      final ruleText = _normalizeArabicText(_stripHtmlPreserveSpacing(inner));
      if (ruleText.isEmpty) continue;

      // --- Span search (three passes, most-to-least strict) ---
      int idx = -1;
      int endIdx = -1;

      // Prefer the rule's source offset. Searching only by its inner text can
      // select an earlier identical sequence, as in ءَابَآءَنَآ.
      final sourcePrefix = _normalizeArabicText(
        _stripHtmlPreserveSpacing(tajweedHtml.substring(0, match.start)),
      );
      if (sourcePrefix.length <= arabicText.length) {
        final sourceMatch = _flexibleMatch(
          arabicText,
          ruleText,
          sourcePrefix.length,
        );
        if (sourceMatch != null && sourceMatch[0] == sourcePrefix.length) {
          idx = sourceMatch[0];
          endIdx = sourceMatch[1];
        }
      }

      // Pass 1: exact match
      final exactIdx = arabicText.indexOf(ruleText, searchFrom);
      if (idx < 0 && exactIdx >= 0) {
        idx = exactIdx;
        endIdx = exactIdx + ruleText.length;
      }

      // Pass 2: sukun-normalised match (U+06E1 ۡ ↔ U+0652 ْ variants).
      if (idx < 0) {
        final normalizedArabic = _normaliseSukun(arabicText);
        final normalizedRule = _normaliseSukun(ruleText);
        final ni = normalizedArabic.indexOf(normalizedRule, searchFrom);
        if (ni >= 0) {
          idx = ni;
          endIdx = ni + ruleText.length;
        }
      }

      // Pass 3: flexible match – allows optional Arabic diacritics between
      // adjacent chars. Needed when the word text has a short vowel between
      // consonant and shadda (e.g. م+َ+ّ after normalization) while the
      // rule text has only consonant+shadda (مّ).
      if (idx < 0) {
        final fm = _flexibleMatch(arabicText, ruleText, searchFrom);
        if (fm != null) {
          idx = fm[0];
          endIdx = fm[1];
        }
      }

      if (idx < 0) continue;

      // Extend endIdx over any trailing Arabic combining / Quranic marks
      // (e.g. U+06ED ۭ small low meem, U+06E2 ۢ small high meem) that
      // belong to the same grapheme cluster but are absent from rule text.
      endIdx = _extendOverCombining(arabicText, endIdx);

      // Drop leading combining marks: a combining mark renders on the base
      // letter *before* the span, so including it tints a letter that is not
      // part of the rule (see _trimLeadingCombining).
      idx = _trimLeadingCombining(arabicText, idx, endIdx);

      // `madda_permissible` covers both madd 'arid lil-sukun and madd lin;
      // disambiguate now that we know where the span sits in the text.
      final resolvedRule = _isPermissibleMaddClass(className)
          ? _resolvePermissibleMadd(arabicText, idx, endIdx)
          : _isNecessaryMaddClass(className)
          ? _resolveNecessaryMadd(arabicText, idx, endIdx)
          : rule;

      spans.add(TajweedSpan(start: idx, end: endIdx, rule: resolvedRule));
      searchFrom = endIdx;
    }

    return spans;
  }

  static bool _containsSajdahInWordDisplaySource(
    Map<String, dynamic> word, {
    required bool forceRubElHizb,
    required bool forceSajdahGlyph,
  }) {
    final wordTajweedHtml = word['text_uthmani_tajweed'] as String?;
    final sourceText = (wordTajweedHtml != null && wordTajweedHtml.isNotEmpty)
        ? _stripHtmlPreserveSpacing(wordTajweedHtml)
        : (word['text_uthmani'] as String? ?? '');
    final normalized = _normalizeArabicText(
      sourceText,
      forceRubElHizb: forceRubElHizb,
      forceSajdahGlyph: forceSajdahGlyph,
    );
    return normalized.contains(_sajdahGlyph);
  }

  static bool _containsSajdahInEndToken(Map<String, dynamic> endToken) {
    final tajweedText = endToken['text_uthmani_tajweed'] as String? ?? '';
    final uthmaniText =
        (endToken['text_uthmani'] as String? ??
                endToken['text'] as String? ??
                '')
            .trim();
    return tajweedText.contains(_sajdahGlyph) ||
        uthmaniText.contains(_sajdahGlyph);
  }

  /// Normalises U+06E1 (ۡ Quranic sukun) and U+06E2 (ۢ) to U+0652 (ْ sukun)
  /// so that span lookups work regardless of which code-point the API uses.
  static String _normaliseSukun(String text) {
    return _normalizeArabicText(
      text.replaceAll('\u06E1', '\u0652').replaceAll('\u06E2', '\u0652'),
    );
  }

  /// Builds a regex that matches [ruleText] with optional Arabic diacritics
  /// between each pair of adjacent code units. Returns [start, end) indices
  /// into [arabicText] on a match, or null.
  static List<int>? _flexibleMatch(
    String arabicText,
    String ruleText,
    int searchFrom,
  ) {
    if (ruleText.isEmpty) return null;
    final buf = StringBuffer();
    for (int i = 0; i < ruleText.length; i++) {
      buf.write(RegExp.escape(String.fromCharCode(ruleText.codeUnitAt(i))));
      if (i < ruleText.length - 1) {
        // Allow any number of Arabic diacritics / small Quranic marks between
        // consecutive rule characters. Include shaddah (U+0651) so spans
        // like َا can still match when text contains َّا after normalization.
        buf.write('[\u064B-\u0652\u06D6-\u06ED]*');
      }
    }
    final re = RegExp(buf.toString());
    final sub = arabicText.substring(searchFrom);
    final m = re.firstMatch(sub);
    if (m == null) return null;
    return [searchFrom + m.start, searchFrom + m.end];
  }

  /// Advances [endIdx] past any trailing Arabic combining marks so that the
  /// span covers the full grapheme cluster (e.g. the trailing ۭ in لَيْلَةًۭ).
  static int _extendOverCombining(String text, int endIdx) {
    while (endIdx < text.length) {
      final cp = text.codeUnitAt(endIdx);
      if ((cp >= 0x0610 && cp <= 0x061A) || // Arabic extended combining
          (cp >= 0x064B && cp <= 0x065F) || // Arabic diacritics
          ((cp >= 0x06D6 && cp <= 0x06ED) && cp != 0x06E9)) {
        // Quranic annotation marks (exclude sajdah sign ۩)
        endIdx++;
      } else {
        break;
      }
    }
    return endIdx;
  }

  /// Parses Quran.com tajweed annotation strings into character-level spans.
  ///
  /// The API can return tajweed data in two formats:
  /// 1. Single character code per word: 'g', 'q', etc.
  /// 2. HTML-like spans: `<tajweed class="tajweed-rule">text</tajweed>`
  ///
  /// We handle both.
  static List<TajweedSpan> _parseTajweedCodes(
    String arabicText,
    String tajweedData,
  ) {
    final spans = <TajweedSpan>[];

    // Format 1: single-char code → whole word is that rule
    if (tajweedData.length == 1) {
      final rule = QuranApiService.ruleFromCode(tajweedData);
      if (rule != null) {
        spans.add(TajweedSpan(start: 0, end: arabicText.length, rule: rule));
      }
      return spans;
    }

    // Format 2: HTML-like tajweed markup
    // e.g. <tajweed class="tajweed_ghunnah">نّ</tajweed>
    final tagPattern = RegExp(
      r'<tajweed\s+class="tajweed[_-](\w+)">([^<]+)</tajweed>',
    );
    int searchFrom = 0;
    for (final match in tagPattern.allMatches(tajweedData)) {
      final ruleKey = match.group(1) ?? '';
      final ruleText = _normalizeArabicText(match.group(2) ?? '');
      final rule = _ruleFromClassName(ruleKey);
      if (rule != null && ruleText.isNotEmpty) {
        final idx = arabicText.indexOf(ruleText, searchFrom);
        if (idx >= 0) {
          final endIdx = idx + ruleText.length;
          final start = _trimLeadingCombining(arabicText, idx, endIdx);
          final resolvedRule = _isPermissibleMaddClass(ruleKey)
              ? _resolvePermissibleMadd(arabicText, start, endIdx)
              : _isNecessaryMaddClass(ruleKey)
              ? _resolveNecessaryMadd(arabicText, start, endIdx)
              : rule;
          spans.add(
            TajweedSpan(start: start, end: endIdx, rule: resolvedRule),
          );
          searchFrom = endIdx;
        }
      }
    }

    return spans;
  }

  static TajweedRule? _ruleFromClassName(String className) {
    switch (className) {
      case 'ghunnah':
      case 'ghn':
        return TajweedRule.ghunnah;
      case 'qalqalah':
      case 'qalaqah':
      case 'qlq':
        return TajweedRule.qalqalah;
      case 'madd_normal':
      case 'madda_normal':
        return TajweedRule.maddTabeei;
      case 'madda_permissible':
      case 'madd_arid':
      case 'madd_arid_lissukun':
        // Context-free fallback; _parseRuleTagTajweed refines this to
        // maddLin where the preceding vowel is a fatha.
        return TajweedRule.maddAridLissukun;
      case 'madd_lin':
      case 'madd_leen':
        return TajweedRule.maddLin;
      case 'madd_muttasil':
      case 'madd_mottasel':
      case 'madda_obligatory':
      case 'madda_obligatory_mottasel':
      case 'madda_obligatory_muttasil':
      case 'madda_obligatory_muttasel':
        return TajweedRule.maddMuttasil;
      case 'madda_obligatory_monfasel':
      case 'madda_obligatory_monfasil':
      case 'madd_munfasil':
        return TajweedRule.maddMunfasil;
      case 'madda_necessary':
        // Context-free fallback; the parsers refine this into the four
        // Madd Lazim types via _resolveNecessaryMadd.
        return TajweedRule.maddLazimKalimiMuthaqqal;
      case 'idgham_ghunnah':
      case 'idghaam_w_ghunnah':
        return TajweedRule.idghamWithGhunnah;
      case 'idgham_no_ghunnah':
      case 'idgham_wo_ghunnah':
      case 'idghaam_wo_ghunnah':
        return TajweedRule.idghamWithoutGhunnah;
      case 'idgham_shafawi':
        return TajweedRule.idghamShafawi;
      case 'idgham_mutajanisayn':
        return TajweedRule.idghamMutajanisayn;
      case 'ikhfa':
      case 'ikhafa':
        return TajweedRule.ikhfa;
      case 'ikhfa_shafawi':
      case 'ikhafa_shafawi':
        return TajweedRule.ikhfaShafawi;
      case 'iqlab':
        return TajweedRule.iqlab;
      case 'izhar':
      case 'idhaar':
        return TajweedRule.izhar;
      case 'ham_wasl':
        return TajweedRule.hamzatWasl;
      case 'laam_shamsiyah':
        return TajweedRule.laamShamsiyah;
      case 'slnt':
        return TajweedRule.silent;
      case 'sajdah':
      case 'sajdah_sign':
        return TajweedRule.sajdah;
      case 'shaddah':
        return TajweedRule.shaddah;
      case 'waqf':
        return TajweedRule.waqf;
      default:
        return null;
    }
  }

  /// Maps Quran.com translation resource IDs back to language codes.
  static String? _langCodeFromResourceId(dynamic resourceId) {
    final id = resourceId is int ? resourceId : int.tryParse('$resourceId');
    switch (id) {
      case 85:
        return 'en';
      case 16:
        return 'ar';
      case 97:
        return 'ur';
      case 52:
        return 'tr';
      case 31:
        return 'fr';
      case 33:
        return 'id';
      case 27:
        return 'de';
      case 83:
        return 'es';
      default:
        return null;
    }
  }

  static String? _langCodeFromName(dynamic languageName) {
    final name = (languageName as String? ?? '').toLowerCase().trim();
    if (name.isEmpty) return null;
    if (name.contains('arab')) return 'ar';
    if (name.contains('urdu')) return 'ur';
    if (name.contains('turk')) return 'tr';
    if (name.contains('french') || name.contains('fran')) return 'fr';
    if (name.contains('indones')) return 'id';
    if (name.contains('german') || name.contains('deutsch')) return 'de';
    if (name.contains('span')) return 'es';
    if (name.contains('english')) return 'en';
    return null;
  }

  /// Strips HTML tags from translation text.
  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  // ─── Tajweed HTML parsing ───────────────────────────────────────────────

  /// Parses Quran.com `text_uthmani_tajweed` HTML into typed segments.
  /// The API returns text like:
  ///   plain `<tajweed class="ghunnah">colored</tajweed>` more plain
  static List<TajweedSegment> parseTajweedHtml(String html) {
    // Remove end-of-ayah markers: <span class=end>١</span> / <span class="end">١</span>
    final cleaned = html
        .replaceAll(RegExp(r'<span\s+class="?end"?>[^<]*</span>'), '')
        .trim();

    final segments = <TajweedSegment>[];
    final pattern = RegExp(r'<tajweed\s+class="?([\w-]+)"?>(.*?)</tajweed>');
    int cursor = 0;

    for (final match in pattern.allMatches(cleaned)) {
      // Plain text before this tag
      if (cursor < match.start) {
        final plain = _normalizeArabicText(
          _stripHtmlPreserveSpacing(cleaned.substring(cursor, match.start)),
        );
        if (plain.isNotEmpty) {
          segments.add(TajweedSegment(text: plain));
        }
      }

      // Tagged text
      final className = match.group(1)!;
      final text = _normalizeArabicText(
        _stripHtmlPreserveSpacing(match.group(2)!),
      );
      final rule = _ruleFromTajweedClass(className);
      if (text.isNotEmpty) {
        segments.add(TajweedSegment(text: text, rule: rule));
      }

      cursor = match.end;
    }

    // Remaining plain text
    if (cursor < cleaned.length) {
      final remaining = _normalizeArabicText(
        _stripHtmlPreserveSpacing(cleaned.substring(cursor)),
      );
      if (remaining.isNotEmpty) {
        segments.add(TajweedSegment(text: remaining));
      }
    }

    return segments;
  }

  static String _stripHtmlPreserveSpacing(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  // Keep Quran text intact. Only normalize combining-mark order so short
  // vowels are stored before shaddah, which prevents misplaced harakat in
  // some font/rendering stacks while preserving the exact verse text.
  static String _normalizeArabicText(
    String text, {
    bool forceRubElHizb = false,
    bool forceSajdahGlyph = false,
  }) {
    final reordered = text.replaceAllMapped(_shaddaBeforeShortVowelPattern, (
      match,
    ) {
      return '${match.group(1)}\u0651';
    });

    final out = StringBuffer();
    bool previousWasCanonicalMarker = false;
    for (final rune in reordered.runes) {
      if (rune == _rubElHizbRune) {
        out.write(_canonicalMarkerGlyph);
        previousWasCanonicalMarker = true;
        continue;
      }

      if (previousWasCanonicalMarker &&
          ((rune >= 0x06D6 && rune <= 0x06DC) ||
              (rune >= 0x06DF && rune <= 0x06E8) ||
              (rune >= 0x06EA && rune <= 0x06ED))) {
        continue;
      }

      out.write(String.fromCharCode(rune));
      previousWasCanonicalMarker = false;
    }

    var normalized = out.toString();
    if (forceRubElHizb) {
      normalized = normalized
          .replaceAll('\u06E9', _canonicalMarkerGlyph)
          .replaceAll('\u06DD', _canonicalMarkerGlyph);
    }
    if (forceSajdahGlyph) {
      normalized = normalized.replaceAll(_canonicalMarkerGlyph, _sajdahGlyph);
    }
    return normalized;
  }

  static bool _isSajdahAyah(int surah, int ayah) {
    return _sajdahAyahKeys.contains(surah * 1000 + ayah);
  }

  static bool _containsPotentialMarker(String text) {
    for (final rune in text.runes) {
      if (rune == 0x06DD || rune == 0x06DE || rune == 0x06E9) {
        return true;
      }
    }
    return false;
  }

  static String _toCodepoints(String text) {
    return text.runes
        .map((r) => 'U+${r.toRadixString(16).toUpperCase()}')
        .join(' ');
  }

  /// Maps Quran.com tajweed CSS class names to [TajweedRule].
  static TajweedRule? _ruleFromTajweedClass(String className) {
    switch (className) {
      case 'ghunnah':
        return TajweedRule.ghunnah;
      case 'qalqalah':
      case 'qalaqah':
        return TajweedRule.qalqalah;
      case 'madd_normal':
      case 'madda_normal':
        return TajweedRule.maddTabeei;
      case 'madda_permissible':
      case 'madd_arid':
      case 'madd_arid_lissukun':
        // Context-free fallback; _parseRuleTagTajweed refines this to
        // maddLin where the preceding vowel is a fatha.
        return TajweedRule.maddAridLissukun;
      case 'madd_lin':
      case 'madd_leen':
        return TajweedRule.maddLin;
      case 'madd_muttasil':
      case 'madd_mottasel':
      case 'madda_obligatory':
      case 'madda_obligatory_mottasel':
      case 'madda_obligatory_muttasil':
      case 'madda_obligatory_muttasel':
        return TajweedRule.maddMuttasil;
      case 'madda_obligatory_monfasel':
      case 'madda_obligatory_monfasil':
      case 'madd_munfasil':
        return TajweedRule.maddMunfasil;
      case 'madda_necessary':
        // Context-free fallback; the parsers refine this into the four
        // Madd Lazim types via _resolveNecessaryMadd.
        return TajweedRule.maddLazimKalimiMuthaqqal;
      case 'idgham_ghunnah':
      case 'idghaam_w_ghunnah':
        return TajweedRule.idghamWithGhunnah;
      case 'idgham_no_ghunnah':
      case 'idgham_wo_ghunnah':
      case 'idghaam_wo_ghunnah':
        return TajweedRule.idghamWithoutGhunnah;
      case 'idgham_shafawi':
        return TajweedRule.idghamShafawi;
      case 'idgham_mutajanisayn':
        return TajweedRule.idghamMutajanisayn;
      case 'ikhfa':
      case 'ikhafa':
        return TajweedRule.ikhfa;
      case 'ikhfa_shafawi':
      case 'ikhafa_shafawi':
        return TajweedRule.ikhfaShafawi;
      case 'iqlab':
        return TajweedRule.iqlab;
      case 'izhar':
      case 'idhaar':
        return TajweedRule.izhar;
      case 'ham_wasl':
        return TajweedRule.hamzatWasl;
      case 'laam_shamsiyah':
        return TajweedRule.laamShamsiyah;
      case 'slnt':
        return TajweedRule.silent;
      case 'sajdah':
      case 'sajdah_sign':
        return TajweedRule.sajdah;
      case 'shaddah':
        return TajweedRule.shaddah;
      case 'waqf':
        return TajweedRule.waqf;
      default:
        return null;
    }
  }
}
