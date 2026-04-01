import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/tajweed_models.dart';
import '../../../core/providers/locale_provider.dart';
import '../../rules/rules_repository.dart';
import 'tajweed_text.dart';

class WordDetailSheet extends StatefulWidget {
  final TajweedRule rule;
  final String word;
  final Ayah? ayah;
  final String? wordAudioUrl;
  final String? ayahAudioUrl;

  const WordDetailSheet({
    super.key,
    required this.rule,
    required this.word,
    this.ayah,
    this.wordAudioUrl,
    this.ayahAudioUrl,
  });

  @override
  State<WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<WordDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final definition = RulesRepository.findByRule(widget.rule);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(
              child: Text(
                widget.word,
                style: TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 36,
                  color: widget.rule.color,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.rule.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  definition?.name(langCode) ?? widget.rule.arabicName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  widget.rule.arabicName,
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
            if (widget.ayah != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.rule.color.withValues(alpha: 0.24),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ayah ${widget.ayah!.surahNumber}:${widget.ayah!.ayahNumber}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    TajweedText(
                      ayah: widget.ayah!,
                      fontSize: 28,
                      lineHeight: 2.0,
                      focusedRule: widget.rule,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (definition != null)
              Text(
                definition.description(langCode),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            if (definition != null && definition.exampleArabic.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.get('examples'), style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: definition.exampleArabic
                    .map(
                      (ex) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.rule.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.rule.color.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          ex,
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 20,
                            color: widget.rule.color,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(widget.rule),
                icon: const Icon(Icons.library_books_outlined, size: 18),
                label: Text(l10n.get('full_details_in_rules_library')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.rule.color,
                  side: BorderSide(color: widget.rule.color.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
