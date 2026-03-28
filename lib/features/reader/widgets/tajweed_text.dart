import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/models/tajweed_models.dart';

/// Renders an [Ayah] as RTL Arabic text with tajweed color highlighting.
/// Tapping a colored span calls [onRuleTapped] with the matching [TajweedRule].
class TajweedText extends StatelessWidget {
  final Ayah ayah;
  final double fontSize;
  final bool highlightEnabled;
  final int highlightedWordIndex;
  final void Function(TajweedRule rule, String word)? onRuleTapped;

  const TajweedText({
    super.key,
    required this.ayah,
    this.fontSize = 26,
    this.highlightEnabled = true,
    this.highlightedWordIndex = -1,
    this.onRuleTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        textAlign: TextAlign.justify,
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
      return _buildSegmentSpans(baseColor);
    }

    final spans = <InlineSpan>[];

    for (int wi = 0; wi < ayah.words.length; wi++) {
      final word = ayah.words[wi];
      final isActiveWord = wi == highlightedWordIndex;

      if (!highlightEnabled || word.spans.isEmpty) {
        // No tajweed spans — render entire word in base color
        spans.add(TextSpan(
          text: '${word.arabic} ',
          style: TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: fontSize,
            color: baseColor,
            height: 2.0,
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
          style: TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: fontSize,
            backgroundColor: isActiveWord
                ? const Color(0xFFFFE08A).withOpacity(0.45)
                : null,
          ),
        ));
      }
    }

    return spans;
  }

  List<InlineSpan> _buildWordSpans(TajweedWord word, Color baseColor, bool isActiveWord) {
    final result = <InlineSpan>[];
    final text = word.arabic;
    int cursor = 0;

    // Sort spans by start position
    final sorted = [...word.spans]..sort((a, b) => a.start.compareTo(b.start));

    for (final span in sorted) {
      final start = span.start.clamp(0, text.length);
      final end = span.end.clamp(0, text.length);

      if (end <= start) {
        // Skip malformed span ranges from upstream data.
        continue;
      }

      // Uncolored text before this span
      if (cursor < start) {
        result.add(_plain(
          text.substring(cursor, start),
          baseColor,
          isActiveWord: isActiveWord,
        ));
      }

      // Colored span
      final spanText = text.substring(start, end);
      final rule = span.rule;

      if (onRuleTapped != null) {
        result.add(TextSpan(
          text: spanText,
          style: _styleFor(rule, baseColor, isActiveWord: isActiveWord),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onRuleTapped!(rule, spanText),
        ));
      } else {
        result.add(TextSpan(
          text: spanText,
          style: _styleFor(rule, baseColor, isActiveWord: isActiveWord),
        ));
      }

      cursor = end;
    }

    // Remaining text after last span
    if (cursor < text.length) {
      result.add(_plain(
        text.substring(cursor),
        baseColor,
        isActiveWord: isActiveWord,
      ));
    }

    return result;
  }

  List<InlineSpan> _buildSegmentSpans(Color baseColor) {
    return ayah.tajweedSegments.map<InlineSpan>((segment) {
      final rule = segment.rule;
      final color = rule?.color ?? baseColor;
      if (rule != null && onRuleTapped != null) {
        return TextSpan(
          text: segment.text,
          style: TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: fontSize,
            color: color,
            height: 2.0,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onRuleTapped!(rule, segment.text),
        );
      }
      return TextSpan(
        text: segment.text,
        style: TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: fontSize,
          color: color,
          height: 2.0,
        ),
      );
    }).toList();
  }

  TextSpan _plain(String text, Color color, {bool isActiveWord = false}) => TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: fontSize,
          color: color,
          height: 2.0,
          backgroundColor: isActiveWord
              ? const Color(0xFFFFE08A).withOpacity(0.65)
              : null,
        ),
      );

  TextStyle _styleFor(TajweedRule rule, Color baseColor, {bool isActiveWord = false}) => TextStyle(
        fontFamily: 'UthmanicHafs',
        fontSize: fontSize,
        color: highlightEnabled ? rule.color : baseColor,
        height: 2.0,
        backgroundColor: isActiveWord
            ? const Color(0xFFFFE08A).withOpacity(0.65)
            : null,
        // Subtle underline for madd rules to indicate elongation
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
