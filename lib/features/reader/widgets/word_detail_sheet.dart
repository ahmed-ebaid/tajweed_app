import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/tajweed_models.dart';
import '../../../core/providers/locale_provider.dart';
import '../../rules/rules_repository.dart';
import 'package:provider/provider.dart';

class WordDetailSheet extends StatelessWidget {
  final TajweedRule rule;
  final String word;

  const WordDetailSheet({super.key, required this.rule, required this.word});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final definition = RulesRepository.findByRule(rule);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tapped word in Arabic
            Center(
              child: Text(
                word,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 36,
                  color: rule.color,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 16),

            // Rule name row
            Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: rule.color, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  definition?.name(langCode) ?? rule.arabicName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  rule.arabicName,
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            if (definition != null)
              Text(
                definition.description(langCode),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),

            // Examples
            if (definition != null && definition.exampleArabic.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Examples',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: definition.exampleArabic.map((ex) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: rule.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rule.color.withOpacity(0.3), width: 0.5),
                  ),
                  child: Text(
                    ex,
                    style: TextStyle(
                      fontFamily: 'UthmanicHafs',
                      fontSize: 20,
                      color: rule.color,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 16),
            // Hear pronunciation button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {}, // wire to AudioService
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label: Text(l10n.hearPronunciation),
                style: OutlinedButton.styleFrom(
                  foregroundColor: rule.color,
                  side: BorderSide(color: rule.color, width: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
