import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/theme/app_theme.dart';
import 'package:tajweed_practice/features/reader/memorization_screen.dart';

/// Real screen capture with a small local Quran fixture; no voice or API use.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const language = String.fromEnvironment(
    'SCREENSHOT_LOCALE',
    defaultValue: 'en',
  );
  final l10n = AppLocalizations(const Locale(language));
  const texts = [
    'قُلْ هُوَ اللَّهُ أَحَدٌ',
    'اللَّهُ الصَّمَدُ',
    'لَمْ يَلِدْ وَلَمْ يُولَدْ',
    'وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
  ];
  final ayahs = [
    for (var i = 0; i < texts.length; i++)
      Ayah(
        surahNumber: 112,
        ayahNumber: i + 1,
        pageNumber: 604,
        juzNumber: 30,
        arabic: texts[i],
        imlaei: texts[i],
        translations: const {},
        words: [
          for (final word in texts[i].split(' '))
            TajweedWord(arabic: word, spans: const []),
        ],
      ),
  ];

  testWidgets('capture surah memorization and non-voice hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        home: MemorizationScreen(
          ayahs: ayahs,
          surahNameFor: (_) => 'الإخلاص',
          playReference: (_) async => false,
          stopReference: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      find.text('${l10n.get('ayah')} ${l10n.digits(1)} / ${l10n.digits(4)}'),
      findsOneWidget,
    );
    expect(find.text('${l10n.get('juz')} ${l10n.digits(30)}'), findsOneWidget);
    await binding.takeScreenshot('surah-memorization');
    await tester.ensureVisible(find.text(l10n.get('hifz_hint')));
    await tester.tap(find.text(l10n.get('hifz_hint')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('surah-memorization-hint');
  });
}
