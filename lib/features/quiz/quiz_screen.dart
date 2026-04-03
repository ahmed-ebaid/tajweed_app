import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/quiz_progress_provider.dart';
import '../../core/providers/streak_provider.dart';
import 'quiz_repository.dart';
import 'widgets/quiz_results_sheet.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizLevel? _activeLevel;
  int _current = 0;
  int? _selectedIndex;
  int _score = 0;
  List<QuizQuestion> _questions = const [];

  bool get _answered => _selectedIndex != null;
  bool get _isCorrect =>
      _questions.isNotEmpty && _selectedIndex == _questions[_current].correctIndex;

  void _startLevel(QuizLevel level) {
    setState(() {
      _activeLevel = level;
      _current = 0;
      _selectedIndex = null;
      _score = 0;
      _questions = QuizRepository.randomizedUnique(level: level);
    });
  }

  void _showLevelPicker() {
    setState(() {
      _activeLevel = null;
      _current = 0;
      _selectedIndex = null;
      _score = 0;
      _questions = const [];
    });
  }

  Future<void> _answer(int index) async {
    if (_questions.isEmpty) return;
    if (_answered) return;
    final isCorrect = index == _questions[_current].correctIndex;
    setState(() {
      _selectedIndex = index;
      if (isCorrect) {
        _score++;
      }
    });

    if (isCorrect) {
      await context.read<StreakProvider>().recordActivity();
    }
  }

  Future<void> _next() async {
    if (_activeLevel == null || _questions.isEmpty) return;
    if (_current < _questions.length - 1) {
      setState(() {
        _current++;
        _selectedIndex = null;
      });
      return;
    }

    final l10n = AppLocalizations.of(context);
    final level = _activeLevel!;
    final percentage = _questions.isEmpty ? 0 : ((_score / _questions.length) * 100).round();
    final passed = percentage >= QuizRepository.passPercentage;
    final nextLevel = QuizRepository.nextLevelAfter(level);
    final unlockedNext = await context.read<QuizProgressProvider>().recordLevelResult(
          level: level,
          percentage: percentage,
        );

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => QuizResultsSheet(
        score: _score,
        total: _questions.length,
        success: passed,
        headline: passed ? l10n.get('quiz_passed') : l10n.get('quiz_failed'),
        message: passed
            ? nextLevel == null
                ? l10n.get('quiz_all_levels_unlocked')
                : unlockedNext
                    ? l10n.get('quiz_next_level_unlocked')
                    : l10n.get('quiz_pass_requirement_met')
            : '${QuizRepository.passPercentage}% ${l10n.get('quiz_pass_requirement')}',
        primaryLabel: passed && nextLevel != null
            ? l10n.get('continue_to_next_level')
            : passed
                ? l10n.get('back_to_levels')
                : l10n.get('retry_level'),
        onPrimary: () {
          Navigator.of(sheetContext).pop();
          if (!mounted) return;
          if (passed && nextLevel != null) {
            _startLevel(nextLevel);
            return;
          }
          if (passed) {
            _showLevelPicker();
            return;
          }
          _startLevel(level);
        },
        secondaryLabel: passed ? l10n.get('retry_level') : l10n.get('back_to_levels'),
        onSecondary: () {
          Navigator.of(sheetContext).pop();
          if (!mounted) return;
          if (passed) {
            _startLevel(level);
            return;
          }
          _showLevelPicker();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_activeLevel == null) {
      return _QuizLevelPicker(
        onSelectLevel: _startLevel,
      );
    }

    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final q = _questions[_current];
    final levelDefinition = QuizRepository.definitionFor(_activeLevel!);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _showLevelPicker,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(l10n.ruleQuiz),
      ),
      body: Column(
        children: [
          _ProgressHeader(
            current: _current,
            total: _questions.length,
            label: l10n.get(levelDefinition.titleKey),
            score: _score,
            scoreLabel: l10n.get('overall_score'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _QuizCard(arabic: q.arabicText, question: q.question(langCode)),
                  const SizedBox(height: 12),
                  ...List.generate(q.options.length, (i) => _OptionTile(
                    text: q.optionText(i, langCode),
                    index: i,
                    selectedIndex: _selectedIndex,
                    correctIndex: q.correctIndex,
                    onTap: () {
                      unawaited(_answer(i));
                    },
                  )),
                  if (_answered) ...[
                    const SizedBox(height: 12),
                    _FeedbackBanner(
                      correct: _isCorrect,
                      explanation: q.explain(langCode),
                      correctLabel: l10n.get('correct'),
                      wrongLabel: l10n.get('not_quite'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          unawaited(_next());
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _current < _questions.length - 1
                              ? l10n.nextQuestion
                              : l10n.get('quiz_finish_level'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizLevelPicker extends StatelessWidget {
  final void Function(QuizLevel level) onSelectLevel;

  const _QuizLevelPicker({required this.onSelectLevel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = context.watch<QuizProgressProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ruleQuiz)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l10n.get('quiz_levels'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.get('choose_level'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...QuizRepository.levels.map((definition) {
            final isUnlocked = progress.isUnlocked(definition.level);
            final isRecommended = progress.recommendedLevel == definition.level;
            final best = progress.bestPercentageFor(definition.level);
            return _LevelCard(
              title: l10n.get(definition.titleKey),
              subtitle: l10n.get(definition.subtitleKey),
              isUnlocked: isUnlocked,
              isRecommended: isRecommended,
              bestPercentage: best,
              passRequirementLabel:
                  '${QuizRepository.passPercentage}% ${l10n.get('quiz_pass_requirement')}',
              onTap: isUnlocked ? () => onSelectLevel(definition.level) : null,
            );
          }),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isUnlocked;
  final bool isRecommended;
  final int bestPercentage;
  final String passRequirementLabel;
  final VoidCallback? onTap;

  const _LevelCard({
    required this.title,
    required this.subtitle,
    required this.isUnlocked,
    required this.isRecommended,
    required this.bestPercentage,
    required this.passRequirementLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFF9FE1CB)
              : Theme.of(context).dividerColor,
          width: 0.8,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F5EE),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        l10n.get('quiz_recommended'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F6E56),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    size: 16,
                    color: isUnlocked ? const Color(0xFF1D9E75) : const Color(0xFF888780),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUnlocked ? l10n.get('quiz_unlocked') : l10n.get('quiz_locked'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${l10n.get('best_score')}: $bestPercentage%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF0F6E56),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                passRequirementLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: isUnlocked
                        ? const Color(0xFF1D9E75)
                        : Theme.of(context).colorScheme.surfaceVariant,
                    foregroundColor: isUnlocked
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  child: Text(
                    isUnlocked ? l10n.get('start_level') : l10n.get('quiz_locked'),
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

class _ProgressHeader extends StatelessWidget {
  final int current;
  final int total;
  final String label;
  final int score;
  final String scoreLabel;

  const _ProgressHeader({
    required this.current,
    required this.total,
    required this.label,
    required this.score,
    required this.scoreLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (current + 1) / total,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1D9E75)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${current + 1} / $total',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0F6E56))),
                  ),
                ),
              ),
              Text(
                '$score / $total $scoreLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF0F6E56),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final String arabic;
  final String question;
  const _QuizCard({required this.arabic, required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        children: [
          Text(arabic,
              style: const TextStyle(
                  fontFamily: 'UthmanicHafs', fontSize: 36, height: 1.8),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 8),
          Text(question,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String text;
  final int index;
  final int? selectedIndex;
  final int correctIndex;
  final VoidCallback onTap;

  const _OptionTile({
    required this.text, required this.index,
    required this.selectedIndex, required this.correctIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Theme.of(context).dividerColor;
    Color bgColor = Theme.of(context).colorScheme.surface;
    Color textColor = Theme.of(context).textTheme.bodyLarge!.color!;

    if (selectedIndex != null) {
      if (index == correctIndex) {
        borderColor = const Color(0xFF1D9E75);
        bgColor = const Color(0xFFE1F5EE);
        textColor = const Color(0xFF0F6E56);
      } else if (index == selectedIndex) {
        borderColor = const Color(0xFFA32D2D);
        bgColor = const Color(0xFFFCEBEB);
        textColor = const Color(0xFFA32D2D);
      } else {
        textColor = textColor.withOpacity(0.4);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                String.fromCharCode(65 + index), // A, B, C, D
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text,
                style: TextStyle(fontSize: 14, color: textColor))),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final bool correct;
  final String explanation;
  final String correctLabel;
  final String wrongLabel;

  const _FeedbackBanner({
    required this.correct, required this.explanation,
    required this.correctLabel, required this.wrongLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFE1F5EE) : const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: correct ? const Color(0xFF9FE1CB) : const Color(0xFFF7C1C1),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: correct ? const Color(0xFF1D9E75) : const Color(0xFFA32D2D),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correct ? correctLabel : wrongLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: correct ? const Color(0xFF0F6E56) : const Color(0xFFA32D2D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(explanation,
                    style: TextStyle(
                      fontSize: 13,
                      color: correct ? const Color(0xFF0F6E56) : const Color(0xFFA32D2D),
                      height: 1.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
