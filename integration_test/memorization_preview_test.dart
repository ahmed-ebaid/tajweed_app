import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/core/services/memorization_speech_service.dart';
import 'package:tajweed_practice/core/theme/app_theme.dart';
import 'package:tajweed_practice/features/reader/memorization_screen.dart';

/// Replays a scripted recitation so the capture shows Hifz following along.
class _ScriptedSpeech implements WindowedMemorizationSpeechInput {
  void Function(String, bool)? result;

  @override
  double windowStartSeconds = 0;

  @override
  Future<void> start({
    required void Function(String, bool) onResult,
    required void Function() onDone,
    required void Function(String) onError,
  }) async => result = onResult;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> stop() async {}
}

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

  testWidgets('capture Hifz following a recitation', (tester) async {
    final response = await Dio().get<Map<String, dynamic>>(
      'https://api.quran.com/api/v4/verses/by_page/562',
      queryParameters: {
        'mushaf': 2,
        'language': 'ar',
        'words': 'true',
        'fields':
            'text_uthmani,text_imlaei,page_number,verse_key,juz_number,'
            'hizb_number,rub_el_hizb_number,sajdah_number',
        'word_fields':
            'text_uthmani,text_imlaei,text_uthmani_tajweed,tajweed,'
            'char_type_name,line_number,page_number',
        'per_page': 50,
      },
    );
    final page = AyahMapper.fromApiList(
      List<Map<String, dynamic>>.from(
        response.data?['verses'] as List<dynamic>? ?? const [],
      ),
      requestedLangCode: 'ar',
    );
    final mulk = page.where((ayah) => ayah.surahNumber == 67).toList();
    expect(mulk, isNotEmpty);
    String spoken(int i) => mulk[i].imlaei ?? mulk[i].plainArabicText();
    final third = spoken(2).split(' ');
    final speech = _ScriptedSpeech();
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
          ayahs: mulk,
          loadPage: (_) async => page,
          continuous: true,
          localQuranLab: true,
          mistakeAlerts: false,
          speechInput: speech,
          surahNameFor: (_) => 'الملك',
          playReference: (_) async => false,
          stopReference: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.get('hifz_start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.get('mem_agree')));
    await tester.pumpAndSettle();
    expect(speech.result, isNotNull);
    var start = 0.0;
    for (final window in [
      spoken(0),
      '${spoken(0)} ${spoken(1)}',
      '${spoken(1)} ${third.take(third.length ~/ 2).join(' ')}',
    ]) {
      speech.windowStartSeconds = start;
      start += 2;
      speech.result!(window, false);
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('hifz-follow-along');
  });
}
