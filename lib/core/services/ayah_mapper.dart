import '../models/tajweed_models.dart';
import 'quran_api_service.dart';

/// Maps raw Quran.com API v4 JSON responses into typed [Ayah] models
/// with word-level tajweed annotations.
class AyahMapper {
  /// Converts a single verse JSON object from the API into an [Ayah].
  /// Optionally accepts [tajweedHtml] from the uthmani_tajweed endpoint.
  static Ayah fromApi(Map<String, dynamic> json, {String? tajweedHtml}) {
    final verseKey = json['verse_key'] as String? ?? '1:1';
    final parts = verseKey.split(':');
    final surahNumber = int.tryParse(parts[0]) ?? 1;
    final ayahNumber = int.tryParse(parts[1]) ?? 1;
    final pageNumber = json['page_number'] as int? ?? 1;

    // Full Arabic text as provided by Quran source.
    final arabic = _normalizeAlefMaddGlyphForms(
      json['text_uthmani'] as String? ?? '',
    );

    // Translations — API may return as a list of translation objects
    final translations = <String, String>{};
    final rawTranslations = json['translations'] as List<dynamic>? ?? [];
    for (final t in rawTranslations) {
      if (t is Map<String, dynamic>) {
        final langCode = _langCodeFromResourceId(t['resource_id']);
        final text = _stripHtml(t['text'] as String? ?? '');
        if (langCode != null) {
          translations[langCode] = text;
        }
      }
    }

    // Words with tajweed spans
    final rawWords = json['words'] as List<dynamic>? ?? [];
    final words = rawWords
        .where((w) => w['char_type_name'] != 'end')
        .map<TajweedWord>((w) => _mapWord(w as Map<String, dynamic>))
        .toList();

    // Audio URL
    final audio = json['audio'] as Map<String, dynamic>?;
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
    final textForDisplay = _normalizeAlefMaddGlyphForms(
      w['text_uthmani'] as String? ?? '',
    );
    final spans = <TajweedSpan>[];

    // The API tajweed field can be a string of codes or HTML-style tags.
    // Parse character-level codes if present.
    final tajweedRaw = w['tajweed'];
    if (tajweedRaw is String && tajweedRaw.isNotEmpty) {
      spans.addAll(_parseTajweedCodes(textForDisplay, tajweedRaw));
    }

    return TajweedWord(arabic: textForDisplay, spans: spans);
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
      final ruleText = _normalizeAlefMaddGlyphForms(match.group(2) ?? '');
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
        final plain = _normalizeAlefMaddGlyphForms(
          _stripHtmlPreserveSpacing(cleaned.substring(cursor, match.start)),
        );
        if (plain.isNotEmpty) {
          segments.add(TajweedSegment(text: plain));
        }
      }

      // Tagged text
      final className = match.group(1)!;
      final text = _normalizeAlefMaddGlyphForms(
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
      final remaining = _normalizeAlefMaddGlyphForms(
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

    // Keep Quran text intact; only normalize specific alef glyph variants that
    // render as hamza-like forms in some stacks where madd should appear.
    static String _normalizeAlefMaddGlyphForms(String text) {
    return text
      .replaceAll('ٲ', 'ٰ')
      .replaceAll('ٳ', 'ٰ')
      .replaceAll('ٵ', 'ٰ');
  }

  /// Maps Quran.com tajweed CSS class names to [TajweedRule].
  static TajweedRule? _ruleFromTajweedClass(String className) {
    switch (className) {
      case 'ghunnah':             return TajweedRule.ghunnah;
      case 'qalaqah':             return TajweedRule.qalqalah;
      case 'madda_normal':        return TajweedRule.maddTabeei;
      case 'madda_obligatory':    return TajweedRule.maddMuttasil;
      case 'madda_permissible':   return TajweedRule.maddMunfasil;
      case 'madda_necessary':     return TajweedRule.maddLazim;
      case 'idgham_ghunnah':      return TajweedRule.idghamWithGhunnah;
      case 'idgham_wo_ghunnah':   return TajweedRule.idghamWithoutGhunnah;
      case 'idgham_shafawi':      return TajweedRule.idghamShafawi;
      case 'idgham_mutajanisayn': return TajweedRule.idghamMutajanisayn;
      case 'ikhafa':              return TajweedRule.ikhfa;
      case 'ikhafa_shafawi':      return TajweedRule.ikhfaShafawi;
      case 'iqlab':               return TajweedRule.iqlab;
      case 'ham_wasl':            return TajweedRule.hamzatWasl;
      case 'laam_shamsiyah':      return TajweedRule.laamShamsiyah;
      case 'slnt':                return TajweedRule.silent;
      default:                    return null;
    }
  }
}
