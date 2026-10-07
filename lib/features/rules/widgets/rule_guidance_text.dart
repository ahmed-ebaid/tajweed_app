import 'package:flutter/material.dart';

import '../../../core/constants/arabic_shaping.dart';
import '../../../core/models/tajweed_models.dart';

class RuleGuidanceText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const RuleGuidanceText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final matches = RegExp(r'\(([۟ۡ])\)').allMatches(text);
    if (matches.isEmpty) return Text(text, style: style);

    final spans = <TextSpan>[];
    var offset = 0;
    for (final match in matches) {
      spans.add(TextSpan(text: text.substring(offset, match.start + 1)));
      spans.add(
        TextSpan(
          // Combining marks need a carrier and a font with Quranic glyphs.
          text: match.group(1) == '۟' ? 'و۟' : 'بۡ',
          style: TextStyle(
            fontFamily: 'AmiriQuran',
            fontWeight: FontWeight.normal,
            fontFeatures: arabicShapingFeatures,
            color: match.group(1) == '۟' ? TajweedRule.silent.color : null,
          ),
        ),
      );
      offset = match.end - 1;
    }
    spans.add(TextSpan(text: text.substring(offset)));
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      semanticsLabel: text,
    );
  }
}
