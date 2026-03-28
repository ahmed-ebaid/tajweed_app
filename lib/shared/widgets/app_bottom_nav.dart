import 'package:flutter/material.dart';
import '../../core/l10n/app_localizations.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.menu_book_outlined),
          activeIcon: const Icon(Icons.menu_book_rounded),
          label: l10n.get('surah'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.quiz_outlined),
          activeIcon: const Icon(Icons.quiz_rounded),
          label: l10n.ruleQuiz,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.library_books_outlined),
          activeIcon: const Icon(Icons.library_books_rounded),
          label: l10n.rulesLibrary,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.mic_outlined),
          activeIcon: const Icon(Icons.mic_rounded),
          label: l10n.recordReview,
        ),
      ],
    );
  }
}
