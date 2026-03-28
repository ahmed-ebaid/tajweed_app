import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/recitation_provider.dart';
import '../../core/providers/streak_provider.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<RecitationProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordReview)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.recordReview,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.get('ai_feedback'),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            _AyahSelector(),
            const SizedBox(height: 24),
            _RecordButton(provider: provider),
            const SizedBox(height: 24),
            if (provider.hasFeedback) _FeedbackPanel(feedback: provider.lastFeedback!),
            if (!provider.hasFeedback) _PlaceholderFeedback(),
          ],
        ),
      ),
    );
  }
}

class _AyahSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Al-Mulk 67:1',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text('Tap to change',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Text(
            'تَبَارَكَ الَّذِي بِيَدِهِ الْمُلْكُ',
            style: TextStyle(
                fontFamily: 'UthmanicHafs',
                fontSize: 16,
                color: Color(0xFF0F6E56)),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final RecitationProvider provider;
  const _RecordButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRecording = provider.isRecording;
    final isProcessing = provider.isProcessing;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: isProcessing ? null : () {
              if (isRecording) {
                provider.stopRecording('/tmp/recording.m4a');
                context.read<StreakProvider>().recordActivity();
              } else {
                provider.startRecording();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? const Color(0xFFFCEBEB)
                    : Theme.of(context).colorScheme.surfaceVariant,
                border: Border.all(
                  color: isRecording
                      ? const Color(0xFFE24B4A)
                      : Theme.of(context).dividerColor,
                  width: isRecording ? 2 : 0.5,
                ),
              ),
              child: isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Container(
                      margin: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE24B4A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_rounded,
                          color: Colors.white, size: 24),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isProcessing
                ? 'Analysing...'
                : isRecording
                    ? l10n.get('recording')
                    : l10n.tapToRecord,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  final RecitationFeedback feedback;
  const _FeedbackPanel({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.get('last_session'),
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${feedback.overallScore}',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F6E56))),
              const SizedBox(width: 6),
              Text('/ 100 ${l10n.get('overall_score')}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 16),
          ...feedback.ruleScores.entries.map((e) {
            final defn = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      defn.arabicName,
                      style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 13),
                      textDirection: TextDirection.rtl,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: e.value,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        valueColor: AlwaysStoppedAnimation(defn.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${(e.value * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlaceholderFeedback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last session — Al-Fatiha 1:1',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 12),
          ...[(TajweedRule.maddTabeei, 0.90), (TajweedRule.ghunnah, 0.75),
              (TajweedRule.qalqalah, 0.85), (TajweedRule.idghamWithGhunnah, 0.60)].map((e) {
            final (rule, score) = e;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(rule.arabicName,
                        style: const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 13),
                        textDirection: TextDirection.rtl,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: score, minHeight: 6,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        valueColor: AlwaysStoppedAnimation(rule.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text('${(score * 100).round()}%',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
