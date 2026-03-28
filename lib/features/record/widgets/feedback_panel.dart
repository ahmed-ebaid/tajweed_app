import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/tajweed_models.dart';

/// Displays per-rule score bars from a [RecitationFeedback].
/// Each tajweed rule gets a colored progress bar with its Arabic label
/// and a percentage score.
class FeedbackPanel extends StatelessWidget {
  final RecitationFeedback feedback;
  final String title;

  const FeedbackPanel({
    super.key,
    required this.feedback,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title,
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
          ],

          // Overall score header
          _OverallScore(score: feedback.overallScore),
          const SizedBox(height: 16),

          // Per-rule breakdown
          ...feedback.ruleScores.entries.map((entry) {
            final rule = entry.key;
            final score = entry.value;
            return _RuleScoreBar(rule: rule, score: score);
          }),

          // Timestamp
          const SizedBox(height: 12),
          Text(
            _formatTimestamp(feedback.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}

class _OverallScore extends StatelessWidget {
  final int score;
  const _OverallScore({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? const Color(0xFF1D9E75)
        : score >= 50
            ? const Color(0xFFB8860B)
            : const Color(0xFFA32D2D);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$score',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text('/ 100',
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _RuleScoreBar extends StatelessWidget {
  final TajweedRule rule;
  final double score;

  const _RuleScoreBar({required this.rule, required this.score});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Rule label (Arabic name)
          SizedBox(
            width: 100,
            child: Text(
              rule.arabicName,
              style: GoogleFonts.amiri(fontSize: 13),
              textDirection: TextDirection.rtl,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: score.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surface,
                valueColor: AlwaysStoppedAnimation(rule.color),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Percentage
          SizedBox(
            width: 36,
            child: Text(
              '${(score * 100).round()}%',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
