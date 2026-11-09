import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_practice/core/providers/bookmark_provider.dart';
import 'package:tajweed_practice/core/providers/daily_lesson_provider.dart';
import 'package:tajweed_practice/core/providers/locale_provider.dart';
import 'package:tajweed_practice/core/providers/quiz_progress_provider.dart';
import 'package:tajweed_practice/core/providers/reader_navigation_provider.dart';
import 'package:tajweed_practice/core/providers/recitation_provider.dart';
import 'package:tajweed_practice/core/providers/streak_provider.dart';
import 'package:tajweed_practice/core/providers/tafseer_provider.dart';
import 'package:tajweed_practice/core/services/hijri_calendar_service.dart';
import 'package:tajweed_practice/core/services/review_prompt_service.dart';
import 'package:tajweed_practice/core/services/seasonal_icon_service.dart';
import 'package:tajweed_practice/features/onboarding/onboarding_screen.dart';
import 'package:tajweed_practice/features/reader/reader_screen.dart';
import 'package:tajweed_practice/main.dart';
import 'package:tajweed_practice/root_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const reviewChannel = MethodChannel('dev.britannio.in_app_review');
  const connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );
  const connectivityEvents = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  const calendarChannel = MethodChannel(HijriCalendarService.channelName);
  const iconChannel = MethodChannel(SeasonalIconService.channelName);
  var requests = 0;
  Completer<bool>? availability;

  setUp(() async {
    requests = 0;
    availability = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(reviewChannel, (call) async {
      if (call.method == 'isAvailable') {
        return availability == null ? true : availability!.future;
      }
      if (call.method == 'requestReview') requests++;
      return null;
    });
    messenger.setMockMethodCallHandler(
      connectivityChannel,
      (_) async => ['none'],
    );
    messenger.setMockMethodCallHandler(connectivityEvents, (_) async => null);
    messenger.setMockMethodCallHandler(
      calendarChannel,
      (_) async => {'year': 1448, 'month': 5, 'day': 22},
    );
    messenger.setMockMethodCallHandler(iconChannel, (call) async {
      if (call.method == 'supportsAlternateIcons') return true;
      if (call.method == 'getIconName') return 'AppIcon-Ramadan';
      return null;
    });
    for (final name in [
      'settings',
      'streak',
      'verse_cache',
      'bookmarks',
      'audio_cache',
    ]) {
      await Hive.openBox<dynamic>(name, bytes: Uint8List(0));
    }
    final settings = Hive.box('settings');
    await settings.putAll({
      'locale': 'en',
      'onboarding_dismissed': true,
      'seasonal_icon_enabled': false,
      'reader_view_mode': 'page',
      'quran_sync_version': 9,
      'quran_sync_completed_at': DateTime.now().millisecondsSinceEpoch,
      'qf_content_sync_validated_at': DateTime.now().millisecondsSinceEpoch,
      ReviewPromptService.readingDaysKey: [
        '2026-10-01',
        '2026-10-02',
        '2026-10-03',
      ],
      'reader_surah_list_en': [
        {
          'id': 1,
          'name_simple': 'Al-Fatihah',
          'name_arabic': 'الفاتحة',
          'verses_count': 1,
        },
      ],
    });
    await Hive.box('verse_cache').put('quran_ar_surah_1', [
      {'verse_key': '1:1', 'page_number': 1, 'text_uthmani': 'بِسْمِ اللَّهِ'},
    ]);
    for (var surah = 1; surah <= 114; surah++) {
      await Hive.box(
        'verse_cache',
      ).put('quran_tajweed_surah_$surah', {'$surah:1': 'بِسْمِ اللَّهِ'});
      if (surah != 1) {
        await Hive.box('verse_cache').put('quran_ar_surah_$surah', [
          {'verse_key': '$surah:1', 'text_uthmani': 'بِسْمِ اللَّهِ'},
        ]);
      }
    }
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      reviewChannel,
      connectivityChannel,
      connectivityEvents,
      calendarChannel,
      iconChannel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    await Hive.close();
  });

  Future<void> launch(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => StreakProvider()),
          ChangeNotifierProvider(create: (_) => BookmarkProvider()),
          ChangeNotifierProvider(create: (_) => DailyLessonProvider()),
          ChangeNotifierProvider(create: (_) => QuizProgressProvider()),
          ChangeNotifierProvider(create: (_) => ReaderNavigationProvider()),
          ChangeNotifierProvider(create: (_) => RecitationProvider()),
          ChangeNotifierProvider(
            create: (_) => TafseerProvider(langCode: 'en'),
          ),
        ],
        child: const TajweedApp(),
      ),
    );
    await tester.pump();
  }

  Future<void> tick(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 5),
  }) async {
    await tester.pump(duration);
    for (var flush = 0; flush < 3; flush++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }

  void background(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  void foreground(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  testWidgets('opening Reader immediately still requests once', (tester) async {
    await launch(tester);
    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigation.items, hasLength(4));
    expect(find.byIcon(Icons.psychology_outlined), findsNothing);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    expect(
      tester.widget<ReaderScreen>(find.byType(ReaderScreen)).isActive,
      true,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(requests, 0);
    await tick(tester, duration: const Duration(seconds: 1));
    expect(requests, 1);
    await tick(tester);
    expect(requests, 1);
    await close(tester);
  });

  testWidgets('page fullscreen hides both bars and restores navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tick(tester, duration: const Duration(seconds: 1));
    expect(
      tester.widget<PageView>(find.byType(PageView).last).childrenDelegate,
      isA<SliverChildBuilderDelegate>().having(
        (delegate) => delegate.estimatedChildCount,
        '604-page Mushaf context',
        604,
      ),
    );
    final region = find.byKey(const ValueKey('mushaf-content-region')).first;
    final originalHeight = tester.getSize(region).height;
    await tester.tap(find.byTooltip('Read full screen'));
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(
      (tester.widget<PageView>(find.byType(PageView).last).childrenDelegate
              as SliverChildBuilderDelegate)
          .estimatedChildCount,
      604,
    );
    expect(find.byTooltip('Show reading controls'), findsOneWidget);
    expect(tester.getSize(region).height, greaterThan(originalHeight + 80));
    await tick(tester);
    expect(requests, 0, reason: 'Do not interrupt full-screen reading');

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(tester.getSize(region).height, closeTo(originalHeight, 0.01));

    await tester.tap(find.byTooltip('Read full screen'));
    await tester.pump();
    await tester.tap(find.byTooltip('Show reading controls'));
    await tester.pump();
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    await tester.tap(find.byTooltip('Read full screen'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byTooltip('Read full screen'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('Mushaf controls auto-hide and taps restart the delay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    await launch(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tick(tester, duration: const Duration(seconds: 1));
    final region = find.byKey(const ValueKey('mushaf-content-region')).first;
    final originalHeight = tester.getSize(region).height;
    await tick(tester, duration: const Duration(seconds: 6));
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(tester.getSize(region).height, greaterThan(originalHeight + 70));
    await tester.tap(find.byTooltip('Show reading controls'));
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump(const Duration(seconds: 7));
    expect(find.byType(AppBar), findsOneWidget);
    await gesture.up();
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(AppBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AppBar), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tick(tester, duration: const Duration(seconds: 10));
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byTooltip('Read full screen'), findsNothing);
    await close(tester);
  });

  testWidgets('Mushaf auto-hide pauses for dialogs and backgrounding', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tick(tester, duration: const Duration(seconds: 1));
    final context = tester.element(find.byType(RootScaffold));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Reading dialog')),
      ),
    );
    await tester.pump();
    await tick(tester, duration: const Duration(seconds: 8));
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    background(tester);
    await tick(tester, duration: const Duration(seconds: 8));
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    foreground(tester);
    await tick(tester, duration: const Duration(seconds: 6));
    expect(find.byType(BottomNavigationBar), findsNothing);
    await close(tester);
  });

  testWidgets('waits for a dialog to close instead of losing the request', (
    tester,
  ) async {
    await launch(tester);
    final context = tester.element(find.byType(RootScaffold));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Dialog')),
      ),
    );
    await tester.pump();
    await tick(tester);
    expect(requests, 0);
    expect(
      Hive.box('settings').get(ReviewPromptService.lastAttemptKey),
      isNull,
    );
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await tick(tester);
    expect(requests, 1);
    await close(tester);
  });

  testWidgets('waits for reader audio to stop', (tester) async {
    await launch(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    reader.onAudioActivityChanged!(true);
    await tick(tester);
    expect(requests, 0);
    reader.onAudioActivityChanged!(false);
    await tick(tester);
    expect(requests, 0, reason: 'Auto-hidden reading still defers reviews');
    await tester.tap(find.byTooltip('Show reading controls'));
    await tester.pump();
    await tick(tester);
    expect(requests, 1);
    await close(tester);
  });

  testWidgets('does not interrupt a quiz when the launch delay expires', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await tester.pump();
    await tick(tester);
    expect(requests, 0);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    await tick(tester);
    expect(requests, 1);
    await close(tester);
  });

  testWidgets('does not request over onboarding', (tester) async {
    await Hive.box('settings').put('onboarding_dismissed', false);
    await launch(tester);
    await tick(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(requests, 0);
    Navigator.of(tester.element(find.byType(OnboardingScreen))).pop();
    await tester.pumpAndSettle();
    await tick(tester);
    expect(requests, 1);
    await close(tester);
  });

  testWidgets(
    'an icon change skips review for the whole launch',
    (tester) async {
      await launch(tester);
      await tick(tester);
      expect(requests, 0);
      background(tester);
      foreground(tester);
      await tick(tester);
      expect(requests, 0);
      expect(
        Hive.box('settings').get(ReviewPromptService.lastAttemptKey),
        isNull,
      );
      await close(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('a recent attempt prevents another request after navigation', (
    tester,
  ) async {
    await ReviewPromptService().recordPromptAttempt();
    await launch(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    await tick(tester);
    expect(requests, 0);
    await close(tester);
  });

  testWidgets('background cancels timer and Reader resume retries', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    background(tester);
    await tick(tester);
    expect(requests, 0);
    foreground(tester);
    await tick(tester);
    expect(requests, 1);
    await close(tester);
  });

  testWidgets('rechecks safety after native availability completes', (
    tester,
  ) async {
    availability = Completer<bool>();
    await launch(tester);
    await tick(tester);
    background(tester);
    availability!.complete(true);
    await tester.pump();
    expect(requests, 0);
    expect(
      Hive.box('settings').get(ReviewPromptService.lastAttemptKey),
      isNull,
    );
    foreground(tester);
    await tick(tester);
    expect(requests, 1);
    await close(tester);
  });

  testWidgets('newly eligible readers wait for a later launch', (tester) async {
    await Hive.box(
      'settings',
    ).put(ReviewPromptService.readingDaysKey, <String>[]);
    await launch(tester);
    await tester.runAsync(() async {
      for (var day = 1; day <= 3; day++) {
        await ReviewPromptService().recordMeaningfulReadingDay(
          date: DateTime(2026, 10, day),
        );
      }
    });
    background(tester);
    foreground(tester);
    await tick(tester);
    expect(requests, 0);
    await close(tester);
  });
}
