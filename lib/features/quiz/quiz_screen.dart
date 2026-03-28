import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/streak_provider.dart';
import 'quiz_repository.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _current = 0;
  int? _selectedIndex;

  static final List<QuizQuestion> _questions = QuizRepository.all;

  bool get _answered => _selectedIndex != null;
  bool get _isCorrect =>
      _selectedIndex == _questions[_current].correctIndex;

  void _answer(int index) {
    if (_answered) return;
    setState(() {
      _selectedIndex = index;
    });
    context.read<StreakProvider>().recordActivity();
  }

  void _next() {
    if (_current < _questions.length - 1) {
      setState(() {
        _current++;
        _selectedIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final q = _questions[_current];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ruleQuiz)),
      body: Column(
        children: [
          _ProgressHeader(
            current: _current,
            total: _questions.length,
            label: l10n.identifyTheRule,
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
                    onTap: () => _answer(i),
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
                        onPressed: _current < _questions.length - 1 ? _next : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.nextQuestion),
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

class _ProgressHeader extends StatelessWidget {
  final int current;
  final int total;
  final String label;
  const _ProgressHeader({required this.current, required this.total, required this.label});

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
          Align(
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
