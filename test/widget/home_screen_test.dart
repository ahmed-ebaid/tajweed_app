import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/data/surah_names.dart';
import 'package:tajweed_practice/core/l10n/home_localizations.dart';
import 'package:tajweed_practice/core/providers/bookmark_provider.dart';
import 'package:tajweed_practice/core/providers/daily_lesson_provider.dart';
import 'package:tajweed_practice/core/providers/reader_navigation_provider.dart';
import 'package:tajweed_practice/core/providers/streak_provider.dart';
import 'package:tajweed_practice/features/home/home_screen.dart';

void main() {
  late Directory temp;
  late BookmarkProvider bookmarks;
  late ReaderNavigationProvider navigation;
  late DailyLessonProvider lesson;
  late StreakProvider streak;
  late List<int> tabs;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('home_test_');
    Hive.init(temp.path);
    for (final box in ['settings', 'bookmarks', 'streak']) {
      await Hive.openBox<dynamic>(box);
    }
    bookmarks = BookmarkProvider();
    navigation = ReaderNavigationProvider();
    lesson = DailyLessonProvider();
    streak = StreakProvider();
    tabs = [];
  });
  tearDown(() async {
    bookmarks.dispose();
    navigation.dispose();
    lesson.dispose();
    streak.dispose();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  Widget subject({String lang = 'en', bool dark = false, double scale = 1}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: bookmarks),
          ChangeNotifierProvider.value(value: navigation),
          ChangeNotifierProvider.value(value: lesson),
          ChangeNotifierProvider.value(value: streak),
        ],
        child: MaterialApp(
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF246F57),
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
          ),
          home: HomeScreen(onTabSwitch: tabs.add),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      );

  testWidgets('new reader can start without changing saved position', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('Start reading'), findsOneWidget);
    expect(find.text('Al-Muzzammil · Ayah 4'), findsOneWidget);
    expect(find.textContaining('0%'), findsNothing);
    expect(find.textContaining('Not quite'), findsNothing);
    await tester.tap(find.byKey(const Key('home_continue_reading')));
    expect(tabs, [1]);
    expect(navigation.pending, isNull);
    expect(bookmarks.hasLastRead, isFalse);
  });

  testWidgets('continue keeps the saved ayah and scroll offset intact', (
    tester,
  ) async {
    await tester.runAsync(
      () => bookmarks.saveLastRead(18, 45, scrollOffset: 732.5),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.text('Al-Kahf'), findsOneWidget);
    expect(find.text('🔥'), findsNothing);
    expect(find.text('Ayah 45'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_continue_reading')));
    expect(tabs, [1]);
    expect(navigation.pending, isNull);
    expect(bookmarks.lastReadSurah, 18);
    expect(bookmarks.lastReadAyah, 45);
    expect(bookmarks.lastScrollOffset, 732.5);
    expect(Hive.box('bookmarks').get('last_scroll_offset'), 732.5);
  });

  testWidgets('daily lesson retains its targeted navigation', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("Today's lesson"));
    await tester.tap(find.text("Today's lesson"));
    expect(tabs, [1]);
    expect(navigation.pending?.surah, lesson.todayLesson.surah);
    expect(navigation.pending?.ayah, lesson.todayLesson.ayah);
  });

  testWidgets('all locales render in light and dark mode', (tester) async {
    for (final lang in homeTranslations.keys) {
      for (final dark in [false, true]) {
        await tester.pumpWidget(subject(lang: lang, dark: dark));
        await tester.pumpAndSettle();
        expect(
          find.text(homeTranslations[lang]!['home_start']!),
          findsOneWidget,
        );
        expect(
          find.text(homeTranslations[lang]!['home_moment']!),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '$lang dark=$dark');
      }
    }
  });

  test('all 114 surahs have offline names', () {
    expect(arabicSurahNames, hasLength(114));
    expect(transliteratedSurahNames, hasLength(114));
    for (var id = 1; id <= 114; id++) {
      expect(surahName(id, 'en'), isNotEmpty);
      expect(surahName(id, 'ar'), isNotEmpty);
    }
    expect(surahName(18, 'ar'), 'الكهف');
    expect(surahName(18, 'ur'), 'الكهف');
    expect(surahName(18, 'en'), 'Al-Kahf');
  });

  testWidgets('large text stays readable on narrow screens in every locale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final lang in homeTranslations.keys) {
      await tester.pumpWidget(subject(lang: lang, scale: 2));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(AppLocalizations(Locale(lang)).ruleQuiz),
        250,
      );
      expect(tester.takeException(), isNull, reason: lang);
    }
  });

  testWidgets('Arabic reading card shows the name and no fire', (tester) async {
    await tester.runAsync(
      () => bookmarks.saveLastRead(18, 45, scrollOffset: 732.5),
    );
    await tester.pumpWidget(subject(lang: 'ar'));
    await tester.pumpAndSettle();
    expect(find.text('الكهف'), findsOneWidget);
    expect(find.text('المزمل · آية 4'), findsOneWidget);
    expect(find.text('🔥'), findsNothing);
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('home_reading_card'))),
      ),
      TextDirection.rtl,
    );
  });
}
