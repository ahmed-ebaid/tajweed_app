import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_practice/core/providers/bookmark_provider.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/providers/daily_lesson_provider.dart';
import 'package:tajweed_practice/core/providers/locale_provider.dart';
import 'package:tajweed_practice/core/providers/quiz_progress_provider.dart';
import 'package:tajweed_practice/core/providers/reader_navigation_provider.dart';
import 'package:tajweed_practice/core/providers/recitation_provider.dart';
import 'package:tajweed_practice/core/providers/streak_provider.dart';
import 'package:tajweed_practice/core/providers/tafseer_provider.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';
import 'package:tajweed_practice/features/reader/widgets/word_detail_sheet.dart';
import 'package:tajweed_practice/main.dart';

class _FixtureLessonProvider extends DailyLessonProvider {
  @override
  DailyLesson get todayLesson => DailyLesson.forDate(DateTime(2026, 1, 2));
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home lesson opens focused example, details, and dismisses', (
    tester,
  ) async {
    await Hive.initFlutter('daily_lesson_focus_test');
    for (final name in [
      'settings',
      'streak',
      'verse_cache',
      'bookmarks',
      'audio_cache',
    ]) {
      final box = await Hive.openBox<dynamic>(name);
      await box.clear();
    }
    final settings = Hive.box('settings');
    await settings.put('locale', 'en');
    await settings.put('onboarding_dismissed', true);
    await settings.put('seasonal_icon_enabled', false);
    await settings.put('reader_surah_list_en', [
      {
        'id': 105,
        'name_simple': 'Al-Fil',
        'name_arabic': 'الفيل',
        'verses_count': 5,
        'translated_name': {'name': 'The Elephant'},
      },
    ]);
    final words = [
      'تَرۡمِيه<rule class=ikhafa_shafawi>ِم</rule>',
      '<rule class=ikhafa_shafawi>ب</rule>ِحِجَارَ<rule class=idgham_ghunnah>ةٍ</rule>',
      '<rule class=idgham_ghunnah>م</rule>ِّ<rule class=ikhafa>ن</rule>',
      '<rule class=ikhafa>س</rule>ِجّ<rule class=madda_permissible>ِي</rule>لٍ',
    ];
    final plain = ['تَرۡمِيهِم', 'بِحِجَارَةٍ', 'مِّن', 'سِجِّيلٍ'];
    await Hive.box('verse_cache').put('quran_ar_surah_105', [
      {
        'verse_key': '105:4',
        'page_number': 601,
        'text_uthmani': plain.join(' '),
        'words': List.generate(
          words.length,
          (index) => {
            'char_type_name': 'word',
            'text_uthmani': plain[index],
            'text_uthmani_tajweed': words[index],
          },
        ),
      },
    ]);
    await Hive.box('bookmarks').put('last_surah', 105);
    await Hive.box('bookmarks').put('last_ayah', 4);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => StreakProvider()),
          ChangeNotifierProvider(create: (_) => BookmarkProvider()),
          ChangeNotifierProvider<DailyLessonProvider>(
            create: (_) => _FixtureLessonProvider(),
          ),
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
    await _waitFor(tester, find.text("Today's lesson"));
    await tester.ensureVisible(find.text("Today's lesson"));
    await tester.tap(find.text("Today's lesson"));
    await _waitFor(tester, find.byKey(const Key('daily_lesson_focus')));
    final text = tester.widget<TajweedText>(find.byType(TajweedText).first);
    expect(text.lessonWordIndices, {0, 1});
    await tester.ensureVisible(find.byKey(const Key('open_daily_lesson_rule')));
    await tester.tap(find.byKey(const Key('open_daily_lesson_rule')));
    await _waitFor(tester, find.byType(WordDetailSheet));
    Navigator.of(tester.element(find.byType(WordDetailSheet))).pop();
    await tester.pump(const Duration(seconds: 1));
    final richText = find.descendant(
      of: find.byType(TajweedText).first,
      matching: find.byType(RichText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(richText);
    final boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 7),
    );
    await tester.tapAt(paragraph.localToGlobal(boxes.first.toRect().center));
    await _waitFor(tester, find.byType(WordDetailSheet));
    expect(
      tester.widget<WordDetailSheet>(find.byType(WordDetailSheet)).rule,
      TajweedRule.ikhfaShafawi,
    );
    Navigator.of(tester.element(find.byType(WordDetailSheet))).pop();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('dismiss_daily_lesson')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('daily_lesson_focus')), findsNothing);
    expect(
      tester
          .widget<TajweedText>(find.byType(TajweedText).first)
          .lessonWordIndices,
      isEmpty,
    );
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text("Today's lesson"));
    await _waitFor(tester, find.byKey(const Key('daily_lesson_focus')));
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('daily_lesson_focus')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await Hive.close();
  });
}
