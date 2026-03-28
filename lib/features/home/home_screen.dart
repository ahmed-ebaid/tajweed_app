import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/providers/streak_provider.dart';
import '../../shared/widgets/streak_bar.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int index) onTabSwitch;
  const HomeScreen({super.key, required this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final streak = context.watch<StreakProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(l10n: l10n),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StreakBar(
                  streakCount: streak.streakCount,
                  weekDots: streak.weekDots,
                ),
              ),
              _TodayLesson(l10n: l10n, onTap: () => onTabSwitch(1)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l10n.practice,
                    style: Theme.of(context).textTheme.labelMedium),
              ),
              _QuickCards(l10n: l10n, onTabSwitch: onTabSwitch),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppLocalizations l10n;
  const _Header({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.greeting,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(l10n.continueJourney,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '﴿ وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا ﴾',
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 18,
              color: Color(0xFF1D9E75),
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

class _TodayLesson extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onTap;
  const _TodayLesson({required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE1F5EE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF9FE1CB), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.todaysLesson,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D9E75),
                    letterSpacing: 0.05)),
            const SizedBox(height: 4),
            const Text(
              'Ghunnah in Surah Al-Mulk',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F6E56)),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 0.65,
                backgroundColor: const Color(0xFF9FE1CB),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1D9E75)),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text('65% ${l10n.get('complete')}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1D9E75))),
          ],
        ),
      ),
    );
  }
}

class _QuickCards extends StatelessWidget {
  final AppLocalizations l10n;
  final void Function(int) onTabSwitch;
  const _QuickCards({required this.l10n, required this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CardData(
          icon: Icons.menu_book_rounded,
          iconBg: const Color(0xFFE1F5EE),
          iconColor: const Color(0xFF1D9E75),
          title: l10n.readWithTajweed,
          sub: l10n.get('colored_highlights'),
          tab: 1),
      _CardData(
          icon: Icons.quiz_rounded,
          iconBg: const Color(0xFFFAEEDA),
          iconColor: const Color(0xFFB8860B),
          title: l10n.ruleQuiz,
          sub: l10n.get('test_knowledge'),
          tab: 2),
      _CardData(
          icon: Icons.mic_rounded,
          iconBg: const Color(0xFFE1F5EE),
          iconColor: const Color(0xFF1D9E75),
          title: l10n.recordReview,
          sub: l10n.get('ai_feedback'),
          tab: 3),
      _CardData(
          icon: Icons.library_books_rounded,
          iconBg: const Color(0xFFFAEEDA),
          iconColor: const Color(0xFFB8860B),
          title: l10n.rulesLibrary,
          sub: l10n.get('all_tajweed_rules'),
          tab: 4),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
        children: cards.map((c) => _QuickCard(data: c, onTabSwitch: onTabSwitch)).toList(),
      ),
    );
  }
}

class _CardData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String sub;
  final int tab;
  const _CardData({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.sub, required this.tab,
  });
}

class _QuickCard extends StatelessWidget {
  final _CardData data;
  final void Function(int) onTabSwitch;
  const _QuickCard({required this.data, required this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTabSwitch(data.tab),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(data.icon, color: data.iconColor, size: 18),
            ),
            const Spacer(),
            Text(data.title,
                style: Theme.of(context).textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(data.sub,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
