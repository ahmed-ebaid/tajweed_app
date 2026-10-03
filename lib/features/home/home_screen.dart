import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/data/surah_names.dart';
import '../../core/providers/daily_lesson_provider.dart';
import '../../core/providers/bookmark_provider.dart';
import '../../core/providers/reader_navigation_provider.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int index) onTabSwitch;
  const HomeScreen({super.key, required this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dailyLesson = context.watch<DailyLessonProvider>();
    final lesson = dailyLesson.todayLesson;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(l10n: l10n),
              _ReadingCard(
                l10n: l10n,
                bookmarks: context.watch<BookmarkProvider>(),
                onTap: () => onTabSwitch(1),
              ),
              _TodayLesson(
                l10n: l10n,
                lessonTitle: lesson.titleFor(l10n.locale.languageCode),
                progress: dailyLesson.progressForToday,
                onTap: () {
                  context.read<ReaderNavigationProvider>().openSurahAyah(
                    surah: lesson.surah,
                    ayah: lesson.ayah,
                  );
                  onTabSwitch(1);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.practice,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
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
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.greeting,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.get('home_moment'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '﴿ وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا ﴾',
              style: TextStyle(
                fontFamily: 'UthmanicHafs',
                fontSize: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final AppLocalizations l10n;
  final BookmarkProvider bookmarks;
  final VoidCallback onTap;

  const _ReadingCard({
    required this.l10n,
    required this.bookmarks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLastRead = bookmarks.hasLastRead;
    return Container(
      key: const Key('home_reading_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF246F57), Color(0xFF104C3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.get('home_reading'),
            style: const TextStyle(
              color: Color(0xFFE0F0E7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasLastRead
                ? surahName(bookmarks.lastReadSurah, l10n.locale.languageCode)
                : l10n.get('home_begin'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasLastRead
                ? '${l10n.get('ayah')} ${bookmarks.lastReadAyah}'
                : l10n.get('home_intro'),
            style: const TextStyle(
              color: Color(0xFFE0F0E7),
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('home_continue_reading'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF5FAF3),
                foregroundColor: const Color(0xFF174F3D),
                padding: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Switch tabs only: let the reader keep its existing restore
              // path, including the saved scroll offset and Mushaf mode.
              onPressed: onTap,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.get(hasLastRead ? 'home_continue' : 'home_start'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayLesson extends StatelessWidget {
  final AppLocalizations l10n;
  final String lessonTitle;
  final double progress;
  final VoidCallback onTap;
  const _TodayLesson({
    required this.l10n,
    required this.lessonTitle,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = progress >= 0.999;
    final statusText = isComplete
        ? l10n.get('complete')
        : l10n.get('not_quite');

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Semantics(
            button: true,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.todaysLesson,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                      letterSpacing: 0.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lessonTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (progress > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).round()}% • $statusText',
                      style: TextStyle(fontSize: 11, color: scheme.primary),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.get('home_lesson_intro'),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
        icon: Icons.quiz_rounded,
        iconBg: const Color(0xFFFAEEDA),
        iconColor: const Color(0xFFB8860B),
        title: l10n.ruleQuiz,
        sub: l10n.get('test_knowledge'),
        tab: 2,
      ),
      _CardData(
        icon: Icons.library_books_rounded,
        iconBg: const Color(0xFFFAEEDA),
        iconColor: const Color(0xFFB8860B),
        title: l10n.rulesLibrary,
        sub: l10n.get('all_tajweed_rules'),
        tab: 3,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(16) > 22;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards
                .map(
                  (c) => SizedBox(
                    width: singleColumn
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2,
                    child: _QuickCard(data: c, onTabSwitch: onTabSwitch),
                  ),
                )
                .toList(),
          );
        },
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
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.tab,
  });
}

class _QuickCard extends StatelessWidget {
  final _CardData data;
  final void Function(int) onTabSwitch;
  const _QuickCard({required this.data, required this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTabSwitch(data.tab),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: data.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.icon, color: data.iconColor, size: 18),
                ),
                const SizedBox(height: 14),
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.sub,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
