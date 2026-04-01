import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/tajweed_models.dart';

/// Renders an [Ayah] as RTL Arabic text with tajweed color highlighting.
/// Tapping a colored span calls [onRuleTapped] with the matching [TajweedRule].
class TajweedText extends StatelessWidget {
  static final RegExp _shaddaBeforeShortVowelPattern = RegExp(
    '\u0651([\u064B-\u0650])',
  );
  static const String _sajdahGlyph = '\u06E9';
  static const String _rubElHizbGlyph = '\u06DE';
  static const String _endOfAyahGlyph = '\u06DD';
  static const String _canonicalMarkerGlyph = _rubElHizbGlyph;
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

  final Ayah ayah;
  final double fontSize;
  final double lineHeight;
  final bool compactFlow;
  final bool highlightEnabled;
  final int highlightedWordIndex;
  final TajweedRule? focusedRule;
  final bool strictFocusedRuleOnly;
  final Set<TajweedRule> suppressedRules;
  final void Function(TajweedRule rule, String word, String? wordAudioUrl)? onRuleTapped;

  const TajweedText({
    super.key,
    required this.ayah,
    this.fontSize = 26,
    this.lineHeight = 2.3,
    this.compactFlow = false,
    this.highlightEnabled = true,
    this.highlightedWordIndex = -1,
    this.focusedRule,
    this.strictFocusedRuleOnly = false,
    this.suppressedRules = const {},
    this.onRuleTapped,
  });

  // Slight stroke-like shadow to make thin harakat marks read clearer.
  static List<Shadow> _diacriticShadows(Color color) => [
        Shadow(
            color: color.withValues(alpha: 0.10),
            offset: const Offset(0.10, 0)),
      ];

  TextStyle _arabicStyle({
    required Color color,
    double? size,
    FontWeight weight = FontWeight.w600,
    Color? backgroundColor,
  }) {
    final base = TextStyle(
      color: color,
      fontSize: size ?? fontSize,
      fontWeight: weight,
      height: lineHeight,
      backgroundColor: backgroundColor,
      shadows: _diacriticShadows(color),
      fontFeatures: const [
        FontFeature.enable('ccmp'),
        FontFeature.enable('mark'),
        FontFeature.enable('mkmk'),
        FontFeature.enable('rlig'),
        FontFeature.enable('liga'),
        FontFeature.enable('calt'),
      ],
      fontFamilyFallback: const [
        'Amiri Quran',
        'Amiri',
        'Noto Naskh Arabic',
        'Geeza Pro',
      ],
    );

    // Force a Quran-capable Arabic font to stabilize mark positioning
    // (e.g. kasra with shadda in words like "رَبِّ").
    return GoogleFonts.amiriQuran(textStyle: base);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final verticalInset = compactFlow ? 3.0 : 4.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalInset),
        child: RichText(
          textAlign: TextAlign.right,
          softWrap: !compactFlow,
          textWidthBasis: compactFlow
              ? TextWidthBasis.longestLine
              : TextWidthBasis.parent,
          textHeightBehavior: TextHeightBehavior(
            // Keep first-line ascent on native font metrics; this avoids
            // clipping high Quranic marks in ayah-by-ayah mode.
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          strutStyle: compactFlow
              ? StrutStyle(
                  fontSize: fontSize,
                  height: lineHeight,
                  leading: 0.34,
                )
              : null,
          text: TextSpan(
            children: _buildSpans(context, baseColor),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context, Color baseColor) {
    // Preserve canonical Quran word glyphs whenever words are available.
    // Verse-level tajweed HTML can contain alternate glyph forms; only use it
    // as a last resort when upstream/cached word data is missing entirely.
    if (highlightEnabled && ayah.words.isEmpty && ayah.tajweedSegments.isNotEmpty) {
      final segmentSpans = _buildSegmentSpans(baseColor);
      segmentSpans.add(_buildAyahEndMarker(baseColor));
      return segmentSpans;
    }

    // Last-resort fallback: render full ayah text so we never show only
    // the end marker when upstream/cached word data is missing.
    if (ayah.words.isEmpty && ayah.tajweedSegments.isEmpty) {
      return [
        TextSpan(
          text: '${_normalizeArabicText(ayah.arabic)} ',
          style: _arabicStyle(color: baseColor),
        ),
        _buildAyahEndMarker(baseColor),
      ];
    }

    final spans = <InlineSpan>[];

    for (int wi = 0; wi < ayah.words.length; wi++) {
      final word = ayah.words[wi];
      final isActiveWord = wi == highlightedWordIndex;
      if (!highlightEnabled || word.spans.isEmpty) {
        // No tajweed spans — still route through grapheme renderer so
        // Quran markers always receive marker-specific glyph styling.
        spans.addAll(
          _buildGraphemeTextSpans(
            _normalizeForCurrentAyah(word.arabic),
            _baseWordStyle(baseColor, isActiveWord: isActiveWord),
          ),
        );
      } else {
        // Build per-character colored spans within the word
        spans.addAll(_buildWordSpans(word, baseColor, isActiveWord));
      }

      if (wi < ayah.words.length - 1) {
        spans.add(TextSpan(
          text: ' ',
          style: _baseSeparatorStyle(baseColor, isActiveWord: isActiveWord),
        ));
      }
    }

    spans.add(_buildAyahEndMarker(baseColor));
    return spans;
  }

  InlineSpan _buildAyahEndMarker(Color baseColor) {
    final arabicAyahNumber = _toArabicDigits(ayah.ayahNumber);
    return TextSpan(
      // NBSP keeps marker attached to the previous word so it appears
      // immediately after the ayah in normal line flow.
      text: '\u00A0﴿$arabicAyahNumber﴾',
      style: _arabicStyle(
        color: const Color(0xFF8B6B2A),
        size: fontSize - 2,
        weight: FontWeight.w700,
      ).copyWith(
        shadows: [
          Shadow(
            color: baseColor.withValues(alpha: 0.14),
            offset: const Offset(0.2, 0.2),
            blurRadius: 1,
          ),
        ],
      ),
    );
  }

  static String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .characters
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }

  List<InlineSpan> _buildWordSpans(
      TajweedWord word, Color baseColor, bool isActiveWord) {
    final result = <InlineSpan>[];
    final text = _normalizeForCurrentAyah(word.arabic);
    final graphemeMap = _GraphemeMap.fromText(text);
    int cursor = 0;

    // Sort spans by start position
    final sorted = [...word.spans]..sort((a, b) => a.start.compareTo(b.start));

    for (final span in sorted) {
      final start = graphemeMap.startClusterForCodeUnit(span.start);
      final end = graphemeMap.endClusterForCodeUnit(span.end);

      if (end <= start || start < cursor) {
        // Skip malformed spans and spans that collapse onto a grapheme
        // cluster already rendered by an earlier tajweed segment.
        continue;
      }

      // Uncolored text before this span
      if (cursor < start) {
        final beforeText = graphemeMap.slice(cursor, start);
        result.addAll(_buildGraphemeTextSpans(
          beforeText,
          _baseWordStyle(baseColor, isActiveWord: isActiveWord),
        ));
      }

      // Colored span
      final spanText = graphemeMap.slice(start, end);
      final rule = span.rule;
      if (suppressedRules.contains(rule)) {
        result.addAll(_buildGraphemeTextSpans(
          spanText,
          _baseWordStyle(baseColor, isActiveWord: isActiveWord),
        ));
        cursor = end;
        continue;
      }
      final style = _styleFor(rule, baseColor, isActiveWord: isActiveWord);

      if (onRuleTapped != null) {
        result.addAll(
          _buildGraphemeTextSpans(
            spanText,
            style,
            onTap: () => onRuleTapped!(rule, _normalizeArabicText(word.arabic), word.audioUrl),
          ),
        );
      } else {
        result.addAll(_buildGraphemeTextSpans(spanText, style));
      }

      cursor = end;
    }

    // Remaining text after last span
    if (cursor < graphemeMap.length) {
      final remaining = graphemeMap.slice(cursor, graphemeMap.length);
      result.addAll(_buildGraphemeTextSpans(
        remaining,
        _baseWordStyle(baseColor, isActiveWord: isActiveWord),
      ));
    }

    return result;
  }

  List<InlineSpan> _buildGraphemeTextSpans(
    String text,
    TextStyle style, {
    VoidCallback? onTap,
  }) {
    // Keep each Arabic segment contiguous so glyph shaping remains stable.
    final normalizedText = _normalizeForCurrentAyah(text);

    if (!_containsQuranMarker(normalizedText)) {
      if (onTap != null) {
        return [
          TextSpan(
            text: normalizedText,
            style: style,
            recognizer: TapGestureRecognizer()..onTap = onTap,
          ),
        ];
      }
      return [TextSpan(text: normalizedText, style: style)];
    }

    final spans = <InlineSpan>[];
    for (final cluster in normalizedText.characters) {
      final isQuranMarker = _isQuranMarkerCluster(cluster);
      final isSajdahMarker = cluster.contains(_sajdahGlyph);
      final markerText = isSajdahMarker ? _sajdahGlyph : cluster;
      spans.add(
        TextSpan(
          text: markerText,
          style: isQuranMarker
              ? _quranMarkerStyleFrom(style, isSajdah: isSajdahMarker)
              : style,
          recognizer: onTap != null
              ? (TapGestureRecognizer()..onTap = onTap)
              : null,
        ),
      );
    }
    return spans;
  }

  static bool _containsQuranMarker(String text) {
    if (text.contains(_sajdahGlyph) || text.contains(_endOfAyahGlyph)) {
      return true;
    }
    for (final rune in text.runes) {
      if (rune == _rubElHizbRune) {
        return true;
      }
    }
    return false;
  }

  static bool _isQuranMarkerCluster(String cluster) {
    if (cluster.contains(_sajdahGlyph) || cluster.contains(_endOfAyahGlyph)) {
      return true;
    }
    for (final rune in cluster.runes) {
      if (rune == _rubElHizbRune) {
        return true;
      }
    }
    return false;
  }

  static bool _isRubElHizbCluster(String cluster) {
    for (final rune in cluster.runes) {
      if (rune == _rubElHizbRune) {
        return true;
      }
    }
    return false;
  }

  List<InlineSpan> _buildSegmentSpans(Color baseColor) {
    final spans = <InlineSpan>[];
    for (final segment in ayah.tajweedSegments) {
      final rule = segment.rule;
      final text = _normalizeForCurrentAyah(segment.text);
      if (rule != null && suppressedRules.contains(rule)) {
        spans.addAll(_buildGraphemeTextSpans(text, _baseWordStyle(baseColor)));
        continue;
      }
      final style = rule == null
          ? _baseWordStyle(baseColor)
          : _styleFor(rule, baseColor);
      if (rule != null && onRuleTapped != null) {
        spans.addAll(
          _buildGraphemeTextSpans(
            text,
            style,
            onTap: () => onRuleTapped!(rule, text, null),
          ),
        );
        continue;
      }
      spans.addAll(_buildGraphemeTextSpans(text, style));
    }
    return spans;
  }

  TextStyle _baseWordStyle(Color baseColor, {bool isActiveWord = false}) =>
      _arabicStyle(
        color: baseColor,
        backgroundColor:
            isActiveWord ? const Color(0xFFFFE08A).withValues(alpha: 0.65) : null,
      );

  TextStyle _baseSeparatorStyle(Color baseColor, {bool isActiveWord = false}) =>
      _arabicStyle(
        color: baseColor,
        backgroundColor:
            isActiveWord ? const Color(0xFFFFE08A).withValues(alpha: 0.45) : null,
      );

  TextStyle _quranMarkerStyleFrom(
    TextStyle style, {
    required bool isSajdah,
  }) {
    // Keep marker glyphs on a dedicated font path instead of sharing the
    // body-text font. This reduces iOS fallback differences for U+06DE.
    final markerBase = style.copyWith(
      fontFamily: isSajdah ? 'Noto Naskh Arabic' : 'Scheherazade New',
      fontFamilyFallback: isSajdah
          ? const [
              'Noto Naskh Arabic',
              'Geeza Pro',
              'Amiri Quran',
              'Amiri',
            ]
          : const [
              'Scheherazade New',
              'Amiri Quran',
              'Noto Naskh Arabic',
              'Geeza Pro',
              'Amiri',
            ],
    );
    return isSajdah
        ? GoogleFonts.notoNaskhArabic(textStyle: markerBase)
        : GoogleFonts.scheherazadeNew(textStyle: markerBase);
  }

  TextStyle _styleFor(TajweedRule rule, Color baseColor,
          {bool isActiveWord = false}) {
    return _arabicStyle(
        color: _resolvedRuleColor(rule, baseColor),
        backgroundColor:
            isActiveWord ? const Color(0xFFFFE08A).withValues(alpha: 0.65) : null,
      );
  }

  Color _resolvedRuleColor(TajweedRule rule, Color baseColor) {
    if (!highlightEnabled) return baseColor;
    if (focusedRule == null || focusedRule == rule) return rule.color;
    if (strictFocusedRuleOnly) return baseColor;
    return Color.lerp(rule.color, baseColor, 0.68) ?? baseColor;
  }

  static String _normalizeArabicText(String text) {
    final reordered = text.replaceAllMapped(_shaddaBeforeShortVowelPattern, (match) {
      return '${match.group(1)}\u0651';
    });

    // Normalize marker variants so ayah view always renders one consistent glyph.
    return _canonicalizeQuranMarkers(reordered);
  }

  String _normalizeForCurrentAyah(String text) {
    var normalized = _normalizeArabicText(text);
    final ayahKey = ayah.surahNumber * 1000 + ayah.ayahNumber;
    if (_sajdahAyahKeys.contains(ayahKey)) {
      normalized = normalized.replaceAll(_canonicalMarkerGlyph, _sajdahGlyph);
    }
    return normalized;
  }

  static String _canonicalizeQuranMarkers(String text) {
    final out = StringBuffer();
    bool previousWasCanonicalMarker = false;

    for (final rune in text.runes) {
      if (rune == _rubElHizbRune) {
        out.write(_canonicalMarkerGlyph);
        previousWasCanonicalMarker = true;
        continue;
      }

      // Drop decorative Quranic combining marks that may follow the marker,
      // otherwise the same marker can still appear visually different.
      if (previousWasCanonicalMarker &&
          ((rune >= 0x06D6 && rune <= 0x06DC) ||
              (rune >= 0x06DF && rune <= 0x06E8) ||
              (rune >= 0x06EA && rune <= 0x06ED))) {
        continue;
      }

      out.write(String.fromCharCode(rune));
      previousWasCanonicalMarker = false;
    }

    return out.toString();
  }
}

class _GraphemeMap {
  final List<String> _clusters;
  final List<int> _clusterCodeUnitStarts;

  _GraphemeMap._(this._clusters, this._clusterCodeUnitStarts);

  factory _GraphemeMap.fromText(String text) {
    final rawClusters = text.characters.toList(growable: false);
    final clusters = <String>[];
    for (final cluster in rawClusters) {
      if (_isStandaloneArabicMarkCluster(cluster) && clusters.isNotEmpty) {
        clusters[clusters.length - 1] = '${clusters.last}$cluster';
        continue;
      }
      clusters.add(cluster);
    }
    final starts = <int>[0];
    var offset = 0;
    for (final cluster in clusters) {
      offset += cluster.length;
      starts.add(offset);
    }
    return _GraphemeMap._(clusters, starts);
  }

  static bool _isStandaloneArabicMarkCluster(String cluster) {
    if (cluster.isEmpty) return false;
    for (final rune in cluster.runes) {
      if (!_isArabicCombiningOrQuranicMark(rune)) {
        return false;
      }
    }
    return true;
  }

  static bool _isArabicCombiningOrQuranicMark(int codePoint) {
    return (codePoint >= 0x0610 && codePoint <= 0x061A) ||
        (codePoint >= 0x064B && codePoint <= 0x065F) ||
        codePoint == 0x0670 ||
        // Keep major Quran markers standalone so they can receive
        // dedicated marker font styling in ayah view.
        (codePoint >= 0x06D6 && codePoint <= 0x06DC) ||
        (codePoint >= 0x06DF && codePoint <= 0x06E8) ||
        (codePoint >= 0x06EA && codePoint <= 0x06ED) ||
        (codePoint >= 0x08D3 && codePoint <= 0x08E1) ||
        (codePoint >= 0x08E3 && codePoint <= 0x08FF);
  }

  int get length => _clusters.length;

  String slice(int startCluster, int endCluster) {
    final start = startCluster.clamp(0, length);
    final end = endCluster.clamp(start, length);
    return _clusters.sublist(start, end).join();
  }

  int startClusterForCodeUnit(int codeUnitOffset) {
    if (_clusters.isEmpty) return 0;
    final clamped = codeUnitOffset.clamp(0, _clusterCodeUnitStarts.last);
    for (int i = 0; i < _clusters.length; i++) {
      if (clamped < _clusterCodeUnitStarts[i + 1]) {
        return i;
      }
    }
    return _clusters.length;
  }

  int endClusterForCodeUnit(int codeUnitOffset) {
    if (_clusters.isEmpty) return 0;
    final clamped = codeUnitOffset.clamp(0, _clusterCodeUnitStarts.last);
    for (int i = 0; i <= _clusters.length; i++) {
      if (_clusterCodeUnitStarts[i] >= clamped) {
        return i;
      }
    }
    return _clusters.length;
  }
}

// ─── Tajweed Legend ───────────────────────────────────────────────────────────

/// A horizontal scrollable row of colored dots with rule names.
class TajweedLegend extends StatelessWidget {
  final List<TajweedRule> rules;
  final String langCode;

  const TajweedLegend({
    super.key,
    required this.rules,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: rules.map((rule) => _LegendItem(rule: rule)).toList(),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final TajweedRule rule;
  const _LegendItem({required this.rule});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: rule.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            rule.arabicName,
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
