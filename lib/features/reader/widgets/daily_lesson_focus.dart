import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/tajweed_models.dart';
import '../../../core/providers/daily_lesson_provider.dart';
import '../../rules/rules_repository.dart';

class DailyLessonFocus extends StatelessWidget {
  final DailyLesson lesson;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const DailyLessonFocus({
    super.key,
    required this.lesson,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final definition = RulesRepository.findByRule(lesson.rule);
    return Card(
      key: const Key('daily_lesson_focus'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lesson.titleFor(l10n.locale.languageCode),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const Key('dismiss_daily_lesson'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                ),
              ],
            ),
            Text(l10n.get('lesson_focus_hint')),
            if (definition != null)
              Text(
                definition.description(l10n.locale.languageCode),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            TextButton(
              key: const Key('open_daily_lesson_rule'),
              onPressed: onOpen,
              child: Text(
                definition?.name(l10n.locale.languageCode) ??
                    lesson.rule.arabicName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
