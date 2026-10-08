import 'package:flutter/material.dart';
import '../../../shared/utils/share_text.dart';

class RuleGuidanceText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const RuleGuidanceText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(ShareText.guidance(text), style: style);
  }
}
