import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';

import 'core/providers/locale_provider.dart';
import 'core/services/review_prompt_service.dart';
import 'core/services/seasonal_icon_service.dart';
import 'core/services/quran_offline_sync_service.dart';
import 'core/services/quran_content_sync_service.dart';
import 'features/home/home_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/quiz/quiz_screen.dart';
import 'features/rules/rules_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/widgets/app_bottom_nav.dart';

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold>
    with WidgetsBindingObserver {
  static const _foregroundMaintenanceInterval = Duration(hours: 12);

  int _currentIndex = 0;
  final QuranOfflineSyncService _quranOfflineSync = QuranOfflineSyncService();
  final QuranContentSyncService _contentSync = QuranContentSyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _foregroundMaintenanceTimer;
  Timer? _reviewPromptTimer;
  bool _wasOffline = false;
  bool _isForeground = true;
  bool _reviewPromptHandledThisLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    _foregroundMaintenanceTimer = Timer.periodic(
      _foregroundMaintenanceInterval,
      (_) {
        if (_isForeground && !_wasOffline) {
          unawaited(_runOfflineMaintenance());
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_applySeasonalIcon());
      _scheduleReviewPrompt();
    });
    unawaited(_initializeOfflineMaintenance());
  }

  Future<void> _applySeasonalIcon() async {
    try {
      if (await SeasonalIconService().applyForDate()) {
        // Avoid stacking the review sheet on top of the icon-change alert.
        _reviewPromptHandledThisLaunch = true;
        _reviewPromptTimer?.cancel();
        _reviewPromptTimer = null;
      }
    } catch (error) {
      debugPrint('Seasonal icon update failed: $error');
    }
  }

  void _scheduleReviewPrompt() {
    if (_reviewPromptHandledThisLaunch || _reviewPromptTimer != null) return;
    _reviewPromptTimer = Timer(const Duration(seconds: 5), () {
      _reviewPromptTimer = null;
      unawaited(_requestReviewIfAppropriate());
    });
  }

  Future<void> _requestReviewIfAppropriate() async {
    if (!mounted ||
        !_isForeground ||
        _currentIndex != 0 ||
        ModalRoute.of(context)?.isCurrent != true ||
        _reviewPromptHandledThisLaunch) {
      return;
    }
    _reviewPromptHandledThisLaunch = true;
    try {
      await ReviewPromptService().requestAtLaunch(
        isAvailable: InAppReview.instance.isAvailable,
        requestReview: InAppReview.instance.requestReview,
      );
    } catch (error) {
      debugPrint('In-app review request failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      unawaited(_applySeasonalIcon());
      if (_currentIndex == 0) _scheduleReviewPrompt();
      unawaited(_runOfflineMaintenance());
    }
  }

  Future<void> _initializeOfflineMaintenance() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      _wasOffline = connectivity.every(
        (result) => result == ConnectivityResult.none,
      );
    } catch (error) {
      debugPrint('Connectivity check failed: $error');
    }
    await _runOfflineMaintenance();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline = results.every(
      (result) => result == ConnectivityResult.none,
    );
    final reconnected = _wasOffline && !isOffline;
    _wasOffline = isOffline;
    if (reconnected) {
      unawaited(_runOfflineMaintenance(ignoreBackoff: true));
    }
  }

  Future<void> _runOfflineMaintenance({bool ignoreBackoff = false}) async {
    try {
      await _contentSync.syncIfDue(ignoreBackoff: ignoreBackoff);
    } catch (error) {
      debugPrint('Quran Content Sync failed: $error');
    }
    try {
      await _quranOfflineSync.ensureBackgroundSync();
    } catch (error) {
      debugPrint('Quran text validation failed: $error');
    }
    try {
      await _contentSync.syncIfDue(ignoreBackoff: ignoreBackoff);
    } catch (error) {
      debugPrint('Quran Content Sync follow-up failed: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundMaintenanceTimer?.cancel();
    _reviewPromptTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  void _switchTab(int index) {
    if (index != 0) _reviewPromptTimer?.cancel();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = context.watch<LocaleProvider>().isRtl;

    final screens = [
      HomeScreen(onTabSwitch: _switchTab),
      ReaderScreen(isActive: _currentIndex == 1),
      const QuizScreen(),
      const RulesScreen(),
    ];

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: screens),
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
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                child: const Icon(Icons.settings_outlined, size: 20),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      ),
    );
  }
}
