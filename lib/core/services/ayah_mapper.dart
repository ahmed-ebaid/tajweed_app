import '../models/tajweed_models.dart';
import 'quran_api_service.dart';

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
  static Ayah fromApi(Map<String, dynamic> json, {String? tajweedHtml}) {
    final verseKey = json['verse_key'] as String? ?? '1:1';
    final parts = verseKey.split(':');
    final surahNumber = int.tryParse(parts[0]) ?? 1;
    final ayahNumber = int.tryParse(parts[1]) ?? 1;
    final pageNumber = json['page_number'] as int? ?? 1;
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
        final langCode = _langCodeFromResourceId(map['resource_id']);
        final text = _stripHtml(map['text'] as String? ?? '');
        if (langCode != null) {
          translations[langCode] = text;
        }
      }
    }

    // Words with tajweed spans
    final rawWords = json['words'] as List<dynamic>? ?? [];
    final adjustedWords = _applyEndTokenShiftFix(rawWords);
    final hasSajdahInNonEndWord = adjustedWords
        .whereType<Map>()
        .map((w) => Map<String, dynamic>.from(w))
        .where((w) => (w['char_type_name'] as String?) != 'end')
        .any((w) => _containsSajdahInWordDisplaySource(
              w,
              forceRubElHizb: forceRubElHizb,
              forceSajdahGlyph: forceSajdahGlyph,
            ));
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
            final uthmaniText = (mapped['text_uthmani'] as String? ??
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

    if (_debugMarkerAyahs &&
        surahNumber == 2 &&
        (ayahNumber == 142 || ayahNumber == 177)) {
      final markerWords = words
          .where((w) => _containsPotentialMarker(w.arabic))
          .map((w) => '${w.arabic} => ${_toCodepoints(w.arabic)}')
          .join(' | ');
      print(
          '🔎 MARKER DEBUG $surahNumber:$ayahNumber ayah=${_toCodepoints(arabic)} words=$markerWords');
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
      arabic: arabic,
      translations: translations,
      words: words,
      audioUrl: audioUrl,
      tajweedSegments: tajweedSegments,
    );
  }

  /// Converts a list of verse JSON objects into [Ayah] models.
  static List<Ayah> fromApiList(
    List<Map<String, dynamic>> verses, {
    Map<String, String>? tajweedMap,
  }) {
    return verses.map((v) {
      final key = v['verse_key'] as String? ?? '';
      return fromApi(v, tajweedHtml: tajweedMap?[key]);
    }).toList();
  }

  // Quran.com sometimes shifts word-level `text_uthmani_tajweed` into the next
  // token and places the last real word's tajweed on the `end` token.
  // Detect this by checking whether the end-token tajweed differs from its
  // ayah-number glyph text, then realign per token order.
  static List<Map<String, dynamic>> _applyEndTokenShiftFix(
      List<dynamic> rawWords) {
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
    final endText = (endToken['text'] as String? ??
            endToken['text_uthmani'] as String? ??
            '')
        .trim();
    final endTajweed =
        (endToken['text_uthmani_tajweed'] as String? ?? '').trim();

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
      spans.add(TajweedSpan(
          start: sajdahIdx, end: sajdahIdx + 1, rule: TajweedRule.sajdah));
      sajdahIdx = textForDisplay.indexOf(sajdahChar, sajdahIdx + 1);
    }

    return TajweedWord(
        arabic: textForDisplay,
        spans: spans,
        audioUrl: w['audio_url'] as String?);
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

      // Pass 1: exact match
      final exactIdx = arabicText.indexOf(ruleText, searchFrom);
      if (exactIdx >= 0) {
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

      spans.add(TajweedSpan(start: idx, end: endIdx, rule: rule));
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
        (endToken['text_uthmani'] as String? ?? endToken['text'] as String? ??
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
      String arabicText, String ruleText, int searchFrom) {
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
      String arabicText, String tajweedData) {
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
          spans.add(TajweedSpan(
            start: idx,
            end: idx + ruleText.length,
            rule: rule,
          ));
          searchFrom = idx + ruleText.length;
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
      case 'madda_permissible':
        return TajweedRule.maddTabeei;
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
        return TajweedRule.maddLazim;
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
      case 131:
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
      default:
        return 'en';
    }
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
    final reordered =
        text.replaceAllMapped(_shaddaBeforeShortVowelPattern, (match) {
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
      case 'madda_permissible':
        return TajweedRule.maddTabeei;
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
        return TajweedRule.maddLazim;
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
