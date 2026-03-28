import 'package:flutter/material.dart';
import '../../core/l10n/app_localizations.dart';

class StreakBar extends StatelessWidget {
  final int streakCount;
  final List<bool> weekDots; // 7 booleans, Mon–Sun

  const StreakBar({
    super.key,
    required this.streakCount,
    required this.weekDots,
  });

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now().weekday - 1; // 0 = Monday

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.dayStreak,
                    style: Theme.of(context).textTheme.bodySmall),
                Text('$streakCount days',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Row(
            children: List.generate(7, (i) {
              final done = i < weekDots.length && weekDots[i];
              final isToday = i == today;
              return Padding(
                padding: const EdgeInsets.only(left: 5),
                child: _DayDot(
                  letter: _dayLetters[i],
                  done: done,
                  isToday: isToday,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String letter;
  final bool done;
  final bool isToday;

  const _DayDot({required this.letter, required this.done, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? const Color(0xFF1D9E75)
            : Theme.of(context).colorScheme.surfaceVariant,
        border: isToday && !done
            ? Border.all(color: const Color(0xFF1D9E75), width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: done
              ? Colors.white
              : isToday
                  ? const Color(0xFF0F6E56)
                  : Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
