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
