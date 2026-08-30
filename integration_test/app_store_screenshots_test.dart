import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
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
import 'package:tajweed_practice/features/reader/widgets/word_detail_sheet.dart';
import 'package:tajweed_practice/features/rules/rule_detail_screen.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/rules_screen.dart';
import 'package:tajweed_practice/features/settings/language_selector_screen.dart';
import 'package:tajweed_practice/features/settings/settings_screen.dart';
import 'package:tajweed_practice/main.dart';

const _screenshotLanguageCode = String.fromEnvironment(
  'SCREENSHOT_LOCALE',
  defaultValue: 'en',
);
const _onboardingAssetsOnly = bool.fromEnvironment('ONBOARDING_ASSETS_ONLY');
const _releaseListingAssetsOnly = bool.fromEnvironment(
  'RELEASE_LISTING_ASSETS_ONLY',
);
const _releaseScreenshotLocales = [
  'en',
  'ar',
  'ur',
  'tr',
  'fr',
  'id',
  'de',
  'es',
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture App Store screens', (tester) async {
    if (_releaseListingAssetsOnly) {
      await _captureLocalizedReleasePages(tester, binding);
      return;
    }

    await _initializeFixtureStorage(_screenshotLanguageCode);
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
            create: (_) => TafseerProvider(langCode: _screenshotLanguageCode),
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

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await _waitForUi(tester, seconds: _onboardingAssetsOnly ? 3 : 35);
    await binding.takeScreenshot('02-ayah-reader');

    final readerContext = tester.element(find.byType(ReaderScreen));
    showModalBottomSheet<void>(
      context: readerContext,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => WordDetailSheet(
        rule: TajweedRule.maddTabeei,
        word: 'ٱلرَّحْمَـٰنِ',
        ayah: Ayah(
          surahNumber: 1,
          ayahNumber: 1,
          pageNumber: 1,
          arabic: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
          translations: {
            _screenshotLanguageCode: _firstAyahTranslation(
              _screenshotLanguageCode,
            ),
          },
          words: [
            TajweedWord(arabic: 'بِسْمِ', spans: []),
            TajweedWord(arabic: 'ٱللَّهِ', spans: []),
            TajweedWord(
              arabic: 'ٱلرَّحْمَـٰنِ',
              spans: [
                TajweedSpan(start: 9, end: 11, rule: TajweedRule.maddTabeei),
              ],
            ),
            TajweedWord(arabic: 'ٱلرَّحِيمِ', spans: []),
          ],
        ),
      ),
    );
    await _finishTransition(tester);
    expect(find.byType(WordDetailSheet), findsOneWidget);
    await binding.takeScreenshot('09-word-tajweed');
    Navigator.of(readerContext).pop();
    await _finishTransition(tester);

    showModalBottomSheet<void>(
      context: readerContext,
      isScrollControlled: true,
      builder: (_) => TafseerSheet(
        verseKey: '1:1',
        tafsirId: 169,
        tafsirName: _localizedTafsirName(_screenshotLanguageCode),
        surahName: 'الفاتحة',
        languageCode: _screenshotLanguageCode,
        api: _ScreenshotQuranApiService(),
      ),
    );
    await _finishTransition(tester);
    expect(find.byType(TafseerSheet), findsOneWidget);
    await binding.takeScreenshot('03-tafseer');
    Navigator.of(readerContext).pop();
    await _finishTransition(tester);
    expect(find.byType(TafseerSheet), findsNothing);

    await tester.tap(find.byIcon(Icons.chrome_reader_mode_outlined));
    await _waitForUi(tester, seconds: _onboardingAssetsOnly ? 3 : 35);
    expect(find.byType(ReaderScreen), findsOneWidget);
    await binding.takeScreenshot('04-mushaf');

    if (_onboardingAssetsOnly) {
      final mushafPageView = tester.widget<PageView>(find.byType(PageView));
      mushafPageView.controller!.jumpToPage(4);
      await _waitForUi(tester, seconds: 5);
      final hizbMarker = find.byKey(const ValueKey('mushaf-hizb-boundary'));
      expect(hizbMarker, findsOneWidget);
      await tester.tap(hizbMarker);
      await _finishTransition(tester);
      await binding.takeScreenshot('05-hizb-boundary');
      return;
    }

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

    await tester.tap(find.byIcon(Icons.copyright_outlined));
    await _finishTransition(tester);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    navigator.pop();
    await _finishTransition(tester);

    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const LanguageSelectorScreen()),
    );
    await _finishTransition(tester);
    expect(find.byType(LanguageSelectorScreen), findsOneWidget);
    await binding.takeScreenshot('10-languages');
  });
}

Future<void> _captureLocalizedReleasePages(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  for (final languageCode in _releaseScreenshotLocales) {
    await _initializeFixtureStorage(languageCode);
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
          ChangeNotifierProvider(
            create: (_) => TafseerProvider(langCode: languageCode),
          ),
        ],
        child: const TajweedApp(),
      ),
    );
    await _waitForUi(tester);

    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await _waitForUi(tester);
    expect(find.byType(RulesScreen), findsOneWidget);
    await binding.takeScreenshot('$languageCode/06-rules-library');

    Navigator.of(
      tester.element(find.byType(RulesScreen)),
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await _finishTransition(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await binding.takeScreenshot('$languageCode/08-settings');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
}

Future<void> _waitForUi(WidgetTester tester, {int seconds = 2}) async {
  await tester.pump();
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finishTransition(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _ScreenshotQuranApiService extends QuranApiService {
  @override
  Future<List<Map<String, dynamic>>> fetchAvailableTafsirs() async {
    return [
      {
        'id': 169,
        'name': _localizedTafsirName(_screenshotLanguageCode),
        'author_name': _localizedTafsirAuthor(_screenshotLanguageCode),
        'language_name': _localizedLanguageName(_screenshotLanguageCode),
      },
    ];
  }
}

Future<void> _initializeFixtureStorage(String languageCode) async {
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

  await Hive.box('settings').put('locale', languageCode);
  await Hive.box('settings').put('onboarding_dismissed', true);
  await Hive.box('settings').put('reader_juz_list', [
    {
      'juz_number': 1,
      'verse_mapping': {'1': '1-7', '2': '1-141'},
    },
  ]);
  await Hive.box('settings').put('reader_surah_list_$languageCode', [
    {
      'id': 1,
      'name_simple': 'Al-Fatihah',
      'name_arabic': 'الفاتحة',
      'verses_count': 7,
      'translated_name': {
        'name': languageCode == 'ar' ? 'الفاتحة' : 'The Opener',
      },
    },
    {
      'id': 2,
      'name_simple': 'Al-Baqarah',
      'name_arabic': 'البقرة',
      'verses_count': 286,
      'translated_name': {'name': _localizedAlBaqarahName(languageCode)},
    },
  ]);
  await Hive.box(
    'verse_cache',
  ).put('quran_ar_surah_1', _localizedAlFatihahFixture(languageCode));
  await Hive.box(
    'verse_cache',
  ).put('quran_tajweed_surah_1', <String, String>{});
  if (_onboardingAssetsOnly) {
    await _seedPageFiveFixture();
  }
  await Hive.box(
    'verse_cache',
  ).put('tafsir_169_surah_1', {'1:1': _localizedTafsirContent(languageCode)});
}

String _localizedAlBaqarahName(String languageCode) {
  return switch (languageCode) {
    'ar' => 'البقرة',
    'ur' => 'البقرۃ',
    'tr' => 'Bakara',
    'fr' => 'Al-Baqara',
    'id' => 'Al-Baqarah',
    'de' => 'Al-Baqara',
    'es' => 'Al-Báqara',
    _ => 'Al-Baqarah',
  };
}

Future<void> _seedPageFiveFixture() async {
  final response = await Dio().get<Map<String, dynamic>>(
    'https://api.quran.com/api/v4/verses/by_page/5',
    queryParameters: {
      'mushaf': 2,
      'language': 'ar',
      'words': 'true',
      'fields':
          'text_uthmani,page_number,verse_key,juz_number,hizb_number,'
          'rub_el_hizb_number,sajdah_number',
      'word_fields':
          'text_uthmani,text_uthmani_tajweed,tajweed,char_type_name,'
          'line_number,page_number',
      'per_page': 50,
    },
  );
  final verses = List<Map<String, dynamic>>.from(
    response.data?['verses'] as List<dynamic>? ?? const [],
  );
  if (verses.isEmpty) {
    throw StateError('Quran page 5 fixture returned no verses');
  }
  await Hive.box('verse_cache').put('quran_ar_surah_2', verses);
}

String _firstAyahTranslation(String languageCode) {
  if (languageCode == 'ar') return 'بسم الله الرحمن الرحيم';
  return _alFatihahTranslations[languageCode]?.first ??
      'In the name of God, the Lord of Mercy, the Giver of Mercy!';
}

String _localizedTafsirName(String languageCode) =>
    _tafsirNames[languageCode] ?? _tafsirNames['en']!;

String _localizedTafsirAuthor(String languageCode) =>
    _tafsirAuthors[languageCode] ?? _tafsirAuthors['en']!;

String _localizedLanguageName(String languageCode) =>
    _languageNames[languageCode] ?? _languageNames['en']!;

String _localizedTafsirContent(String languageCode) =>
    _tafsirContents[languageCode] ?? _tafsirContents['en']!;

const _tafsirNames = <String, String>{
  'en': 'Ibn Kathir (Abridged)',
  'ar': 'تفسير ابن كثير (مختصر)',
  'ur': 'تفسیر ابن کثیر (مختصر)',
  'tr': 'İbn Kesir Tefsiri (Özet)',
  'fr': 'Tafsir Ibn Kathir (abrégé)',
  'id': 'Tafsir Ibnu Katsir (Ringkas)',
  'de': 'Tafsir Ibn Kathir (gekürzt)',
  'es': 'Tafsir de Ibn Kathir (abreviado)',
};

const _tafsirAuthors = <String, String>{
  'en': 'Hafiz Ibn Kathir',
  'ar': 'الحافظ ابن كثير',
  'ur': 'حافظ ابن کثیر',
  'tr': 'Hafız İbn Kesir',
  'fr': 'Hafiz Ibn Kathir',
  'id': 'Hafiz Ibnu Katsir',
  'de': 'Hafiz Ibn Kathir',
  'es': 'Hafiz Ibn Kathir',
};

const _languageNames = <String, String>{
  'en': 'English',
  'ar': 'العربية',
  'ur': 'اردو',
  'tr': 'Türkçe',
  'fr': 'Français',
  'id': 'Bahasa Indonesia',
  'de': 'Deutsch',
  'es': 'Español',
};

const _tafsirContents = <String, String>{
  'en':
      'In the opening of the Quran, the servant begins by remembering God, '
      'seeking His mercy, and recognizing that every blessing comes from Him.',
  'ar':
      'يفتتح العبد قراءة القرآن بذكر الله، مستعينًا برحمته، ومقرًّا بأن كل '
      'نعمة منه سبحانه.',
  'ur':
      'قرآن کے آغاز میں بندہ اللہ کو یاد کرتا ہے، اس کی رحمت سے مدد چاہتا ہے، '
      'اور اقرار کرتا ہے کہ ہر نعمت اسی کی طرف سے ہے۔',
  'tr':
      'Kur’an’ın başlangıcında kul, Allah’ı anarak, O’nun rahmetine sığınarak '
      've her nimetin O’ndan geldiğini kabul ederek okumaya başlar.',
  'fr':
      'Au début du Coran, le serviteur commence par se rappeler Dieu, implorer '
      'Sa miséricorde et reconnaître que tout bienfait vient de Lui.',
  'id':
      'Pada awal Al-Qur’an, seorang hamba memulai dengan mengingat Allah, '
      'memohon rahmat-Nya, dan mengakui bahwa setiap nikmat berasal dari-Nya.',
  'de':
      'Zu Beginn des Korans erinnert sich der Diener an Gott, bittet um Seine '
      'Barmherzigkeit und erkennt an, dass jede Gabe von Ihm kommt.',
  'es':
      'Al comienzo del Corán, el siervo empieza recordando a Dios, buscando Su '
      'misericordia y reconociendo que toda bendición procede de Él.',
};

List<Map<String, dynamic>> _localizedAlFatihahFixture(String languageCode) {
  final resourceId = int.parse(QuranApiService.translationIdFor(languageCode));
  final translations = _alFatihahTranslations[languageCode];
  return _alFatihahFixture
      .asMap()
      .entries
      .map((entry) {
        final verse = entry.value;
        final localizedVerse = Map<String, dynamic>.from(verse);
        final fixtureTranslations = verse['translations']! as List<dynamic>;
        final translation = Map<String, dynamic>.from(
          fixtureTranslations.first! as Map<dynamic, dynamic>,
        );
        translation['resource_id'] = resourceId;
        if (translations != null) {
          translation['text'] = translations[entry.key];
        }
        localizedVerse['translations'] = [translation];
        return localizedVerse;
      })
      .toList(growable: false);
}

const _alFatihahTranslations = <String, List<String>>{
  'ur': [
    'اللہ کے نام سے جو رحمان و رحیم ہے',
    'تعریف اللہ ہی کے لیے ہے جو تمام کائنات کا رب ہے',
    'رحمان اور رحیم ہے',
    'روز جزا کا مالک ہے',
    'ہم تیری ہی عبادت کرتے ہیں اور تجھی سے مدد مانگتے ہیں',
    'ہمیں سیدھا راستہ دکھا',
    'ان لوگوں کا راستہ جن پر تو نے انعام فرمایا، جو معتوب نہیں ہوئے، جو بھٹکے ہوئے نہیں ہیں',
  ],
  'tr': [
    "Rahmân ve Rahîm olan Allah'ın ismiyle.",
    'Hamd o âlemlerin Rabbi,',
    'O Rahmân ve Rahim,',
    "O, din gününün maliki Allah'ın.",
    'Ancak sana ederiz kulluğu ve ancak senden dileriz yardımı.',
    'Hidayet eyle bizi doğru yola,',
    'O kendilerine nimet verdiğin kimselerin yoluna; gazaba uğramışların ve sapmışların yoluna değil.',
  ],
  'fr': [
    'Au nom d’Allah, le Tout Miséricordieux, le Très Miséricordieux.',
    'Louange à Allah, Seigneur de l’Univers.',
    'Le Tout Miséricordieux, le Très Miséricordieux,',
    'Maître du Jour de la Rétribution.',
    'C’est Toi Seul que nous adorons, et c’est Toi Seul dont nous implorons secours.',
    'Guide-nous dans le droit chemin,',
    'Le chemin de ceux que Tu as comblés de faveurs, non pas de ceux qui ont encouru Ta colère, ni des égarés.',
  ],
  'id': [
    'Dengan nama Allah Yang Maha Pengasih, Maha Penyayang.',
    'Segala puji bagi Allah, Tuhan seluruh alam,',
    'Yang Maha Pengasih, Maha Penyayang,',
    'Pemilik hari pembalasan.',
    'Hanya kepada Engkaulah kami menyembah dan hanya kepada Engkaulah kami mohon pertolongan.',
    'Tunjukilah kami jalan yang lurus,',
    'Jalan orang-orang yang telah Engkau beri nikmat; bukan jalan mereka yang dimurkai dan bukan pula mereka yang sesat.',
  ],
  'de': [
    'Im Namen Allahs, des Allerbarmers, des Barmherzigen.',
    'Alles Lob gehört Allah, dem Herrn der Welten,',
    'dem Allerbarmer, dem Barmherzigen,',
    'dem Herrscher am Tag des Gerichts.',
    'Dir allein dienen wir, und zu Dir allein flehen wir um Hilfe.',
    'Leite uns den geraden Weg,',
    'den Weg derjenigen, denen Du Gunst erwiesen hast, nicht derjenigen, die Deinen Zorn erregt haben, und nicht der Irregehenden!',
  ],
  'es': [
    'En el nombre de Dios, el Compasivo, el Misericordioso.',
    'Todas las alabanzas son para Dios, Señor de todo cuanto existe,',
    'el Compasivo, el Misericordioso.',
    'Soberano absoluto del Día del Juicio Final,',
    'solo a Ti te adoramos y solo de Ti imploramos ayuda.',
    '¡Guíanos por el camino recto!',
    'El camino de los que has colmado con Tus favores, no el de los que han caído en Tu ira, ni el de los que se extraviaron.',
  ],
};

final _alFatihahFixture = <Map<String, dynamic>>[
  _fixtureAyah(
    1,
    arabic: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    translation: 'In the name of God, the Lord of Mercy, the Giver of Mercy!',
    words: [
      _fixtureWord('بِسْمِ', 2, tajweed: 'بِسۡمِ'),
      _fixtureWord(
        'ٱللَّهِ',
        2,
        tajweed: '<rule class=ham_wasl>ٱ</rule>للَّهِ',
      ),
      _fixtureWord(
        'ٱلرَّحْمَـٰنِ',
        2,
        tajweed:
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>رَّحۡمَ<rule class=madda_normal>ـٰ</rule>نِ',
      ),
      _fixtureWord(
        'ٱلرَّحِيمِ',
        2,
        tajweed:
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>رَّح<rule class=madda_permissible>ِي</rule>مِ',
      ),
    ],
  ),
  _fixtureAyah(
    2,
    arabic: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ',
    translation: 'Praise belongs to God, Lord of the Worlds,',
    words: [
      _fixtureWord('ٱلْحَمْدُ', 3, tajweed: 'ٱلۡحَمۡدُ'),
      _fixtureWord('لِلَّهِ', 3),
      _fixtureWord('رَبِّ', 3),
      _fixtureWord(
        'ٱلْعَـٰلَمِينَ',
        3,
        tajweed:
            '<rule class=ham_wasl>ٱ</rule>لۡعَ<rule class=madda_normal>ـٰ</rule>لَم<rule class=madda_permissible>ِي</rule>نَ',
      ),
    ],
  ),
  _fixtureAyah(
    3,
    arabic: 'ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    translation: 'the Lord of Mercy, the Giver of Mercy,',
    words: [
      _fixtureWord(
        'ٱلرَّحْمَـٰنِ',
        4,
        tajweed:
            'ٱ<rule class=laam_shamsiyah>ل</rule>رَّحۡمَ<rule class=madda_normal>ـٰ</rule>نِ',
      ),
      _fixtureWord(
        'ٱلرَّحِيمِ',
        4,
        tajweed:
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>رَّح<rule class=madda_permissible>ِي</rule>مِ',
      ),
    ],
  ),
  _fixtureAyah(
    4,
    arabic: 'مَـٰلِكِ يَوْمِ ٱلدِّينِ',
    translation: 'Master of the Day of Judgment.',
    words: [
      _fixtureWord(
        'مَـٰلِكِ',
        4,
        tajweed: 'مَ<rule class=madda_normal>ـٰ</rule>لِكِ',
      ),
      _fixtureWord('يَوْمِ', 4, tajweed: 'يَوۡمِ'),
      _fixtureWord(
        'ٱلدِّينِ',
        4,
        tajweed:
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>دّ<rule class=madda_permissible>ِي</rule>نِ',
      ),
    ],
  ),
  _fixtureAyah(
    5,
    arabic: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
    translation: 'You alone we worship; You alone we ask for help.',
    words: [
      _fixtureWord('إِيَّاكَ', 5),
      _fixtureWord('نَعْبُدُ', 5, tajweed: 'نَعۡبُدُ'),
      _fixtureWord('وَإِيَّاكَ', 5),
      _fixtureWord(
        'نَسْتَعِينُ',
        5,
        tajweed: 'نَسۡتَع<rule class=madda_permissible>ِي</rule>نُ',
      ),
    ],
  ),
  _fixtureAyah(
    6,
    arabic: 'ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ',
    translation: 'Guide us to the straight path:',
    words: [
      _fixtureWord('ٱهْدِنَا', 5, tajweed: 'ٱهۡدِنَا'),
      _fixtureWord(
        'ٱلصِّرَٰطَ',
        6,
        tajweed:
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>صِّر<rule class=madda_normal><rule class=custom-alef-maksora>ٰ</rule></rule>طَ',
      ),
      _fixtureWord(
        'ٱلْمُسْتَقِيمَ',
        6,
        tajweed:
            '<rule class=ham_wasl>ٱ</rule>لۡمُسۡتَق<rule class=madda_permissible>ِي</rule>مَ',
      ),
    ],
  ),
  _fixtureAyah(
    7,
    arabic:
        'صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ',
    translation:
        'the path of those You have blessed, those who incur no anger and who have not gone astray.',
    words: [
      _fixtureWord(
        'صِرَٰطَ',
        6,
        tajweed:
            'صِر<rule class=madda_normal><rule class=custom-alef-maksora>ٰ</rule></rule>طَ',
      ),
      _fixtureWord(
        'ٱلَّذِينَ',
        6,
        tajweed: '<rule class=ham_wasl>ٱ</rule>لَّذِينَ',
      ),
      _fixtureWord('أَنْعَمْتَ', 6, tajweed: 'أَنۡعَمۡتَ'),
      _fixtureWord('عَلَيْهِمْ', 7, tajweed: 'عَلَيۡهِمۡ'),
      _fixtureWord('غَيْرِ', 7, tajweed: 'غَيۡرِ'),
      _fixtureWord(
        'ٱلْمَغْضُوبِ',
        7,
        tajweed: '<rule class=ham_wasl>ٱ</rule>لۡمَغۡضُوبِ',
      ),
      _fixtureWord('عَلَيْهِمْ', 7, tajweed: 'عَلَيۡهِمۡ'),
      _fixtureWord('وَلَا', 8),
      _fixtureWord(
        'ٱلضَّآلِّينَ',
        8,
        tajweed:
            '<rule class=ham_wasl>ٱ</rule><rule class=laam_shamsiyah>ل</rule>ضّ<rule class=madda_necessary>َا</rule>ٓلّ<rule class=madda_permissible>ِي</rule>نَ',
      ),
    ],
  ),
];

Map<String, dynamic> _fixtureAyah(
  int ayahNumber, {
  required String arabic,
  required String translation,
  required List<Map<String, dynamic>> words,
}) {
  return {
    'verse_key': '1:$ayahNumber',
    'text_uthmani': arabic,
    'page_number': 1,
    'juz_number': 1,
    'hizb_number': 1,
    'rub_el_hizb_number': 1,
    'translations': [
      {'resource_id': 85, 'text': translation},
    ],
    'words': words,
  };
}

Map<String, dynamic> _fixtureWord(
  String arabic,
  int lineNumber, {
  String? tajweed,
}) {
  return {
    'char_type_name': 'word',
    'text_uthmani': arabic,
    'text_uthmani_tajweed': tajweed ?? arabic,
    'line_number': lineNumber,
    'translation': {'text': arabic},
  };
}
