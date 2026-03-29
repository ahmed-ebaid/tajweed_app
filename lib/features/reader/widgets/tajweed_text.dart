import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/models/tajweed_models.dart';

/// Renders an [Ayah] as RTL Arabic text with tajweed color highlighting.
/// Tapping a colored span calls [onRuleTapped] with the matching [TajweedRule].
class TajweedText extends StatelessWidget {
  final Ayah ayah;
  final double fontSize;
  final double lineHeight;
  final bool compactFlow;
  final bool highlightEnabled;
  final int highlightedWordIndex;
  final void Function(TajweedRule rule, String word)? onRuleTapped;

  const TajweedText({
    super.key,
    required this.ayah,
    this.fontSize = 26,
    this.lineHeight = 2.15,
    this.compactFlow = false,
    this.highlightEnabled = true,
    this.highlightedWordIndex = -1,
    this.onRuleTapped,
  });

  // Slight stroke-like shadow to make thin harakat marks read clearer.
  static List<Shadow> _diacriticShadows(Color color) => [
      Shadow(color: color.withValues(alpha: 0.10), offset: const Offset(0.10, 0)),
      ];

  TextStyle _arabicStyle({
    required Color color,
    double? size,
    FontWeight weight = FontWeight.w600,
    Color? backgroundColor,
  }) {
    return TextStyle(
      color: color,
      fontSize: size ?? fontSize,
      fontWeight: weight,
      height: lineHeight,
      backgroundColor: backgroundColor,
      shadows: _diacriticShadows(color),
      fontFeatures: const [
        FontFeature.enable('mark'),
        FontFeature.enable('mkmk'),
      ],
      fontFamily: 'UthmanicHafs',
      fontFamilyFallback: const [
        'Noto Naskh Arabic',
        'Amiri Quran',
        'Amiri',
        'Geeza Pro',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        textAlign: TextAlign.right,
        softWrap: !compactFlow,
        textWidthBasis:
            compactFlow ? TextWidthBasis.longestLine : TextWidthBasis.parent,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        strutStyle: StrutStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: fontSize,
          height: lineHeight,
          leading: 0.15,
        ),
        text: TextSpan(
          children: _buildSpans(context, baseColor),
        ),
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context, Color baseColor) {
    // Prefer verse-level tajweed segments from the uthmani_tajweed API
    // When syncing playback to words, prefer word rendering so active word
    // can be highlighted.
    if (highlightEnabled && ayah.tajweedSegments.isNotEmpty && highlightedWordIndex < 0) {
      final segmentSpans = _buildSegmentSpans(baseColor);
      segmentSpans.add(_buildAyahEndMarker(baseColor));
      return segmentSpans;
    }

    final spans = <InlineSpan>[];

    for (int wi = 0; wi < ayah.words.length; wi++) {
      final word = ayah.words[wi];
      final isActiveWord = wi == highlightedWordIndex;

      if (!highlightEnabled || word.spans.isEmpty) {
        // No tajweed spans — render entire word in base color
        spans.add(TextSpan(
          text: '${word.arabic} ',
          style: _arabicStyle(
            color: baseColor,
            backgroundColor: isActiveWord
                ? const Color(0xFFFFE08A).withOpacity(0.65)
                : null,
          ),
        ));
      } else {
        // Build per-character colored spans within the word
        spans.addAll(_buildWordSpans(word, baseColor, isActiveWord));
        spans.add(TextSpan(
          text: ' ',
          style: _arabicStyle(
            color: baseColor,
            backgroundColor: isActiveWord
                ? const Color(0xFFFFE08A).withOpacity(0.45)
                : null,
          ),
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

  List<InlineSpan> _buildWordSpans(TajweedWord word, Color baseColor, bool isActiveWord) {
    final result = <InlineSpan>[];
    final text = word.arabic;
    final graphemeMap = _GraphemeMap.fromText(text);
    int cursor = 0;

    // Sort spans by start position
    final sorted = [...word.spans]..sort((a, b) => a.start.compareTo(b.start));

    for (final span in sorted) {
      final start = graphemeMap.startClusterForCodeUnit(span.start);
      final end = graphemeMap.endClusterForCodeUnit(span.end);

      if (end <= start) {
        // Skip malformed span ranges from upstream data.
        continue;
      }

      // Uncolored text before this span
      if (cursor < start) {
        final beforeText = graphemeMap.slice(cursor, start);
        result.addAll(_buildGraphemeTextSpans(
          beforeText,
          _arabicStyle(
            color: baseColor,
            backgroundColor: isActiveWord
                ? const Color(0xFFFFE08A).withOpacity(0.65)
                : null,
          ),
        ));
      }

      // Colored span
      final spanText = graphemeMap.slice(start, end);
      final rule = span.rule;
      final style = _styleFor(rule, baseColor, isActiveWord: isActiveWord);

      if (onRuleTapped != null) {
        result.addAll(
          _buildGraphemeTextSpans(
            spanText,
            style,
            onTap: () => onRuleTapped!(rule, spanText),
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
        _arabicStyle(
          color: baseColor,
          backgroundColor: isActiveWord
              ? const Color(0xFFFFE08A).withOpacity(0.65)
              : null,
        ),
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
    if (onTap != null) {
      return [
        TextSpan(
          text: text,
          style: style,
          recognizer: TapGestureRecognizer()..onTap = onTap,
        ),
      ];
    }
    return [TextSpan(text: text, style: style)];
  }

  List<InlineSpan> _buildSegmentSpans(Color baseColor) {
    return ayah.tajweedSegments.map<InlineSpan>((segment) {
      final rule = segment.rule;
      final color = rule?.color ?? baseColor;
      if (rule != null && onRuleTapped != null) {
        return TextSpan(
          text: segment.text,
          style: _arabicStyle(color: color),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onRuleTapped!(rule, segment.text),
        );
      }
      return TextSpan(
        text: segment.text,
        style: _arabicStyle(color: color),
      );
    }).toList();
  }

  TextStyle _styleFor(TajweedRule rule, Color baseColor, {bool isActiveWord = false}) => _arabicStyle(
        color: highlightEnabled ? rule.color : baseColor,
        backgroundColor: isActiveWord
            ? const Color(0xFFFFE08A).withOpacity(0.65)
            : null,
        // Subtle underline for madd rules to indicate elongation
      ).copyWith(
        decoration: rule == TajweedRule.maddTabeei ||
                rule == TajweedRule.maddMuttasil ||
                rule == TajweedRule.maddMunfasil ||
                rule == TajweedRule.maddLazim
            ? TextDecoration.underline
            : TextDecoration.none,
        decorationColor: rule.color.withOpacity(0.5),
        decorationStyle: TextDecorationStyle.dotted,
      );
}

class _GraphemeMap {
  final List<String> _clusters;
  final List<int> _clusterCodeUnitStarts;

  _GraphemeMap._(this._clusters, this._clusterCodeUnitStarts);

  factory _GraphemeMap.fromText(String text) {
    final clusters = text.characters.toList(growable: false);
    final starts = <int>[0];
    var offset = 0;
    for (final cluster in clusters) {
      offset += cluster.length;
      starts.add(offset);
    }
    return _GraphemeMap._(clusters, starts);
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
