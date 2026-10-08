import 'package:flutter/material.dart';

import '../../../core/constants/arabic_shaping.dart';
import '../../../core/models/tajweed_models.dart';
import '../rule_example_highlight.dart';
import '../waqf_symbols.dart';

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
    this.fontFamily = 'AmiriQuran',
    this.fontWeight = FontWeight.normal,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = rule.color;
    var displayText = text;
    if (rule == TajweedRule.waqf) {
      for (final symbol in WaqfSymbols.examples) {
        if (symbol.quranSymbol == text) {
          displayText = symbol.displaySymbol;
          break;
        }
      }
    }
    final range = RuleExampleHighlight.rangeIn(rule, displayText, exampleIndex);
    final base =
        baseColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);

    final style = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.8,
      fontFeatures: arabicShapingFeatures,
    );

    if (range == null) {
      return Text(
        displayText,
        style: style.copyWith(color: highlight),
        textDirection: TextDirection.rtl,
        textHeightBehavior: const TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          if (range.start > 0)
            TextSpan(
              text: displayText.substring(0, range.start),
              style: style.copyWith(color: base),
            ),
          TextSpan(
            text: displayText.substring(range.start, range.end),
            // Colour is the only thing that may change mid-word: a different
            // weight would start a new shaping run and split the ligatures,
            // rendering the letters in isolated forms.
            style: style.copyWith(color: highlight),
          ),
          if (range.end < displayText.length)
            TextSpan(
              text: displayText.substring(range.end),
              style: style.copyWith(color: base),
            ),
        ],
      ),
      textDirection: TextDirection.rtl,
      textHeightBehavior: const TextHeightBehavior(
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}
