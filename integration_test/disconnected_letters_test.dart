import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/memorization_speech_service.dart';
import 'package:tajweed_practice/features/reader/memorization_screen.dart';
import 'package:tajweed_practice/features/reader/mushaf_page_view.dart';

class _ControlledSpeech implements MemorizationSpeechInput {
  late void Function(String, bool) result;

  @override
  Future<void> start({
    required void Function(String, bool) onResult,
    required void Function() onDone,
    required void Function(String) onError,
  }) async {
    result = onResult;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const openings = {
    '2:1': ('الم', '1000 لام ميم'),
    '3:1': ('الم', 'ألف لام ميم'),
    '7:1': ('المص', 'ألف لام ميم صاد'),
    '10:1': ('الر', 'ألف لام را'),
    '11:1': ('الر', 'ألف لام راء'),
    '12:1': ('الر', 'ألف لام را'),
    '13:1': ('المر', 'ألف لام ميم را'),
    '14:1': ('الر', 'ألف لام را'),
    '15:1': ('الر', 'ألف لام را'),
    '19:1': ('كهيعص', 'كاف هاء ياء عين صاد'),
    '20:1': ('طه', 'طاء هاء'),
    '26:1': ('طسم', 'طا سين ميم'),
    '27:1': ('طس', 'طا سين'),
    '28:1': ('طسم', 'طا سين ميم'),
    '29:1': ('الم', '١٠٠٠ لام ميم'),
    '30:1': ('الم', 'الف لام ميم'),
    '31:1': ('الم', 'ألف لام ميم'),
    '32:1': ('الم', 'ألف لام ميم'),
    '36:1': ('يس', 'يا سين'),
    '38:1': ('ص', 'صاد'),
    '40:1': ('حم', 'حاء ميم'),
    '41:1': ('حم', 'حا ميم'),
    '42:1': ('حم', 'حا ميم'),
    '42:2': ('عسق', 'عين سين قاف'),
    '43:1': ('حم', 'حا ميم'),
    '44:1': ('حم', 'حا ميم'),
    '45:1': ('حم', 'حا ميم'),
    '46:1': ('حم', 'حا ميم'),
    '50:1': ('ق', 'قاف'),
    '68:1': ('ن', 'نون'),
  };

  for (final continuous in [true, false]) {
    testWidgets('all disconnected-letter positions reveal ($continuous)', (
      tester,
    ) async {
      for (final entry in openings.entries) {
        final numbers = entry.key.split(':').map(int.parse).toList();
        final (written, spoken) = entry.value;
        final speech = _ControlledSpeech();
        final ayah = Ayah(
          surahNumber: numbers[0],
          ayahNumber: numbers[1],
          pageNumber: 1,
          juzNumber: 1,
          arabic: written,
          imlaei: written,
          translations: const {},
          words: [TajweedWord(arabic: written, spans: const [], lineNumber: 1)],
          endLineNumber: 1,
        );
        // Synthetic single-line fixtures exercise matching, not printed-page
        // fidelity or native microphone recognition.
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$continuous:${entry.key}'),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MemorizationScreen(
              continuous: continuous,
              ayahs: [ayah],
              speechInput: speech,
              surahNameFor: (_) => '${numbers[0]}',
              playReference: (_) async => false,
              stopReference: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final start = find.text(continuous ? 'Start reciting' : 'Recite ayah');
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agree and continue'));
        await tester.pumpAndSettle();
        speech.result(spoken, false);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MushafPageContent>(find.byType(MushafPageContent))
              .hiddenAyahs,
          contains(entry.key),
          reason: 'Partial recognition must not reveal ${entry.key}',
        );
        speech.result(spoken, true);
        await tester.pumpAndSettle();
        final page = tester.widget<MushafPageContent>(
          find.byType(MushafPageContent),
        );
        expect(page.hiddenAyahs, isEmpty, reason: entry.key);
        expect(page.ayahs.single.arabic, written, reason: entry.key);
      }
    });
  }
}
