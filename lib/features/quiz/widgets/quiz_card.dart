import 'package:flutter/material.dart';

import '../../../core/models/tajweed_models.dart';

/// Displays the Arabic text of a quiz question along with the question prompt.
class QuizCard extends StatelessWidget {
  final String arabic;
  final String question;
  final List<QuizHighlightRange> highlightRanges;
  final Color highlightColor;

  const QuizCard({
    super.key,
    required this.arabic,
    required this.question,
    required this.highlightRanges,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(children: _buildTextSpans()),
            style: const TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 36,
              height: 1.8,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            question,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildTextSpans() {
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final range in highlightRanges) {
      assert(range.start >= cursor && range.end <= arabic.length);
      if (cursor < range.start) {
        spans.add(TextSpan(text: arabic.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: arabic.substring(range.start, range.end),
          style: TextStyle(
            color: highlightColor,
            backgroundColor: highlightColor.withValues(alpha: 0.12),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = range.end;
    }

    if (cursor < arabic.length) {
      spans.add(TextSpan(text: arabic.substring(cursor)));
    }
    return spans;
  }
}
