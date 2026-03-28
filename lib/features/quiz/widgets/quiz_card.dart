import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Displays the Arabic text of a quiz question along with the question prompt.
class QuizCard extends StatelessWidget {
  final String arabic;
  final String question;

  const QuizCard({
    super.key,
    required this.arabic,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            arabic,
            style: GoogleFonts.amiri(
              fontSize: 36,
              height: 1.8,
            ),
            textDirection: TextDirection.rtl,
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
}
