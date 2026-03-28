import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/locale_provider.dart';
import 'features/home/home_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/quiz/quiz_screen.dart';
import 'features/rules/rules_screen.dart';
import 'features/record/record_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/widgets/app_bottom_nav.dart';

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _currentIndex = 0;

  void _switchTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final isRtl = context.watch<LocaleProvider>().isRtl;

    final screens = [
      HomeScreen(onTabSwitch: _switchTab),
      const ReaderScreen(),
      const QuizScreen(),
      const RulesScreen(),
      const RecordScreen(),
    ];

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _currentIndex,
          onTap: _switchTab,
        ),
        // Keep floating settings on other tabs, but hide on reader where
        // settings is shown directly in the app bar actions.
        floatingActionButton: _currentIndex == 1
            ? null
            : FloatingActionButton.small(
                heroTag: 'settings',
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                elevation: 0,
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: const Icon(Icons.settings_outlined, size: 20),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      ),
    );
  }
}
