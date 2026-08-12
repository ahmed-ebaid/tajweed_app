import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_practice/core/providers/bookmark_provider.dart';
import 'package:tajweed_practice/core/providers/daily_lesson_provider.dart';
import 'package:tajweed_practice/core/providers/locale_provider.dart';
import 'package:tajweed_practice/core/providers/quiz_progress_provider.dart';
import 'package:tajweed_practice/core/providers/reader_navigation_provider.dart';
import 'package:tajweed_practice/core/providers/recitation_provider.dart';
import 'package:tajweed_practice/core/providers/streak_provider.dart';
import 'package:tajweed_practice/core/providers/tafseer_provider.dart';
import 'package:tajweed_practice/core/services/quran_api_service.dart';
import 'package:tajweed_practice/features/quiz/quiz_screen.dart';
import 'package:tajweed_practice/features/reader/reader_screen.dart';
import 'package:tajweed_practice/features/reader/widgets/tafseer_sheet.dart';
import 'package:tajweed_practice/features/rules/rule_detail_screen.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/rules_screen.dart';
import 'package:tajweed_practice/features/settings/settings_screen.dart';
import 'package:tajweed_practice/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture App Store screens', (tester) async {
    await _initializeFixtureStorage();
    final localeProvider = LocaleProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeProvider),
          ChangeNotifierProvider(create: (_) => StreakProvider()),
          ChangeNotifierProvider(create: (_) => BookmarkProvider()),
          ChangeNotifierProvider(create: (_) => DailyLessonProvider()),
          ChangeNotifierProvider(create: (_) => QuizProgressProvider()),
          ChangeNotifierProvider(create: (_) => ReaderNavigationProvider()),
          ChangeNotifierProvider(create: (_) => RecitationProvider()),
          ChangeNotifierProxyProvider<LocaleProvider, TafseerProvider>(
            create: (_) => TafseerProvider(langCode: 'en'),
            update: (_, locale, provider) {
              final value =
                  provider ??
                  TafseerProvider(langCode: locale.locale.languageCode);
              value.syncLanguage(locale.locale.languageCode);
              return value;
            },
          ),
        ],
        child: const TajweedApp(),
      ),
    );
    await _waitForUi(tester);

    await binding.takeScreenshot('01-home');

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await _waitForUi(tester, seconds: 4);
    await binding.takeScreenshot('02-ayah-reader');

    final readerContext = tester.element(find.byType(ReaderScreen));
    showModalBottomSheet<void>(
      context: readerContext,
      isScrollControlled: true,
      builder: (_) => TafseerSheet(
        verseKey: '1:1',
        tafsirId: 169,
        tafsirName: 'Ibn Kathir (Abridged)',
        surahName: 'الفاتحة',
        languageCode: 'en',
        api: _ScreenshotQuranApiService(),
      ),
    );
    await _finishTransition(tester);
    expect(find.byType(TafseerSheet), findsOneWidget);
    await binding.takeScreenshot('03-tafseer');
    Navigator.of(readerContext).pop();
    await _finishTransition(tester);
    expect(find.byType(TafseerSheet), findsNothing);

    await tester.tap(find.byTooltip('Switch to Page view'));
    await _waitForUi(tester, seconds: 3);
    expect(find.byIcon(Icons.view_list_outlined), findsOneWidget);
    await binding.takeScreenshot('04-mushaf');

    await tester.tap(find.byIcon(Icons.quiz_outlined));
    await _waitForUi(tester);
    expect(find.byType(QuizScreen), findsOneWidget);
    await binding.takeScreenshot('05-quiz');

    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await _waitForUi(tester);
    expect(find.byType(RulesScreen), findsOneWidget);
    await binding.takeScreenshot('06-rules-library');

    final navigator = Navigator.of(readerContext);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RuleDetailScreen(definition: RulesRepository.all.first),
      ),
    );
    await _finishTransition(tester);
    expect(find.byType(RuleDetailScreen), findsOneWidget);
    await binding.takeScreenshot('07-rule-detail');

    navigator.pop();
    await _finishTransition(tester);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    await _finishTransition(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await binding.takeScreenshot('08-settings');
  });
}

Future<void> _waitForUi(WidgetTester tester, {int seconds = 2}) async {
  await tester.pump();
  await tester.pump(Duration(seconds: seconds));
}

Future<void> _finishTransition(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _ScreenshotQuranApiService extends QuranApiService {
  @override
  Future<List<Map<String, dynamic>>> fetchAvailableTafsirs() async {
    return const [
      {
        'id': 169,
        'name': 'Ibn Kathir (Abridged)',
        'author_name': 'Hafiz Ibn Kathir',
        'language_name': 'english',
      },
    ];
  }
}

Future<void> _initializeFixtureStorage() async {
  await Hive.initFlutter('app_store_screenshots');
  for (final name in [
    'settings',
    'streak',
    'verse_cache',
    'bookmarks',
    'audio_cache',
  ]) {
    final box = await Hive.openBox(name);
    await box.clear();
  }

  await Hive.box('settings').put('reader_surah_list_en', [
    {
      'id': 1,
      'name_simple': 'Al-Fatihah',
      'name_arabic': 'الفاتحة',
      'verses_count': 7,
      'translated_name': {'name': 'The Opener'},
    },
  ]);
  await Hive.box('verse_cache').put('quran_ar_surah_1', _alFatihahFixture);
  await Hive.box(
    'verse_cache',
  ).put('quran_tajweed_surah_1', <String, String>{});
  await Hive.box('verse_cache').put('tafsir_169_surah_1', {
    '1:1':
        'In the opening of the Quran, the servant begins by remembering God, '
        'seeking His mercy, and recognizing that every blessing comes from Him.',
  });
}

const _alFatihahFixture = <Map<String, dynamic>>[
  {
    'verse_key': '1:1',
    'text_uthmani': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    'page_number': 1,
    'juz_number': 1,
    'hizb_number': 1,
    'rub_el_hizb_number': 1,
    'translations': [
      {
        'resource_id': 85,
        'text': 'In the name of God, the Lord of Mercy, the Giver of Mercy!',
      },
    ],
    'words': [
      {
        'char_type_name': 'word',
        'text_uthmani': 'بِسْمِ',
        'text_uthmani_tajweed': 'بِسۡمِ',
        'translation': {'text': 'In the name'},
      },
      {
        'char_type_name': 'word',
        'text_uthmani': 'ٱللَّهِ',
        'text_uthmani_tajweed': '<rule class=ham_wasl>ٱ</rule>للَّهِ',
        'translation': {'text': 'of God'},
      },
      {
        'char_type_name': 'word',
        'text_uthmani': 'ٱلرَّحْمَـٰنِ',
        'text_uthmani_tajweed':
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>رَّحۡمَ<rule class=madda_normal>ـٰ</rule>نِ',
        'translation': {'text': 'the Lord of Mercy'},
      },
      {
        'char_type_name': 'word',
        'text_uthmani': 'ٱلرَّحِيمِ',
        'text_uthmani_tajweed':
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>رَّح<rule class=madda_permissible>ِي</rule>مِ',
        'translation': {'text': 'the Giver of Mercy'},
      },
    ],
  },
  {
    'verse_key': '1:2',
    'text_uthmani': 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ',
    'page_number': 1,
    'juz_number': 1,
    'hizb_number': 1,
    'rub_el_hizb_number': 1,
    'translations': [
      {'resource_id': 85, 'text': 'Praise belongs to God, Lord of the Worlds,'},
    ],
    'words': [
      {
        'char_type_name': 'word',
        'text_uthmani': 'ٱلْحَمْدُ',
        'text_uthmani_tajweed': 'ٱلۡحَمۡدُ',
        'translation': {'text': 'Praise belongs'},
      },
      {
        'char_type_name': 'word',
        'text_uthmani': 'لِلَّهِ',
        'text_uthmani_tajweed': 'لِلَّهِ',
        'translation': {'text': 'to God'},
      },
      {
        'char_type_name': 'word',
        'text_uthmani': 'رَبِّ',
        'text_uthmani_tajweed': 'رَبِّ',
        'translation': {'text': 'Lord'},
      },
      {
        'char_type_name': 'word',
        'text_uthmani': 'ٱلْعَـٰلَمِينَ',
        'text_uthmani_tajweed':
            '<rule class=ham_wasl>ٱ</rule>لۡعَ<rule class=madda_normal>ـٰ</rule>لَم<rule class=madda_permissible>ِي</rule>نَ',
        'translation': {'text': 'of the Worlds'},
      },
    ],
  },
  {
    'verse_key': '1:3',
    'text_uthmani': 'ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    'page_number': 1,
    'juz_number': 1,
    'hizb_number': 1,
    'rub_el_hizb_number': 1,
    'translations': [
      {'resource_id': 85, 'text': 'the Lord of Mercy, the Giver of Mercy,'},
    ],
    'words': [
      {
        'char_type_name': 'word',
        'text_uthmani': 'ٱلرَّحْمَـٰنِ',
        'text_uthmani_tajweed':
            'ٱ<rule class=laam_shamsiyah>ل</rule>رَّحۡمَ<rule class=madda_normal>ـٰ</rule>نِ',
        'translation': {'text': 'the Lord of Mercy'},
      },
      {
        'char_type_name': 'word',
        'text_uthmani': 'ٱلرَّحِيمِ',
        'text_uthmani_tajweed':
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>رَّح<rule class=madda_permissible>ِي</rule>مِ',
        'translation': {'text': 'the Giver of Mercy'},
      },
    ],
  },
];
