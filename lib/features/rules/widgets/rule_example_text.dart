import 'package:flutter/material.dart';

import '../../../core/models/tajweed_models.dart';
import '../rule_example_highlight.dart';

/// Renders a rule's example word with the rule colour applied **only** to the
/// letters the rule actually governs; the rest of the word stays neutral.
///
/// This mirrors the mushaf renderer, where a span never spills onto
/// neighbouring letters. When the fragment cannot be located the whole word is
/// tinted, preserving the previous behaviour.
class RuleExampleText extends StatelessWidget {
  final TajweedRule rule;
  final String text;
  final int exampleIndex;
  final double fontSize;
  final String fontFamily;
  final FontWeight fontWeight;
  final Color? baseColor;

  const RuleExampleText({
    super.key,
    required this.rule,
    required this.text,
    required this.exampleIndex,
    required this.fontSize,
    this.fontFamily = 'UthmanicHafs',
    this.fontWeight = FontWeight.normal,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = rule.color;
    final range = RuleExampleHighlight.rangeIn(rule, text, exampleIndex);
    final base =
        baseColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    final style = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.5,
    );

    if (range == null) {
      return Text(
        text,
        style: style.copyWith(color: highlight),
        textDirection: TextDirection.rtl,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          if (range.start > 0)
            TextSpan(
              text: text.substring(0, range.start),
              style: style.copyWith(color: base),
            ),
          TextSpan(
            text: text.substring(range.start, range.end),
            style: style.copyWith(
              color: highlight,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (range.end < text.length)
            TextSpan(
              text: text.substring(range.end),
              style: style.copyWith(color: base),
            ),
        ],
      ),
      textDirection: TextDirection.rtl,
    );
  }
}
