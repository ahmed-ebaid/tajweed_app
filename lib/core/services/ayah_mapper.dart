import '../models/tajweed_models.dart';
import 'quran_api_service.dart';

/// Maps raw Quran.com API v4 JSON responses into typed [Ayah] models
/// with word-level tajweed annotations.
class AyahMapper {
  static final RegExp _shaddaBeforeShortVowelPattern = RegExp(
    '\u0651([\u064B-\u0650])',
  );

  /// Converts a single verse JSON object from the API into an [Ayah].
  /// Optionally accepts [tajweedHtml] from the uthmani_tajweed endpoint.
  static Ayah fromApi(Map<String, dynamic> json, {String? tajweedHtml}) {
    final verseKey = json['verse_key'] as String? ?? '1:1';
    final parts = verseKey.split(':');
    final surahNumber = int.tryParse(parts[0]) ?? 1;
    final ayahNumber = int.tryParse(parts[1]) ?? 1;
    final pageNumber = json['page_number'] as int? ?? 1;

    // Preserve the source glyphs exactly, but reorder combining marks into
    // canonical form so shaddah + kasrah render correctly across font stacks.
    final arabic = _normalizeArabicText(
      json['text_uthmani'] as String? ?? '',
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
    final words = rawWords
        .where((w) => w['char_type_name'] != 'end')
        .whereType<Map>()
        .map<TajweedWord>((w) => _mapWord(Map<String, dynamic>.from(w)))
        .toList();

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

  static TajweedWord _mapWord(Map<String, dynamic> w) {
    // Keep display text and span positions aligned by deriving both from the
    // same source (`text_uthmani_tajweed`) when available.
    final wordTajweedHtml = w['text_uthmani_tajweed'] as String?;
    final sourceText = (wordTajweedHtml != null && wordTajweedHtml.isNotEmpty)
        ? _stripHtmlPreserveSpacing(wordTajweedHtml)
        : (w['text_uthmani'] as String? ?? '');
    final textForDisplay = _normalizeArabicText(sourceText);
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

    return TajweedWord(arabic: textForDisplay, spans: spans);
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
      final rule = _ruleFromTajweedClass(className) ?? _ruleFromClassName(className);
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
        // consecutive rule characters.
        buf.write('[\u064B-\u0650\u0652\u06D6-\u06ED]*');
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
          (cp >= 0x06D6 && cp <= 0x06ED)) { // Quranic annotation marks
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
      case 'qlq':
        return TajweedRule.qalqalah;
      case 'madd_normal':
      case 'madda_normal':
        return TajweedRule.maddTabeei;
      case 'madd_muttasil':
      case 'madda_obligatory':
      case 'madda_obligatory_monfasel':
      case 'madda_obligatory_muttasel':
        return TajweedRule.maddMuttasil;
      case 'madd_munfasil':
      case 'madda_permissible':
        return TajweedRule.maddMunfasil;
      case 'idgham_ghunnah':
      case 'idghaam_w_ghunnah':
        return TajweedRule.idghamWithGhunnah;
      case 'idgham_no_ghunnah':
      case 'idghaam_wo_ghunnah':
        return TajweedRule.idghamWithoutGhunnah;
      case 'ikhfa':
      case 'ikhfa_shafawi':
        return TajweedRule.ikhfa;
      case 'iqlab':
        return TajweedRule.iqlab;
      case 'izhar':
      case 'idhaar':
        return TajweedRule.izhar;
      case 'shaddah':
        return TajweedRule.shaddah;
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
  ///   plain <tajweed class=ghunnah>colored</tajweed> more plain
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
  static String _normalizeArabicText(String text) {
    return text.replaceAllMapped(_shaddaBeforeShortVowelPattern, (match) {
      return '${match.group(1)}\u0651';
    });
  }

  /// Maps Quran.com tajweed CSS class names to [TajweedRule].
  static TajweedRule? _ruleFromTajweedClass(String className) {
    switch (className) {
      case 'ghunnah':
        return TajweedRule.ghunnah;
      case 'qalaqah':
        return TajweedRule.qalqalah;
      case 'madda_normal':
        return TajweedRule.maddTabeei;
      case 'madda_obligatory':
      case 'madda_obligatory_monfasel':
      case 'madda_obligatory_muttasel':
        return TajweedRule.maddMuttasil;
      case 'madda_permissible':
        return TajweedRule.maddMunfasil;
      case 'madda_necessary':
        return TajweedRule.maddLazim;
      case 'idgham_ghunnah':
        return TajweedRule.idghamWithGhunnah;
      case 'idgham_wo_ghunnah':
        return TajweedRule.idghamWithoutGhunnah;
      case 'idgham_shafawi':
        return TajweedRule.idghamShafawi;
      case 'idgham_mutajanisayn':
        return TajweedRule.idghamMutajanisayn;
      case 'ikhafa':
        return TajweedRule.ikhfa;
      case 'ikhafa_shafawi':
        return TajweedRule.ikhfaShafawi;
      case 'iqlab':
        return TajweedRule.iqlab;
      case 'ham_wasl':
        return TajweedRule.hamzatWasl;
      case 'laam_shamsiyah':
        return TajweedRule.laamShamsiyah;
      case 'slnt':
        return TajweedRule.silent;
      default:
        return null;
    }
  }
}
