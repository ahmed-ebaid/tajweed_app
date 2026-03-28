import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

/// Bottom sheet shown when the quiz is complete.
/// Displays the final score and a restart button.
class QuizResultsSheet extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRestart;

  const QuizResultsSheet({
    super.key,
    required this.score,
    required this.total,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percentage = total > 0 ? (score / total * 100).round() : 0;
    final isGreat = percentage >= 70;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Trophy / result icon
            Icon(
              isGreat
                  ? Icons.emoji_events_rounded
                  : Icons.refresh_rounded,
              size: 48,
              color: isGreat
                  ? const Color(0xFFB8860B)
                  : const Color(0xFF1D9E75),
            ),
            const SizedBox(height: 16),

            // Score text
            Text(
              '$score / $total',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F6E56),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$percentage% ${l10n.get('overall_score')}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isGreat
                  ? 'Excellent! Keep going \u2728'
                  : 'Good effort! Practice makes perfect.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF888780),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Restart button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
