import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/memorization_speech_service.dart';
import 'package:tajweed_practice/core/services/quran_asr_speech_input.dart';
import 'package:tajweed_practice/features/reader/memorization_screen.dart';
import 'package:tajweed_practice/features/reader/mushaf_page_view.dart';

class _FakeSpeech implements MemorizationSpeechInput {
  int starts = 0;
  int cancellations = 0;
  Future<void>? pendingStart;
  Future<void>? pendingStop;
  void Function(String, bool)? result;
  void Function(String)? error;
  void Function()? done;
  void Function()? stopping;

  @override
  Future<void> start({
    required void Function(String, bool) onResult,
    required void Function() onDone,
    required void Function(String) onError,
  }) async {
    starts++;
    result = onResult;
    error = onError;
    done = onDone;
    await pendingStart;
  }

  @override
  Future<void> cancel() async => cancellations++;

  @override
  Future<void> stop() async {
    stopping?.call();
    await pendingStop;
  }
}

class _FakeWindowedSpeech extends _FakeSpeech
    implements WindowedMemorizationSpeechInput {
  @override
  double windowStartSeconds = 0;
}

Ayah _ayah(
  int number,
  String text, {
  bool referenceAvailable = true,
  int pageNumber = 1,
  int surahNumber = 1,
}) => Ayah(
  surahNumber: surahNumber,
  ayahNumber: number,
  pageNumber: pageNumber,
  juzNumber: 1,
  arabic: text,
  imlaei: referenceAvailable ? text : null,
  translations: const {},
  words: [TajweedWord(arabic: text, spans: const [], lineNumber: number)],
  endLineNumber: number,
);

const _first = 'بسم الله الرحمن الرحيم';
const _second = 'الحمد لله رب العالمين';

Future<void> _open(
  WidgetTester tester,
  MemorizationSpeechInput speech, {
  Locale locale = const Locale('en'),
  bool referenceAvailable = true,
  Future<bool> Function(Ayah)? playReference,
  Future<void> Function()? stopReference,
  List<Ayah>? ayahs,
  bool continuous = false,
  bool review = false,
  bool localQuranLab = false,
  Future<List<Ayah>> Function(int)? loadPage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MemorizationScreen(
        continuous: continuous,
        review: review,
        localQuranLab: localQuranLab,
        loadPage: loadPage,
        ayahs:
            ayahs ??
            [
              _ayah(1, _first, referenceAvailable: referenceAvailable),
              _ayah(2, _second),
            ],
        speechInput: speech,
        surahNameFor: (_) => 'الفاتحة',
        playReference: playReference ?? (_) async => true,
        stopReference: stopReference ?? () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _start(WidgetTester tester) async {
  await _tap(tester, 'Recite ayah');
  await _tap(tester, 'Agree and continue');
}

Set<String> _hidden(WidgetTester tester) => tester
    .widget<MushafPageContent>(find.byType(MushafPageContent))
    .hiddenAyahs;

void main() {
  if (quranAsrExperimentEnabled) {
    for (final locale in [const Locale('ar'), const Locale('en')]) {
      testWidgets(
        'Mushaf swipes forward to the right in ${locale.languageCode}',
        (tester) async {
          final speech = _FakeSpeech();
          final l10n = AppLocalizations(locale);
          await _open(
            tester,
            speech,
            locale: locale,
            continuous: true,
            localQuranLab: true,
            ayahs: [
              _ayah(1, _first, pageNumber: 1),
              _ayah(2, _second, pageNumber: 1),
              _ayah(3, _first, pageNumber: 2),
              _ayah(4, _second, pageNumber: 2),
            ],
          );

          await tester.fling(
            find.byType(MushafPageContent),
            const Offset(300, 0),
            1000,
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              '${l10n.get('ayah')} ${l10n.digits(3)} / ${l10n.digits(4)}',
            ),
            findsOneWidget,
          );

          await tester.fling(
            find.byType(MushafPageContent),
            const Offset(-300, 0),
            1000,
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              '${l10n.get('ayah')} ${l10n.digits(1)} / ${l10n.digits(4)}',
            ),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets(
      'alignment diagnostics distinguish mismatch tail recovery and revealed words',
      (tester) async {
        const channel = MethodChannel(
          'com.ebaidllc.tajweed_practice/quran_asr',
        );
        final records = <Map<dynamic, dynamic>>[];
        var transcript = 'بسم الله الرحمن';
        final binding = TestDefaultBinaryMessengerBinding.instance;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          if (call.method == 'traceProgress') {
            records.add(call.arguments as Map<dynamic, dynamic>);
          }
          return switch (call.method) {
            'available' => true,
            'preview' || 'check' => {
              'transcript': transcript,
              'durationSeconds': 4.0,
              'inferenceSeconds': 0.3,
              'windowStartSeconds': 0.0,
            },
            _ => null,
          };
        });
        addTearDown(() {
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        });
        await _open(
          tester,
          QuranAsrSpeechInput(),
          continuous: true,
          localQuranLab: true,
        );
        await _tap(tester, 'Start reciting');
        await _tap(tester, 'Agree and continue');
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(records.last['visibleWords'], 3);
        transcript = 'بسم الله الرحمن العليم';
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(records.last['rawMismatch'], 1);
        expect(records.last['rawWordIndex'], 3);
        expect(records.last['cursorWords'], 3);
        expect(records.last['displayedBefore'], 3);
        expect(records.last['visibleWords'], 3);
        transcript = 'الرحيم';
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(records.last['cursorRawPrefix'], 0);
        expect(records.last['cursorTailPrefix'], 4);
        expect(records.last['visibleWords'], 4);
        transcript = '$_first $_second';
        await _tap(tester, 'Pause');
        expect(records.last['final'], 1);
        expect(records.last['rawCompleted'], 2);
        expect(records.last['visibleWords'], 8);
        expect(records.last.values, everyElement(isA<num>()));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    for (final previewEnabled in [true, false]) {
      testWidgets(
        'rolling recitation continues beyond two minutes with preview $previewEnabled',
        (tester) async {
          const channel = MethodChannel(
            'com.ebaidllc.tajweed_practice/quran_asr',
          );
          final calls = <String>[];
          var text = '$_first الحمد لله';
          var windowStart = 0.0;
          final binding = TestDefaultBinaryMessengerBinding.instance;
          binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
            call,
          ) async {
            calls.add(call.method);
            return switch (call.method) {
              'available' => true,
              'preview' || 'check' => {
                'transcript': text,
                'durationSeconds': 30.0,
                'inferenceSeconds': 0.3,
                'windowStartSeconds': windowStart,
              },
              _ => null,
            };
          });
          addTearDown(() {
            binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              null,
            );
          });
          await _open(
            tester,
            QuranAsrSpeechInput(),
            continuous: true,
            localQuranLab: true,
            ayahs: [
              _ayah(1, _first),
              _ayah(2, _second),
              _ayah(3, 'الرحمن الرحيم', pageNumber: 2),
              _ayah(4, 'مالك يوم الدين', pageNumber: 2),
            ],
          );
          if (!previewEnabled) {
            await _tap(tester, 'Live word preview (unverified)');
          }
          await _tap(tester, 'Start reciting');
          await _tap(tester, 'Agree and continue');
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          for (final (offset, transcript, expected) in [
            (
              1.0,
              'الله الرحمن الرحيم $_second الرحمن',
              {'1:1': 4, '1:2': 4, '1:3': 1},
            ),
            (
              31.0,
              'لله رب العالمين الرحمن العليم',
              {'1:1': 4, '1:2': 4, '1:3': 1},
            ),
            (61.0, 'مالك يوم الدين', {'1:1': 4, '1:2': 4, '1:3': 1}),
            (
              91.0,
              'رب العالمين الرحمن الرحيم مالك يوم',
              {'1:1': 4, '1:2': 4, '1:3': 2, '1:4': 2},
            ),
            (
              121.0,
              'الرحمن الرحيم مالك يوم الدين',
              {'1:1': 4, '1:2': 4, '1:3': 2, '1:4': 3},
            ),
          ]) {
            windowStart = offset;
            text = transcript;
            await tester.pump(const Duration(seconds: 31));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<MushafPageContent>(find.byType(MushafPageContent))
                  .revealedWordCounts,
              previewEnabled ? expected : isEmpty,
            );
            expect(
              tester
                  .widget<MushafPageContent>(find.byType(MushafPageContent))
                  .pageNumber,
              previewEnabled ? 2 : 1,
            );
            expect(
              find.text('Unaided matches: 0 · Assisted: 0'),
              findsOneWidget,
            );
            expect(calls, isNot(contains('finishCapture')));
            expect(calls, isNot(contains('check')));
          }
          expect(calls.where((method) => method == 'start'), hasLength(1));
          await _tap(tester, 'Pause');
          expect(
            tester
                .widget<MushafPageContent>(find.byType(MushafPageContent))
                .hiddenAyahs,
            isEmpty,
          );
          expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
          expect(
            calls.where((method) => method == 'finishCapture'),
            hasLength(1),
          );
          expect(calls.where((method) => method == 'check'), hasLength(1));
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }

    testWidgets(
      'lab microphone snapshots reveal live words by default without credit',
      (tester) async {
        const channel = MethodChannel(
          'com.ebaidllc.tajweed_practice/quran_asr',
        );
        final calls = <String>[];
        final binding = TestDefaultBinaryMessengerBinding.instance;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          calls.add(call.method);
          return switch (call.method) {
            'available' => true,
            'preview' => {
              'transcript': 'بسم الله',
              'durationSeconds': 3.0,
              'inferenceSeconds': 0.3,
              'windowStartSeconds': 0.0,
            },
            'check' => {
              'transcript': _first,
              'durationSeconds': 4.0,
              'inferenceSeconds': 0.4,
              'windowStartSeconds': 0.0,
            },
            _ => null,
          };
        });
        addTearDown(() {
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        });
        await _open(
          tester,
          QuranAsrSpeechInput(),
          continuous: true,
          localQuranLab: true,
          ayahs: [
            for (final (index, text) in [_first, _second].indexed)
              Ayah(
                surahNumber: 1,
                ayahNumber: index + 1,
                pageNumber: 1,
                arabic: text,
                imlaei: text,
                translations: const {},
                words: [
                  for (final word in text.split(' '))
                    TajweedWord(
                      arabic: word,
                      spans: const [],
                      lineNumber: index + 1,
                    ),
                ],
                endLineNumber: index + 1,
              ),
          ],
        );
        await _tap(tester, 'Start reciting');
        expect(find.textContaining('AI Lab only'), findsWidgets);
        expect(
          find.textContaining('six audio snapshots'),
          quranAsrRetainDebugAudio ? findsOneWidget : findsNothing,
        );
        await _tap(tester, 'Agree and continue');
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        final page = tester.widget<MushafPageContent>(
          find.byType(MushafPageContent),
        );
        expect(page.revealedWordCounts, {'1:1': 2});
        expect(page.highlightedWordIndices, {
          '1:1': {0, 1},
        });
        expect(page.hiddenAyahs, {'1:1', '1:2'});
        expect(find.textContaining('Recognized words:'), findsNothing);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
        await _tap(tester, 'Pause');
        expect(find.text('Unaided matches: 1 · Assisted: 0'), findsOneWidget);
        expect(
          calls,
          containsAllInOrder(['available', 'start', 'preview', 'check']),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  group('strict local lab practice', () {
    MushafPageContent page(WidgetTester tester) =>
        tester.widget<MushafPageContent>(find.byType(MushafPageContent));

    Future<void> startLab(
      WidgetTester tester,
      _FakeSpeech speech, {
      List<Ayah>? ayahs,
    }) async {
      await _open(
        tester,
        speech,
        continuous: true,
        localQuranLab: true,
        ayahs: ayahs,
      );
      await _tap(tester, 'Live word preview (unverified)');
      await _tap(tester, 'Start reciting');
      await _tap(tester, 'Agree and continue');
    }

    testWidgets('Pause immediately shows finalizing while ASR completes', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      final stopping = Completer<void>();
      speech.pendingStop = stopping.future;
      await startLab(tester, speech);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Finishing recognition…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      speech.result!(_first, true);
      stopping.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ayah 2 / 2'), findsOneWidget);
      expect(find.text('Finishing recognition…'), findsNothing);
    });

    testWidgets('completed recitation stays highlighted after Pause', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(
        tester,
        speech,
        ayahs: [
          for (final (index, text) in [_first, _second].indexed)
            Ayah(
              surahNumber: 1,
              ayahNumber: index + 1,
              pageNumber: 1,
              arabic: text,
              imlaei: text,
              translations: const {},
              words: [
                for (final word in text.split(' '))
                  TajweedWord(
                    arabic: word,
                    spans: const [],
                    lineNumber: index + 1,
                  ),
              ],
              endLineNumber: index + 1,
            ),
        ],
      );
      speech.result!(_first, true);
      await tester.pumpAndSettle();

      expect(page(tester).highlightedWordIndices, {
        '1:1': {0, 1, 2, 3},
      });
      expect(page(tester).hiddenAyahs, {'1:2'});
      expect(find.text('Unaided matches: 1 · Assisted: 0'), findsOneWidget);

      await _tap(tester, 'Reveal ayah and continue');
      expect(page(tester).highlightedWordIndices, {
        '1:1': {0, 1, 2, 3},
      });
      expect(find.text('Unaided matches: 1 · Assisted: 1'), findsOneWidget);
    });

    testWidgets('page swipes retain partial highlights without skipping', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      Ayah pageAyah(int number, String text, int pageNumber) => Ayah(
        surahNumber: 1,
        ayahNumber: number,
        pageNumber: pageNumber,
        arabic: text,
        imlaei: text,
        translations: const {},
        words: [
          for (final word in text.split(' '))
            TajweedWord(arabic: word, spans: const [], lineNumber: number),
        ],
        endLineNumber: number,
      );
      await _open(
        tester,
        speech,
        continuous: true,
        localQuranLab: true,
        ayahs: [
          pageAyah(1, _first, 1),
          pageAyah(2, _second, 1),
          pageAyah(3, _first, 2),
          pageAyah(4, _second, 2),
        ],
      );
      await _tap(tester, 'Start reciting');
      await _tap(tester, 'Agree and continue');
      speech.result!('$_first الحمد لله', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});

      await tester.fling(
        find.byType(MushafPageContent),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Ayah 3 / 4'), findsOneWidget);
      await tester.fling(
        find.byType(MushafPageContent),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ayah 1 / 4'), findsOneWidget);
      expect(find.text('Continue from word: 1'), findsOneWidget);
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});
      expect(page(tester).highlightedWordIndices['1:2'], {0, 1});
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      expect(find.textContaining('unverified'), findsWidgets);
      final words = <String, TextSpan>{};
      void collect(InlineSpan span) {
        if (span is! TextSpan) return;
        if (['الحمد', 'لله', 'رب'].contains(span.text)) {
          words[span.text!] = span;
        }
        for (final child in span.children ?? <InlineSpan>[]) {
          collect(child);
        }
      }

      for (final text in tester.widgetList<RichText>(
        find.descendant(
          of: find.byKey(const ValueKey('mushaf-line-2')),
          matching: find.byType(RichText),
        ),
      )) {
        collect(text.text);
      }
      expect(words['الحمد']?.style?.backgroundColor, isNotNull);
      expect(words['لله']?.style?.backgroundColor, isNotNull);
      expect(words['رب']?.style?.color, Colors.transparent);

      await _tap(tester, 'Resume');
      speech.result!('الله', false);
      await tester.pumpAndSettle();
      expect(find.text('Ayah 1 / 4'), findsOneWidget);
      expect(find.text('Continue from word: 1'), findsOneWidget);
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
    });

    testWidgets(
      'swiping to next page and back keeps Resume active at first unrevealed ayah',
      (tester) async {
        final speech = _FakeSpeech();
        await _open(
          tester,
          speech,
          continuous: true,
          localQuranLab: true,
          ayahs: [
            _ayah(1, _first, pageNumber: 1),
            _ayah(2, _second, pageNumber: 1),
            _ayah(3, _first, pageNumber: 2),
          ],
        );
        await _tap(tester, 'Start reciting');
        await _tap(tester, 'Agree and continue');
        speech.result!(_first, true);
        await tester.pumpAndSettle();
        expect(find.text('Ayah 2 / 3'), findsOneWidget);

        await tester.fling(
          find.byType(MushafPageContent),
          const Offset(300, 0),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.text('Ayah 3 / 3'), findsOneWidget);

        await tester.fling(
          find.byType(MushafPageContent),
          const Offset(-300, 0),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.text('Ayah 2 / 3'), findsOneWidget);
        await _tap(tester, 'Resume');
        speech.result!(_second, true);
        await tester.pumpAndSettle();
        expect(find.text('Ayah 3 / 3'), findsOneWidget);
      },
    );

    testWidgets('longer snapshots continue after dropping earlier ayahs', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      final ayahs = [
        _ayah(1, _first),
        _ayah(2, _second),
        _ayah(3, 'الرحمن الرحيم'),
        _ayah(4, 'مالك يوم الدين'),
        _ayah(5, 'إهدنا الصراط المستقيم'),
      ];
      await startLab(tester, speech, ayahs: ayahs);
      await _tap(tester, 'Live word preview (unverified)');

      speech.result!('$_first $_second', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4});

      const resumed = '$_second الرحمن الرحيم مالك يوم الدين';
      speech.result!(resumed, false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {
        '1:1': 4,
        '1:2': 4,
        '1:3': 2,
        '1:4': 3,
      });

      speech.result!(resumed, true);
      await tester.pumpAndSettle();
      expect(find.text('Ayah 5 / 5'), findsOneWidget);
      expect(find.text('Unaided matches: 3 · Assisted: 0'), findsOneWidget);
    });

    testWidgets('short rolling snapshots recover the omitted third ayah', (
      tester,
    ) async {
      final speech = _FakeWindowedSpeech();
      await startLab(
        tester,
        speech,
        ayahs: [
          _ayah(1, _first),
          _ayah(2, _second),
          _ayah(3, 'الرحمن الرحيم'),
          _ayah(4, 'مالك يوم الدين'),
          _ayah(5, 'إياك نعبد وإياك نستعين'),
        ],
      );
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!('$_first $_second', false);
      await tester.pumpAndSettle();
      speech.windowStartSeconds = 4;
      speech.result!('$_second الرحمن الرحيم', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts['1:3'], 2);
      speech.windowStartSeconds = 8;
      speech.result!('الرحمن الرحيم مالك يوم الدين إياك نعبد', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts['1:4'], 3);
      expect(page(tester).revealedWordCounts['1:5'], 2);
      speech.stopping = () => speech.result!(
        '$_second مالك يوم الدين إياك نعبد وإياك نستعين',
        true,
      );
      await _tap(tester, 'Pause');
      expect(page(tester).revealedWordCounts['1:3'], 2);
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
    });

    testWidgets('last preview during Stop survives a worse final hypothesis', (
      tester,
    ) async {
      const last = 'صراط الذين أنعمت عليهم غير المغضوب عليهم ولا الضالين';
      final speech = _FakeWindowedSpeech();
      await startLab(tester, speech, ayahs: [_ayah(7, last)]);
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!('صراط الذين', false);
      await tester.pumpAndSettle();
      speech.stopping = () {
        speech.windowStartSeconds = 65;
        speech.result!('أنعمت عليهم غير المغضوب عليهم ولا الضالين', false);
        speech.windowStartSeconds = 43;
        speech.result!(
          'صراط الذي إهدنا الصراط المستقيم غير المغضوب عليهم ولا الضالين',
          true,
        );
      };
      await _tap(tester, 'Pause');
      expect(page(tester).revealedWordCounts, {'1:7': 9});
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
    });

    testWidgets(
      'basmala last word continues a live partial prefix without skipping',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(tester, speech);
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('بسم الله الرحمن', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 3});
        for (final text in ['', 'العليم', _second, 'الرحيم', 'الرحيم الرحيم']) {
          speech.result!(text, false);
          await tester.pumpAndSettle();
          expect(page(tester).revealedWordCounts, {
            '1:1': text.startsWith('الرحيم') ? 4 : 3,
          });
        }
        speech.stopping = () => speech.result!('الرحيم الرحيم', true);
        await _tap(tester, 'Pause');
        expect(_hidden(tester), isNot(contains('1:1')));
        expect(page(tester).revealedWordCounts.containsKey('1:2'), isFalse);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
        await _tap(tester, 'Resume');
        speech.result!(_second, false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:2'], 4);
      },
    );

    testWidgets(
      'revised recognition keeps displayed words and retries only the missing word',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            for (final (index, text) in [_first, _second].indexed)
              Ayah(
                surahNumber: 1,
                ayahNumber: index + 1,
                pageNumber: 1,
                arabic: text,
                imlaei: text,
                translations: const {},
                words: [
                  for (final word in text.split(' '))
                    TajweedWord(
                      arabic: word,
                      spans: const [],
                      lineNumber: index + 1,
                    ),
                ],
                endLineNumber: index + 1,
              ),
          ],
        );
        void expectBasmalaPrefix(int count) {
          final words = <TextSpan>[];
          void collect(InlineSpan span) {
            if (span is! TextSpan) return;
            if (_first.split(' ').contains(span.text)) words.add(span);
            for (final child in span.children ?? <InlineSpan>[]) {
              collect(child);
            }
          }

          for (final text in tester.widgetList<RichText>(
            find.descendant(
              of: find.byKey(const ValueKey('mushaf-line-1')),
              matching: find.byType(RichText),
            ),
          )) {
            collect(text.text);
          }
          expect(words, hasLength(4));
          for (final (index, word) in words.indexed) {
            expect(
              word.style?.color,
              index < count ? isNot(Colors.transparent) : Colors.transparent,
            );
            if (index >= count) expect(word.semanticsLabel, '');
          }
        }

        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('بسم الله الرحمن', false);
        await tester.pumpAndSettle();
        for (final text in [
          'بسم الله',
          'بسم الكريم الرحمن الرحيم',
          _second,
          '',
        ]) {
          speech.result!(text, false);
          await tester.pumpAndSettle();
          expect(page(tester).revealedWordCounts, {'1:1': 3});
          expectBasmalaPrefix(3);
        }
        speech.stopping = () => speech.result!('بسم الكريم', true);
        await _tap(tester, 'Pause');
        expect(page(tester).revealedWordCounts, {'1:1': 3});
        expectBasmalaPrefix(3);
        expect(find.text('Continue from word: 4'), findsOneWidget);
        await _tap(tester, 'Resume');
        speech.result!('بسم الله', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 3});
        speech.result!('الرحيم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4});
        expectBasmalaPrefix(4);
        speech.result!('$_first الحمد', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 1});
        speech.result!('لله رب العالمين', true);
        await tester.pumpAndSettle();
        expect(_hidden(tester), isEmpty);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      },
    );

    testWidgets(
      'overlapping retries extend live words without skipping a wrong word',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(tester, speech);
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('بسم الله الرحمن', false);
        await tester.pumpAndSettle();
        speech.result!('الرحمن العليم الرحيم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 3});
        speech.result!('الرحمن الرحيم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4});
        speech.result!('الحمد لله', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});
        speech.result!('لله خطأ رب العالمين', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});
        speech.result!('لله رب العالمين', true);
        await tester.pumpAndSettle();
        expect(_hidden(tester), isEmpty);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      },
    );

    for (final rolling in [false, true]) {
      testWidgets(
        'partial later ayahs continue at the missing word with rolling $rolling',
        (tester) async {
          final speech = _FakeWindowedSpeech();
          await startLab(
            tester,
            speech,
            ayahs: [
              _ayah(1, _first),
              _ayah(2, _second),
              _ayah(3, 'الرحمن الرحيم'),
              _ayah(4, 'مالك يوم الدين'),
            ],
          );
          await _tap(tester, 'Live word preview (unverified)');
          speech.result!('$_first $_second الرحمن', false);
          await tester.pumpAndSettle();
          expect(page(tester).revealedWordCounts, {
            '1:1': 4,
            '1:2': 4,
            '1:3': 1,
          });
          if (rolling) speech.windowStartSeconds = 31;
          for (final text in ['', 'العليم', 'مالك يوم الدين']) {
            speech.result!(text, false);
            await tester.pumpAndSettle();
            expect(page(tester).revealedWordCounts, {
              '1:1': 4,
              '1:2': 4,
              '1:3': 1,
            });
          }
          speech.result!('الرحيم', false);
          await tester.pumpAndSettle();
          expect(page(tester).revealedWordCounts, {
            '1:1': 4,
            '1:2': 4,
            '1:3': 2,
          });
          speech.result!('مالك يوم', false);
          await tester.pumpAndSettle();
          expect(page(tester).revealedWordCounts, {
            '1:1': 4,
            '1:2': 4,
            '1:3': 2,
            '1:4': 2,
          });
          speech.stopping = () => speech.result!('الدين', true);
          await _tap(tester, 'Pause');
          expect(_hidden(tester), isEmpty);
          expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'rolling contradictions keep old words but cannot reveal new later words',
      (tester) async {
        final speech = _FakeWindowedSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(1, 'الرحمن الرحيم'),
            _ayah(2, 'الرحمن العليم'),
            _ayah(3, 'مالك يوم الدين'),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('الرحمن الرحيم الرحمن العليم', false);
        await tester.pumpAndSettle();
        speech.windowStartSeconds = 1;
        speech.result!('الرحمن العليم مالك يوم الدين', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 2, '1:2': 2});
        speech.stopping = () =>
            speech.result!('الرحمن العليم مالك يوم الدين', true);
        await _tap(tester, 'Pause');
        expect(page(tester).revealedWordCounts, {'1:1': 2, '1:2': 2});
        expect(find.text('Ayah 3 / 3'), findsOneWidget);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
        await _tap(tester, 'Resume');
        speech.windowStartSeconds = 0;
        speech.result!('الرحيم الرحمن العليم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 2, '1:2': 2});
        speech.result!('مالك يوم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 2, '1:2': 2, '1:3': 2});
      },
    );

    testWidgets(
      'sliding window suffix with repeated phrase extends ayah 2:24 instead of contradicting',
      (tester) async {
        const baqarah24 =
            'فَإِن لَّمْ تَفْعَلُوا وَلَن تَفْعَلُوا فَاتَّقُوا النَّارَ الَّتِي وَقُودُهَا النَّاسُ وَالْحِجَارَةُ أُعِدَّتْ لِلْكَافِرِينَ';
        final speech = _FakeWindowedSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [_ayah(24, baqarah24), _ayah(25, 'وبشر الذين آمنوا')],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('فإن لم تفعلوا ولن تفعلوا فاتقوا النار التي', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:24': 8});

        speech.windowStartSeconds = 0.89;
        speech.result!(
          'وإن لم تفعلوا ولن تفعلوا فاتقوا النار التي وقودها الناس والحجارة',
          false,
        );
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:24': 11});
      },
    );

    testWidgets(
      'Surah Nuh 71:9 to 71:10 progression continues cleanly and tolerates trailing word carryover',
      (tester) async {
        const nuh9 =
            'ثُمَّ إِنِّي أَعْلَنتُ لَهُمْ وَأَسْرَرْتُ لَهُمْ إِسْرَارًا';
        const nuh10 = 'فَقُلْتُ اسْتَغْفِرُوا رَبَّكُمْ إِنَّهُ كَانَ غَفَّارًا';
        const nuh11 = 'يُرْسِلِ السَّمَاءَ عَلَيْكُم مِّدْرَارًا';
        final speech = _FakeWindowedSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(9, nuh9),
            _ayah(10, nuh10),
            _ayah(11, nuh11),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('ثم إني', false);
        await tester.pumpAndSettle();
        speech.stopping = () => speech.result!('ثم إني', true);
        await _tap(tester, 'Pause');
        expect(page(tester).revealedWordCounts, {'1:9': 2});

        await _tap(tester, 'Resume');
        speech.result!('أعلنت لهم وأسررت لهم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:9': 6});

        speech.stopping = () =>
            speech.result!('أعلنت لهم وأسررت لهم إسرارا', true);
        await _tap(tester, 'Pause');
        expect(_hidden(tester), isNot(contains('1:9')));
        expect(find.text('Ayah 2 / 3'), findsOneWidget);

        await _tap(tester, 'Resume');
        speech.windowStartSeconds = 0;
        speech.result!(
          'إسرارى فقلت استغفروا ربكم إنه كان غفارا',
          false,
        );
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:10'], 6);

        speech.stopping = () => speech.result!(
          'إسرارى فقلت استغفروا ربكم إنه كان غفارا',
          true,
        );
        await _tap(tester, 'Pause');
        expect(find.text('Ayah 3 / 3'), findsOneWidget);
      },
    );

    testWidgets(
      'a revised snapshot cannot skip an omitted word into a similar next ayah',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(1, 'الرحمن الرحيم'),
            _ayah(2, 'الرحمن العليم'),
            _ayah(3, 'مالك يوم الدين'),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('الرحمن الرحيم الرحمن العليم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 2, '1:2': 2});
        speech.result!('الرحمن العليم مالك يوم الدين', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 2, '1:2': 2});
        speech.result!('الرحمن الرحيم الرحمن العليم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 2, '1:2': 2});
      },
    );

    testWidgets(
      'pause and resume count actual words, not separate Quran pause marks',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(
              2,
              'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ',
            ),
            _ayah(3, 'الذين يؤمنون'),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('ذلك الكتاب لا ريب فيه', false);
        await tester.pumpAndSettle();
        speech.stopping = () => speech.result!('ذلك الكتاب لا ريب', true);
        await _tap(tester, 'Pause');
        expect(page(tester).revealedWordCounts, {'1:2': 5});
        expect(find.text('Continue from word: 6'), findsOneWidget);
        await _tap(tester, 'Resume');
        speech.result!('هدى للمتقين', true);
        await tester.pumpAndSettle();
        expect(find.text('Ayah 2 / 2'), findsOneWidget);
        expect(_hidden(tester), {'1:3'});
      },
    );

    testWidgets(
      'completed first ayahs survive a tail-only final with a third-ayah mistake',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            for (final (index, text) in [
              _first,
              _second,
              'الرحمن الرحيم',
              'مالك يوم الدين',
            ].indexed)
              Ayah(
                surahNumber: 1,
                ayahNumber: index + 1,
                pageNumber: 1,
                arabic: text,
                imlaei: text,
                translations: const {},
                words: [
                  for (final word in text.split(' '))
                    TajweedWord(
                      arabic: word,
                      spans: const [],
                      lineNumber: index + 1,
                    ),
                ],
                endLineNumber: index + 1,
              ),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('بسم الله', true);
        await tester.pumpAndSettle();
        await _tap(tester, 'Resume');
        speech.result!('الرحمن الرحيم $_second', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4});
        speech.result!('الرحمن العليم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4, '1:3': 1});
        speech.result!('الرحمن العليم', true);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4, '1:3': 1});
        expect(find.text('Ayah 3 / 4'), findsOneWidget);
        expect(find.text('Continue from word: 2'), findsOneWidget);
        final thirdWords = <TextSpan>[];
        void collect(InlineSpan span) {
          if (span is! TextSpan) return;
          if (span.text == 'الرحمن' || span.text == 'الرحيم') {
            thirdWords.add(span);
          }
          for (final child in span.children ?? <InlineSpan>[]) {
            collect(child);
          }
        }

        for (final text in tester.widgetList<RichText>(
          find.descendant(
            of: find.byKey(const ValueKey('mushaf-line-3')),
            matching: find.byType(RichText),
          ),
        )) {
          collect(text.text);
        }
        expect(thirdWords, hasLength(2));
        expect(thirdWords[0].style?.color, isNot(Colors.transparent));
        expect(thirdWords[1].style?.color, Colors.transparent);
        expect(thirdWords[1].semanticsLabel, '');
        await _tap(tester, 'Resume');
        speech.result!('العليم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:3'], 1);
        speech.result!('الرحيم', true);
        await tester.pumpAndSettle();
        expect(find.text('Ayah 4 / 4'), findsOneWidget);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      },
    );

    testWidgets(
      'tail-only final reveals the third prefix even without a last preview',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(1, _first),
            _ayah(2, _second),
            _ayah(3, 'الرحمن الرحيم'),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('$_first $_second', false);
        await tester.pumpAndSettle();
        speech.result!('الرحمن العليم', true);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4, '1:3': 1});
        expect(find.text('Continue from word: 2'), findsOneWidget);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      },
    );

    for (final ending in ['done', 'error', 'background']) {
      testWidgets('visible ayahs survive recognition $ending', (tester) async {
        final speech = _FakeSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(1, _first),
            _ayah(2, _second),
            _ayah(3, 'الرحمن الرحيم'),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('$_first $_second الرحمن العليم', false);
        await tester.pumpAndSettle();
        if (ending == 'done') {
          speech.done!();
        } else if (ending == 'error') {
          speech.error!('quran_asr_invalid_result');
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        }
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4, '1:3': 1});
        expect(find.text('Continue from word: 2'), findsOneWidget);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
        if (ending == 'background') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
        }
        await _tap(tester, ending == 'error' ? 'Retry' : 'Resume');
        speech.result!('العليم', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:3'], 1);
        speech.result!('الرحيم', true);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:1'], 4);
        expect(page(tester).revealedWordCounts['1:2'], 4);
      });
    }

    testWidgets(
      'Fatiha final ayah progresses across repeated overlapping restarts',
      (tester) async {
        const last = 'صراط الذين أنعمت عليهم غير المغضوب عليهم ولا الضالين';
        final speech = _FakeSpeech();
        await startLab(tester, speech, ayahs: [_ayah(7, last)]);
        await _tap(tester, 'Live word preview (unverified)');
        for (final (segment, count) in [
          ('صراط الذين', 2),
          ('صراط الذين أنعمت عليهم', 4),
          ('أنعمت عليهم غير المغضوب', 6),
          ('عليهم ولا العالمين', 8),
        ]) {
          speech.result!(segment, false);
          await tester.pumpAndSettle();
          expect(page(tester).revealedWordCounts, {'1:7': count});
          speech.stopping = () => speech.result!(segment, true);
          await _tap(tester, 'Pause');
          expect(page(tester).revealedWordCounts, {'1:7': count});
          expect(find.text('Continue from word: ${count + 1}'), findsOneWidget);
          await _tap(tester, 'Resume');
        }
        speech.result!('ولا الضالين', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:7': 9});
        speech.stopping = () => speech.result!('ولا الضالين', true);
        await _tap(tester, 'Pause');
        expect(_hidden(tester), isEmpty);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      },
    );

    testWidgets(
      'Fatiha full surah sliding windows advance through 1:5-1:7 cloud snapshots',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(1, _first),
            _ayah(2, _second),
            _ayah(3, 'الرحمن الرحيم'),
            _ayah(4, 'مالك يوم الدين'),
            _ayah(5, 'إياك نعبد وإياك نستعين'),
            _ayah(6, 'اهدنا الصراط المستقيم'),
            _ayah(7, 'صراط الذين أنعمت عليهم غير المغضوب عليهم ولا الضالين'),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!('$_first $_second', false);
        await tester.pumpAndSettle();
        speech.result!('$_second الرحمن الرحيم مالك يوم الدين', false);
        await tester.pumpAndSettle();
        speech.result!(
          'إِيَكَ نَعْبُدُ وَإِيَّكَ نَسْتَعِينُ إِهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
          false,
        );
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:5'], 4);
        expect(page(tester).revealedWordCounts['1:6'], 3);
        speech.result!(
          'وَإِيَّاكَ نَسْتَعِيِّنَ إِهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ فِرَاطَ الَّذِينَ نَعْمَثَ عَلَيْهِمْ غَيْرِ الْمَغْوِ عَلَيْهِمْ',
          false,
        );
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:7'], 2);
        speech.stopping = () => speech.result!(
          'الْحَمْدُ لِلَّهِ رَحْمَنِ الرَّحِيمِ مَالِكِ يَوْمِ الدِّينِ إِيَكَ نَعْبُدُ وَإِيَّكَ نَسْتَعِيِّنَ إِهْدِيَ الصِّرَاطَ الْمُسْتَقِيمَ فِرَاطَ الَّذِينَ نَعْمَتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
          true,
        );
        await _tap(tester, 'Pause');
        expect(_hidden(tester), isNot(contains('1:7')));
        expect(find.text('Ayah 7 / 7'), findsOneWidget);
      },
    );

    testWidgets('pause retains displayed words despite a revised mismatch', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(tester, speech);
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!('$_first الحمد لله', false);
      await tester.pumpAndSettle();
      speech.stopping = () => speech.result!('بسم الكريم', true);
      await _tap(tester, 'Pause');
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});
      expect(find.text('Ayah 2 / 2'), findsOneWidget);
      expect(find.text('Continue from word: 3'), findsOneWidget);
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      await _tap(tester, 'Resume');
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});
      speech.result!('خطأ العالمين', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});
      speech.result!('رب العالمين', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), isNot(contains('1:2')));
      expect(find.text('Ayah 2 / 2'), findsOneWidget);
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
    });

    for (final stopResult in ['none', 'empty', 'error']) {
      testWidgets('pause preserves words after $stopResult final output', (
        tester,
      ) async {
        final speech = _FakeSpeech();
        await startLab(tester, speech);
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!(_first, false);
        await tester.pumpAndSettle();
        speech.stopping = () {
          if (stopResult == 'empty') speech.result!('', true);
          if (stopResult == 'error') speech.error!('quran_asr_invalid_result');
        };
        await _tap(tester, 'Pause');
        expect(page(tester).revealedWordCounts, {'1:1': 4});
        expect(find.text('Ayah 2 / 2'), findsOneWidget);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
        await _tap(tester, stopResult == 'error' ? 'Retry' : 'Resume');
        expect(page(tester).revealedWordCounts, {'1:1': 4});
        speech.result!(_second, true);
        await tester.pumpAndSettle();
        expect(find.text('Unaided matches: 1 · Assisted: 0'), findsOneWidget);
      });
    }

    testWidgets('third ayah reveals الرحمن but blocks العليم across pause', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(
        tester,
        speech,
        ayahs: [_ayah(1, _first), _ayah(2, _second), _ayah(3, 'الرحمن الرحيم')],
      );
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!('$_first $_second', false);
      await tester.pumpAndSettle();
      speech.result!('الرحمن العليم', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4, '1:3': 1});
      speech.stopping = () => speech.result!('الرحمن العليم', true);
      await _tap(tester, 'Pause');
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4, '1:3': 1});
      expect(find.text('Continue from word: 2'), findsOneWidget);
      await _tap(tester, 'Resume');
      speech.result!('العليم', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts['1:3'], 1);
      speech.result!('الرحيم', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts['1:3'], 2);
      speech.result!('الرحيم', true);
      await tester.pumpAndSettle();
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
    });

    testWidgets(
      'completed basmala stays visible as next ayah snapshots revise',
      (tester) async {
        final speech = _FakeSpeech();
        await startLab(tester, speech);
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!(_first, false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4});
        for (final (text, expected) in [
          ('الحمد لله', {'1:1': 4, '1:2': 2}),
          ('الحمد زيادة رب العالمين', {'1:1': 4, '1:2': 2}),
          ('', {'1:1': 4, '1:2': 2}),
          ('بسم الكريم', {'1:1': 4, '1:2': 2}),
          ('$_first $_second', {'1:1': 4, '1:2': 4}),
          ('خطأ', {'1:1': 4, '1:2': 4}),
        ]) {
          speech.result!(text, false);
          await tester.pumpAndSettle();
          expect(page(tester).revealedWordCounts, expected);
          expect(find.text('Ayah 1 / 2'), findsOneWidget);
          expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
        }
        speech.result!('بسم الله الكريم', true);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4});
        expect(_hidden(tester), {'1:1', '1:2'});
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      },
    );

    testWidgets('completed previews clear on disable and cannot skip an ayah', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(
        tester,
        speech,
        ayahs: [_ayah(1, _first), _ayah(2, _second), _ayah(3, 'الرحمن الرحيم')],
      );
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!(_first, false);
      await tester.pumpAndSettle();
      speech.result!('الرحمن الرحيم', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4});
      await _tap(tester, 'Live word preview (unverified)');
      expect(page(tester).revealedWordCounts, isEmpty);
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!(_second, false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, isEmpty);
      speech.result!(_first, false);
      await tester.pumpAndSettle();
      speech.error!('quran_asr_failed');
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4});
      await _tap(tester, 'Retry');
      speech.result!(_second, false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4});
    });

    testWidgets('optional lab words stay unverified through revisions', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(tester, speech);
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!('بسم الله الرحمن', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 3});
      expect(
        find.text('Preview only — awaiting final recognition'),
        findsOneWidget,
      );
      speech.result!('بسم الكريم الرحمن الرحيم $_second', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 3});
      expect(find.text('Ayah 1 / 2'), findsOneWidget);
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      expect(find.textContaining('Recognized words:'), findsNothing);
      await _tap(tester, 'Live word preview (unverified)');
      expect(page(tester).revealedWordCounts, isEmpty);
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!('$_first الحمد', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 1});
      speech.result!('بسم الله الكريم', true);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 1});
      await _tap(tester, 'Resume');
      speech.result!('خطأ', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 1});
      speech.result!('لله', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});
      speech.error!('quran_asr_failed');
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 2});
    });

    testWidgets('microphone permission inactivity must not cancel startup', (
      tester,
    ) async {
      final permission = Completer<void>();
      final speech = _FakeSpeech()..pendingStart = permission.future;
      await startLab(tester, speech);
      final initialCancellations = speech.cancellations;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(speech.cancellations, initialCancellations);
      permission.complete();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      speech.result!(_first, true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:2'});
    });

    testWidgets('real backgrounding still cancels a pending microphone start', (
      tester,
    ) async {
      final permission = Completer<void>();
      final speech = _FakeSpeech()..pendingStart = permission.future;
      await startLab(tester, speech);
      final result = speech.result!;
      final initialCancellations = speech.cancellations;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(speech.cancellations, greaterThan(initialCancellations));
      permission.complete();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      result(_first, true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
    });

    testWidgets('even complete interim ayahs and transcripts stay hidden', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(tester, speech);
      expect(find.text('Live word preview (unverified)'), findsOneWidget);
      for (final text in ['بسم الله', '$_first $_second', 'بسم الكريم', '']) {
        speech.result!(text, false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, isEmpty);
        expect(page(tester).highlightedWordIndices, isEmpty);
        expect(_hidden(tester), {'1:1', '1:2'});
        expect(find.textContaining('Recognized words:'), findsNothing);
        expect(find.textContaining('Preview only'), findsNothing);
        expect(find.text('Ayah 1 / 2'), findsOneWidget);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      }
    });

    testWidgets('default live words render in place and can be disabled', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await _open(
        tester,
        speech,
        continuous: true,
        localQuranLab: true,
        ayahs: [
          Ayah(
            surahNumber: 1,
            ayahNumber: 1,
            pageNumber: 1,
            arabic: _first,
            imlaei: _first,
            translations: const {},
            words: [
              for (final (index, word) in _first.split(' ').indexed)
                TajweedWord(
                  arabic: word,
                  spans: const [],
                  lineNumber: index < 2 ? 1 : 2,
                ),
            ],
            endLineNumber: 2,
          ),
        ],
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(
        tester
            .getRect(find.byType(SwitchListTile))
            .overlaps(tester.getRect(find.byType(Scaffold))),
        isTrue,
      );
      await _tap(tester, 'Start reciting');
      await _tap(tester, 'Agree and continue');
      final lines = [
        find.byKey(const ValueKey('mushaf-line-1')),
        find.byKey(const ValueKey('mushaf-line-2')),
      ];
      final originalRects = [for (final line in lines) tester.getRect(line)];
      List<TextSpan> wordSpans() {
        final spans = <TextSpan>[];
        void collect(InlineSpan span) {
          if (span is! TextSpan) return;
          if (_first.split(' ').contains(span.text)) spans.add(span);
          for (final child in span.children ?? <InlineSpan>[]) {
            collect(child);
          }
        }

        for (final richText in tester.widgetList<RichText>(
          find.descendant(
            of: find.byType(MushafPageContent),
            matching: find.byType(RichText),
          ),
        )) {
          collect(richText.text);
        }
        return spans;
      }

      expect(wordSpans(), hasLength(4));
      for (final span in wordSpans()) {
        expect(span.style?.color, Colors.transparent);
        expect(span.semanticsLabel, '');
      }
      speech.result!('بسم الله', false);
      await tester.pumpAndSettle();
      for (var index = 0; index < wordSpans().length; index++) {
        expect(
          wordSpans()[index].style?.color,
          index < 2 ? isNot(Colors.transparent) : Colors.transparent,
        );
        expect(wordSpans()[index].semanticsLabel, index < 2 ? null : '');
      }
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      await _tap(tester, 'Live word preview (unverified)');
      for (final span in wordSpans()) {
        expect(span.style?.color, Colors.transparent);
        expect(span.semanticsLabel, '');
      }
      speech.result!(_first, false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, isEmpty);
      speech.result!('بسم الله الكريم الرحيم', true);
      await tester.pumpAndSettle();
      final spans = wordSpans();
      for (var index = 0; index < spans.length; index++) {
        expect(
          spans[index].style?.color,
          index < 2 ? isNot(Colors.transparent) : Colors.transparent,
        );
        expect(spans[index].semanticsLabel, index < 2 ? null : '');
      }
      expect([for (final line in lines) tester.getRect(line)], originalRects);
    });

    for (final text in [
      'بسم الكريم الرحمن الرحيم $_second',
      'بسم الرحمن الرحيم $_second',
      'بسم زيادة الله الرحمن الرحيم $_second',
      'بسم الله الله الرحمن الرحيم $_second',
    ]) {
      testWidgets('final prefix blocks and recovers after $text', (
        tester,
      ) async {
        final speech = _FakeSpeech();
        await startLab(tester, speech);
        speech.result!(text, true);
        await tester.pumpAndSettle();
        final accepted = text.startsWith('بسم الله الله') ? 2 : 1;
        expect(page(tester).revealedWordCounts, {'1:1': accepted});
        expect(_hidden(tester), {'1:1', '1:2'});
        expect(
          find.text('Continue from word: ${accepted + 1}'),
          findsOneWidget,
        );
        expect(find.text('Ayah 1 / 2'), findsOneWidget);
        expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
        expect(find.textContaining('Recognized words:'), findsNothing);
        await _tap(tester, 'Resume');
        speech.result!(_first.split(' ').skip(accepted).join(' '), true);
        await tester.pumpAndSettle();
        expect(_hidden(tester), {'1:2'});
        expect(page(tester).revealedWordCounts, isEmpty);
        expect(find.text('Ayah 2 / 2'), findsOneWidget);
        expect(find.text('Continue from word: 1'), findsOneWidget);
        expect(find.text('Unaided matches: 1 · Assisted: 0'), findsOneWidget);
        await _tap(tester, 'Resume');
        speech.result!(_second, true);
        await tester.pumpAndSettle();
        expect(_hidden(tester), isEmpty);
        expect(find.textContaining('Surah practice finished.'), findsOneWidget);
      });
    }

    testWidgets('later ayah mismatch retains only its ordered prefix', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(tester, speech);
      speech.result!('$_first الحمد زيادة رب العالمين', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:2'});
      expect(page(tester).revealedWordCounts, {'1:2': 1});
      expect(find.text('Ayah 2 / 2'), findsOneWidget);
      expect(find.text('Continue from word: 2'), findsOneWidget);
      await _tap(tester, 'Resume');
      speech.result!('لله رب العالمين', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), isEmpty);
      expect(find.text('Unaided matches: 2 · Assisted: 0'), findsOneWidget);
    });

    testWidgets('errors and lifecycle interruptions retain only final prefix', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(tester, speech);
      speech.result!('بسم الله', true);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 2});
      await _tap(tester, 'Resume');
      speech.result!('الرحمن الرحيم', false);
      speech.error!('quran_asr_invalid_result');
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 2});
      await _tap(tester, 'Retry');
      final lateResult = speech.result!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      lateResult('الرحمن الرحيم', true);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 2});
      expect(_hidden(tester), {'1:1', '1:2'});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _tap(tester, 'Resume');
      speech.result!('الرحمن الرحيم', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:2'});
    });

    testWidgets('a trailing extra word cannot complete the final ayah', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(tester, speech, ayahs: [_ayah(1, _first)]);
      speech.result!('بسم الله', true);
      await tester.pumpAndSettle();
      await _tap(tester, 'Resume');
      speech.result!('الرحمن الرحيم زيادة', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1'});
      expect(page(tester).revealedWordCounts, {'1:1': 2});
      expect(find.text('Continue from word: 3'), findsOneWidget);
      await _tap(tester, 'Resume');
      speech.result!('الرحمن الرحيم', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), isEmpty);
    });

    testWidgets('disconnected opening stays masked until every name matches', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(
        tester,
        speech,
        ayahs: [
          const Ayah(
            surahNumber: 2,
            ayahNumber: 1,
            pageNumber: 2,
            arabic: 'الم',
            imlaei: 'الم',
            translations: {},
            words: [TajweedWord(arabic: 'الم', spans: [], lineNumber: 1)],
            endLineNumber: 1,
          ),
        ],
      );
      speech.result!('ألف خطأ ميم', true);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, isEmpty);
      expect(_hidden(tester), {'2:1'});
      await _tap(tester, 'Resume');
      await _tap(tester, 'Live word preview (unverified)');
      speech.result!('الٓمٓ', false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'2:1': 1});
      expect(_hidden(tester), {'2:1'});
      expect(find.text('Unaided matches: 0 · Assisted: 0'), findsOneWidget);
      speech.result!('الٓمٓ', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), isEmpty);
    });

    for (final help in ['Need a hint?', 'Listen to reference']) {
      testWidgets('$help preserves prefix but prevents unaided credit', (
        tester,
      ) async {
        final speech = _FakeSpeech();
        await startLab(tester, speech);
        speech.result!('بسم الله', true);
        await tester.pumpAndSettle();
        await _tap(tester, help);
        expect(page(tester).revealedWordCounts, {'1:1': 2});
        if (help == 'Need a hint?') {
          expect(page(tester).hintedWords, {'1:1': 4});
        } else {
          expect(page(tester).hintedWords, isEmpty);
        }
        await _tap(tester, 'Resume');
        speech.result!('الرحمن الرحيم', true);
        await tester.pumpAndSettle();
        expect(_hidden(tester), {'1:2'});
        expect(find.text('Unaided matches: 0 · Assisted: 1'), findsOneWidget);
      });
    }

    testWidgets('a hint remains fixed while later final prefixes advance', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await startLab(tester, speech);
      await _tap(tester, 'Need a hint?');
      expect(page(tester).hintedWords, {'1:1': 2});
      await _tap(tester, 'Resume');
      speech.result!('بسم الله الرحمن', true);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, {'1:1': 3});
      expect(page(tester).hintedWords, {'1:1': 2});
      expect(find.text('Continue from word: 4'), findsOneWidget);
      await _tap(tester, 'Need a hint?');
      expect(page(tester).hintedWords, {'1:1': 4});
      await _tap(tester, 'Need a hint?');
      expect(_hidden(tester), {'1:2'});
      expect(page(tester).hintedWords['1:2'], 2);
      expect(find.text('Ayah 2 / 2'), findsOneWidget);
    });

    testWidgets(
      'Surah Al-Falaq 113 auto-completes across cloud transcripts',
      (tester) async {
        final speech = _FakeWindowedSpeech();
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(1, 'قل أعوذ برب الفلق'),
            _ayah(2, 'من شر ما خلق'),
            _ayah(3, 'ومن شر غاسق إذا وقب'),
            _ayah(4, 'ومن شر النفاثات في العقد'),
            _ayah(5, 'ومن شر حاسد إذا حسد'),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        speech.result!(
          'قل أعوذ برب الفلق من شر ما خلق ومن شر غاسقا إذا وقب',
          false,
        );
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:3'], 5);
        speech.stopping = () => speech.result!(
          'قل أعوذ برب الفلق من شر ما خلق ومن شر غاصق إذا وقبة ومن شر النفاثات في العقد ومن شر حاسد إذا حسد',
          true,
        );
        await _tap(tester, 'Pause');
        expect(_hidden(tester), isEmpty);
      },
    );

    testWidgets(
      'Surah An-Nas 114 auto-completes across cloud transcripts',
      (tester) async {
        final nasSpeech = _FakeWindowedSpeech();
        await startLab(
          tester,
          nasSpeech,
          ayahs: [
            _ayah(1, 'قل أعوذ برب الناس'),
            _ayah(2, 'ملك الناس'),
            _ayah(3, 'إله الناس'),
            _ayah(4, 'من شر الوسواس الخناس'),
            _ayah(5, 'الذي يوسوس في صدور الناس'),
            _ayah(6, 'من الجنة والناس'),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');
        nasSpeech.result!(
          'قل أعوذ برب الناس ملك الناس إله الناس من شر الوسواس الخناس الذي يوسوسوا في سضور الناس من الجنة والناس من الجنة والناس',
          false,
        );
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts['1:5'], 5);
        expect(page(tester).revealedWordCounts['1:6'], 3);
        nasSpeech.stopping = () => nasSpeech.result!(
          'قل أعوذ برب الناس ملك الناس إله الناس من شر الوسواس الخناس الذي يوسوسوا في سضور الناس من الجنة والناس من الجنة والناس',
          true,
        );
        await _tap(tester, 'Pause');
        expect(_hidden(tester), isEmpty);
      },
    );

    testWidgets(
      'Listen to reference and Reveal ayah target active live cursor instead of old recited ayah',
      (tester) async {
        final speech = _FakeSpeech();
        final playedAyahs = <int>[];
        await _open(
          tester,
          speech,
          continuous: true,
          localQuranLab: true,
          playReference: (ayah) async {
            playedAyahs.add(ayah.ayahNumber);
            return true;
          },
          ayahs: [
            _ayah(1, _first),
            _ayah(2, _second),
            _ayah(3, 'الرحمن الرحيم'),
            _ayah(4, 'مالك يوم الدين'),
          ],
        );
        await _tap(tester, 'Start reciting');
        await _tap(tester, 'Agree and continue');
        speech.result!('$_first $_second الرحمن', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {
          '1:1': 4,
          '1:2': 4,
          '1:3': 1,
        });

        await _tap(tester, 'Listen to reference');
        expect(playedAyahs, [3]);

        await _tap(tester, 'Reveal ayah and continue');
        await tester.pumpAndSettle();
        expect(_hidden(tester), {'1:4'});
        expect(find.text('Ayah 4 / 4'), findsOneWidget);
      },
    );

    testWidgets(
      'page holds at page boundary until next page ayah begins and allows swiping back during recitation',
      (tester) async {
        final speech = _FakeWindowedSpeech();
        await _open(
          tester,
          speech,
          continuous: true,
          localQuranLab: true,
          ayahs: [
            _ayah(1, _first, pageNumber: 1),
            _ayah(2, _second, pageNumber: 1),
            _ayah(3, 'الرحمن الرحيم', pageNumber: 2),
            _ayah(4, 'مالك يوم الدين', pageNumber: 2),
          ],
        );
        await _tap(tester, 'Start reciting');
        await _tap(tester, 'Agree and continue');

        // Completing all ayahs on page 1 stays on page 1 until page 2 begins
        speech.result!('$_first $_second', false);
        await tester.pumpAndSettle();
        expect(page(tester).pageNumber, 1);
        expect(page(tester).revealedWordCounts, {'1:1': 4, '1:2': 4});

        // Once the first word of page 2 is recited, page advances to 2
        speech.result!('$_first $_second الرحمن', false);
        await tester.pumpAndSettle();
        expect(page(tester).pageNumber, 2);
        expect(page(tester).revealedWordCounts, {
          '1:1': 4,
          '1:2': 4,
          '1:3': 1,
        });

        // Swiping back while still reciting inspects page 1 without cancelling
        await tester.fling(
          find.byType(MushafPageContent),
          const Offset(-300, 0),
          1000,
        );
        await tester.pumpAndSettle();
        expect(page(tester).pageNumber, 1);
        expect(page(tester).revealedWordCounts, {
          '1:1': 4,
          '1:2': 4,
          '1:3': 1,
        });
        expect(speech.cancellations, 0);

        // Swiping forward returns to page 2
        await tester.fling(
          find.byType(MushafPageContent),
          const Offset(300, 0),
          1000,
        );
        await tester.pumpAndSettle();
        expect(page(tester).pageNumber, 2);
      },
    );

    testWidgets(
      'Al-Qadr adjacent ليلة القدر boundary and mid-ayah final suffix verify later ayahs',
      (tester) async {
        final speech = _FakeWindowedSpeech();
        const qadr1 = 'إِنَّا أَنزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ';
        const qadr2 = 'وَمَا أَدْرَاكَ مَا لَيْلَةُ الْقَدْرِ';
        const qadr3 = 'لَيْلَةُ الْقَدْرِ خَيْرٌ مِّنْ أَلْفِ شَهْرٍ';
        const qadr4 =
            'تَنَزَّلُ الْمَلَائِكَةُ وَالرُّوحُ فِيهَا بِإِذْنِ رَبِّهِم مِّن كُلِّ أَمْرٍ';
        const qadr5 = 'سَلَامٌ هِيَ حَتَّىٰ مَطْلَعِ الْفَجْرِ';
        await startLab(
          tester,
          speech,
          ayahs: [
            _ayah(1, qadr1, surahNumber: 97),
            _ayah(2, qadr2, surahNumber: 97),
            _ayah(3, qadr3, surahNumber: 97),
            _ayah(4, qadr4, surahNumber: 97),
            _ayah(5, qadr5, surahNumber: 97),
          ],
        );
        await _tap(tester, 'Live word preview (unverified)');

        speech.result!('$qadr1 $qadr2', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {'97:1': 5, '97:2': 5});

        speech.windowStartSeconds = 12;
        speech.result!('لَيْلَةُ الْقَدْرِ خَيْرٌ مِنْ أَلْفِ شَهْرٍ', false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {
          '97:1': 5,
          '97:2': 5,
          '97:3': 6,
        });

        speech.windowStartSeconds = 0;
        const qadr3to5 =
            'وَخَيْرٌ مِنْ أَلْفِ شَهْرٍ تَنَزَّلُ الْمَلَائِكَةُ وَالرُّوحُ فِيهَا بِإِذْنِ رَبِّهِمْ مِنْ كُلِّ أَمْحٍ سَلَامٌ هِيَ حَتَّى مَطْلَعِ الْفَجْرِ';
        speech.result!(qadr3to5, false);
        await tester.pumpAndSettle();
        expect(page(tester).revealedWordCounts, {
          '97:1': 5,
          '97:2': 5,
          '97:3': 6,
          '97:4': 9,
          '97:5': 5,
        });

        speech.result!(qadr3to5, true);
        await tester.pumpAndSettle();
        expect(_hidden(tester), isEmpty);
        expect(find.text('Unaided matches: 2 · Assisted: 0'), findsOneWidget);
      },
    );

    testWidgets('step practice also hides interim words and raw transcript', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      await _open(tester, speech, localQuranLab: true);
      await _tap(tester, 'Live word preview (unverified)');
      await _start(tester);
      speech.result!(_first, false);
      await tester.pumpAndSettle();
      expect(page(tester).revealedWordCounts, isEmpty);
      expect(page(tester).highlightedWordIndices, isEmpty);
      expect(_hidden(tester), {'1:1', '1:2'});
      expect(find.textContaining('Recognized words:'), findsNothing);
      speech.result!(_first, true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:2'});
    });
  });

  testWidgets('word previews revise and never commit interim progress', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    final ayahs = [_first, _second].indexed.map((entry) {
      final (index, text) = entry;
      return Ayah(
        surahNumber: 1,
        ayahNumber: index + 1,
        pageNumber: 1,
        arabic: text,
        imlaei: text,
        translations: const {},
        words: [
          for (final word in text.split(' '))
            TajweedWord(arabic: word, spans: const [], lineNumber: index + 1),
        ],
      );
    }).toList();
    MushafPageContent page() =>
        tester.widget<MushafPageContent>(find.byType(MushafPageContent));
    await _open(tester, speech, continuous: true, ayahs: ayahs);
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!('بسم الله', false);
    await tester.pumpAndSettle();
    expect(page().revealedWordCounts, isEmpty);
    await _tap(tester, 'Live ayah preview (unconfirmed)');
    speech.result!('بسم الله الرحمن', false);
    await tester.pumpAndSettle();
    expect(page().revealedWordCounts, {'1:1': 3});
    expect(page().highlightedWordIndices, {
      '1:1': {0, 1, 2},
    });
    expect(find.text('Unaided matches: 0 · Hint-assisted: 0'), findsOneWidget);
    speech.result!('بسم الكريم', false);
    await tester.pumpAndSettle();
    expect(page().revealedWordCounts, {'1:1': 1});
    expect(page().highlightedWordIndices, {
      '1:1': {0},
    });
    speech.result!('بسم لل', false);
    await tester.pumpAndSettle();
    expect(page().revealedWordCounts, {'1:1': 1});
    speech.error!('test_error');
    await tester.pumpAndSettle();
    expect(page().revealedWordCounts, isEmpty);
    expect(page().highlightedWordIndices, isEmpty);
    expect(_hidden(tester), {'1:1', '1:2'});
    expect(find.text('Unaided matches: 0 · Hint-assisted: 0'), findsOneWidget);
  });

  testWidgets('speech failure and Retry preserve confirmed page and ayah', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    final nextPage = Ayah(
      surahNumber: 1,
      ayahNumber: 2,
      pageNumber: 2,
      arabic: _second,
      imlaei: _second,
      translations: const {},
      words: const [TajweedWord(arabic: _second, spans: [], lineNumber: 1)],
      endLineNumber: 1,
    );
    await _open(
      tester,
      speech,
      continuous: true,
      ayahs: [_ayah(1, _first), nextPage],
    );
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!('$_first الحمد', true);
    await tester.pumpAndSettle();
    expect(find.text('Ayah 2 / 2'), findsOneWidget);
    expect(
      tester
          .widget<MushafPageContent>(find.byType(MushafPageContent))
          .pageNumber,
      2,
    );
    await _tap(tester, 'Resume');
    speech.error!('error_unknown (300)');
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Ayah 2 / 2'), findsOneWidget);
    expect(_hidden(tester), {'1:2'});
    expect(find.text('Unaided matches: 1 · Hint-assisted: 0'), findsOneWidget);
    expect(
      tester
          .widget<MushafPageContent>(find.byType(MushafPageContent))
          .pageNumber,
      2,
    );
    await _tap(tester, 'Retry');
    speech.result!('لله رب العالمين', true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), isEmpty);
    expect(find.text('Unaided matches: 2 · Hint-assisted: 0'), findsOneWidget);
  });

  testWidgets('live preview is opt-in and disabling it masks previews', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech, continuous: true);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!(_first, false);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:1', '1:2'});
    await _tap(tester, 'Live ayah preview (unconfirmed)');
    speech.result!(_first, false);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:2'});
    await _tap(tester, 'Live ayah preview (unconfirmed)');
    expect(_hidden(tester), {'1:1', '1:2'});
    expect(find.text('Unaided matches: 0 · Hint-assisted: 0'), findsOneWidget);
  });

  testWidgets('a mismatching final result discards a matching preview', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech, continuous: true);
    await _tap(tester, 'Live ayah preview (unconfirmed)');
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!('$_first $_second', false);
    await tester.pumpAndSettle();
    expect(_hidden(tester), isEmpty);
    speech.result!('بسم الكريم', true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:1', '1:2'});
    expect(find.text('Ayah 1 / 2'), findsOneWidget);
    expect(find.text('Unaided matches: 0 · Hint-assisted: 0'), findsOneWidget);
  });

  testWidgets('live previews revise without counting or advancing ayahs', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech, continuous: true);
    await _tap(tester, 'Live ayah preview (unconfirmed)');
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!('$_first $_second', false);
    await tester.pumpAndSettle();
    expect(_hidden(tester), isEmpty);
    expect(find.textContaining('Preview only'), findsOneWidget);
    expect(find.text('Ayah 1 / 2'), findsOneWidget);
    expect(find.text('Unaided matches: 0 · Hint-assisted: 0'), findsOneWidget);
    speech.result!('$_first الحمد', false);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:2'});
    speech.result!('بسم الكريم', false);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:1', '1:2'});
    speech.result!(_first, true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:2'});
    expect(find.textContaining('Preview only'), findsNothing);
    expect(find.text('Ayah 2 / 2'), findsOneWidget);
    expect(find.text('Unaided matches: 1 · Hint-assisted: 0'), findsOneWidget);
  });

  for (final ending in ['done', 'error', 'pause', 'hint']) {
    testWidgets('unconfirmed preview clears on $ending', (tester) async {
      final speech = _FakeSpeech();
      await _open(tester, speech, continuous: true);
      await _tap(tester, 'Live ayah preview (unconfirmed)');
      await _tap(tester, 'Start reciting');
      await _tap(tester, 'Agree and continue');
      speech.result!(_first, false);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:2'});
      switch (ending) {
        case 'done':
          speech.done!();
        case 'error':
          speech.error!('test_error');
        case 'pause':
          await _tap(tester, 'Pause');
        case 'hint':
          await _tap(tester, 'Need a hint?');
      }
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
      expect(find.textContaining('Preview only'), findsNothing);
      expect(find.text('Ayah 1 / 2'), findsOneWidget);
    });
  }

  testWidgets('final Alif alone survives Resume for Lam and Meem', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    final opening = Ayah(
      surahNumber: 2,
      ayahNumber: 1,
      pageNumber: 2,
      arabic: 'الٓمٓ',
      imlaei: 'الم',
      translations: const {},
      words: const [TajweedWord(arabic: 'الٓمٓ', spans: [], lineNumber: 1)],
      endLineNumber: 1,
    );
    await _open(tester, speech, ayahs: [opening], continuous: true);
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!('1000', true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), contains('2:1'));
    expect(find.textContaining('1000'), findsOneWidget);
    await _tap(tester, 'Resume');
    speech.result!('لام ميم', true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), isEmpty);
  });

  for (final continuous in [false, true]) {
    testWidgets('spoken Alif aliases reveal Baqarah opening ($continuous)', (
      tester,
    ) async {
      final speech = _FakeSpeech();
      final opening = Ayah(
        surahNumber: 2,
        ayahNumber: 1,
        pageNumber: 2,
        juzNumber: 1,
        arabic: 'الٓمٓ',
        imlaei: 'الم',
        translations: const {},
        words: const [TajweedWord(arabic: 'الٓمٓ', spans: [], lineNumber: 1)],
        endLineNumber: 1,
      );
      await _open(tester, speech, ayahs: [opening], continuous: continuous);
      await _tap(tester, continuous ? 'Start reciting' : 'Recite ayah');
      await _tap(tester, 'Agree and continue');
      speech.result!('1000 لام ميم', false);
      await tester.pumpAndSettle();
      expect(_hidden(tester), contains('2:1'));
      speech.result!('1000 لام ميم', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), isEmpty);
      expect(
        tester
            .widget<MushafPageContent>(find.byType(MushafPageContent))
            .ayahs
            .single
            .arabic,
        'الٓمٓ',
      );
    });
  }

  testWidgets('continuous recognition advances onto the next full page', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    final second = Ayah(
      surahNumber: 1,
      ayahNumber: 2,
      pageNumber: 2,
      arabic: _second,
      imlaei: _second,
      translations: const {},
      words: const [TajweedWord(arabic: _second, spans: [], lineNumber: 1)],
      endLineNumber: 1,
    );
    await _open(
      tester,
      speech,
      continuous: true,
      ayahs: [_ayah(1, _first), second],
    );
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!(_first, true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MushafPageContent>(find.byType(MushafPageContent))
          .pageNumber,
      2,
    );
    expect(_hidden(tester), {'1:2'});
    await _tap(tester, 'Resume');
    speech.result!(_second, true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Surah practice finished'), findsOneWidget);
  });

  testWidgets('later mismatch reveals only confirmed earlier ayahs', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech, continuous: true);
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!('$_first الحمد لله رب الناس', true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:2'});
    expect(find.text('Ayah 2 / 2'), findsOneWidget);
    expect(
      find.textContaining('The recognized words do not match'),
      findsOneWidget,
    );
    await _tap(tester, 'Resume');
    speech.result!(_second, true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), isEmpty);
  });

  testWidgets(
    'silence and manual Pause never turn partial words into a match or hint',
    (tester) async {
      final speech = _FakeSpeech();
      await _open(tester, speech, continuous: true);
      await _tap(tester, 'Start reciting');
      await _tap(tester, 'Agree and continue');
      speech.result!(_first, false);
      await tester.pumpAndSettle();
      await _tap(tester, 'Pause');
      speech.result!(_first, true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
      await _tap(tester, 'Resume');
      speech.done!();
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
      expect(
        tester
            .widget<MushafPageContent>(find.byType(MushafPageContent))
            .hintedWords,
        isEmpty,
      );
      expect(find.textContaining('Recognition paused'), findsOneWidget);
    },
  );

  testWidgets(
    'hint and reference interrupt ongoing recognition and ignore its late text',
    (tester) async {
      final speech = _FakeSpeech();
      await _open(tester, speech, continuous: true);
      await _tap(tester, 'Start reciting');
      await _tap(tester, 'Agree and continue');
      final beforeHint = speech.result!;
      await _tap(tester, 'Need a hint?');
      beforeHint(_first, true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
      await _tap(tester, 'Resume');
      final beforeReference = speech.result!;
      await _tap(tester, 'Listen to reference');
      beforeReference(_first, true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
      expect(speech.cancellations, greaterThan(1));
    },
  );

  testWidgets(
    'failed full-page load cannot start the microphone; retry is explicit',
    (tester) async {
      final speech = _FakeSpeech();
      var failed = true;
      await _open(
        tester,
        speech,
        continuous: true,
        loadPage: (_) async {
          if (failed) throw StateError('Missing neighboring surahs');
          return [_ayah(1, _first), _ayah(2, _second)];
        },
      );
      expect(find.byType(MushafPageContent), findsNothing);
      await _tap(tester, 'Start reciting');
      expect(speech.starts, 0);
      expect(find.text('Optional voice word checking'), findsNothing);
      failed = false;
      await _tap(tester, AppLocalizations(const Locale('en')).get('retry'));
      expect(find.byType(MushafPageContent), findsOneWidget);
    },
  );

  testWidgets('continuous recitation confirms ayahs without a Next tap', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech, continuous: true);
    await _tap(tester, 'Start reciting');
    await _tap(tester, 'Agree and continue');
    speech.result!('$_first $_second', false);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:1', '1:2'});
    speech.result!('$_first $_second', true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), isEmpty);
    expect(find.textContaining('Surah practice finished'), findsOneWidget);
    expect(find.text('Next ayah'), findsNothing);
    expect(find.text('Unaided matches: 2 · Hint-assisted: 0'), findsOneWidget);
  });

  testWidgets(
    'continuous session resumes a partial next ayah and ignores late callbacks',
    (tester) async {
      final speech = _FakeSpeech();
      await _open(tester, speech, continuous: true);
      await _tap(tester, 'Start reciting');
      await _tap(tester, 'Agree and continue');
      final old = speech.result!;
      speech.result!('$_first الحمد لله', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:2'});
      expect(find.text('Ayah 2 / 2'), findsOneWidget);
      await _tap(tester, 'Resume');
      old('$_first $_second', true);
      speech.result!('رب العالمين', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), isEmpty);
      expect(find.textContaining('Surah practice finished'), findsOneWidget);
      expect(speech.starts, 2);
    },
  );

  testWidgets(
    'hint exposes opening words in place and keeps neighboring surahs',
    (tester) async {
      final speech = _FakeSpeech();
      final practiced = Ayah(
        surahNumber: 112,
        ayahNumber: 1,
        pageNumber: 604,
        juzNumber: 30,
        arabic: 'قل هو الله أحد',
        imlaei: 'قل هو الله أحد',
        translations: const {},
        words: [
          for (final word in ['قل', 'هو', 'الله', 'أحد'])
            TajweedWord(arabic: word, spans: const [], lineNumber: 1),
        ],
        endLineNumber: 1,
      );
      final neighbor = Ayah(
        surahNumber: 113,
        ayahNumber: 1,
        pageNumber: 604,
        juzNumber: 30,
        arabic: 'قل أعوذ برب الفلق',
        translations: const {},
        words: [
          for (final word in ['قل', 'أعوذ', 'برب', 'الفلق'])
            TajweedWord(arabic: word, spans: const [], lineNumber: 3),
        ],
        endLineNumber: 3,
      );
      await _open(
        tester,
        speech,
        continuous: true,
        ayahs: [practiced],
        loadPage: (_) async => [practiced, neighbor],
      );
      await _tap(tester, 'Need a hint?');
      final page = tester.widget<MushafPageContent>(
        find.byType(MushafPageContent),
      );
      expect(page.ayahs, [practiced, neighbor]);
      expect(page.hiddenAyahs, {'112:1'});
      expect(page.hintedWords, {'112:1': 2});
      expect(page.ayahs.last.endLineNumber, 3);
      await _tap(tester, 'Start reciting');
      await _tap(tester, 'Agree and continue');
      speech.result!('قل هو الله أحد', true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), isEmpty);
      expect(
        find.text('Unaided matches: 0 · Hint-assisted: 1'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Review has all text visible and never requests speech', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech, continuous: true, review: true);
    expect(_hidden(tester), isEmpty);
    expect(find.text('Start reciting'), findsNothing);
    expect(find.text('Need a hint?'), findsNothing);
    await _tap(tester, 'Listen to reference');
    expect(speech.starts, 0);
    await _tap(tester, 'Next ayah');
    expect(find.text('Ayah 2 / 2'), findsOneWidget);
  });

  test('surah completeness rejects partial, duplicate and foreign verses', () {
    final ayahs = [_ayah(1, _first), _ayah(2, _second)];
    expect(
      MemorizationScreen.isCompleteSurah(
        ayahs,
        surahNumber: 1,
        expectedCount: 2,
      ),
      isTrue,
    );
    for (final invalid in [
      [ayahs.first],
      [ayahs.first, ayahs.first],
      [ayahs.first, _ayah(3, _second)],
    ]) {
      expect(
        MemorizationScreen.isCompleteSurah(
          invalid,
          surahNumber: 1,
          expectedCount: 2,
        ),
        isFalse,
      );
    }
    expect(
      MemorizationScreen.isCompleteSurah(
        ayahs,
        surahNumber: 2,
        expectedCount: 2,
      ),
      isFalse,
    );
  });

  testWidgets('surah practice crosses pages and completes only at surah end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final speech = _FakeSpeech();
    final secondPage = Ayah(
      surahNumber: 1,
      ayahNumber: 2,
      pageNumber: 2,
      juzNumber: 2,
      arabic: _second,
      imlaei: _second,
      translations: const {},
      words: [TajweedWord(arabic: _second, spans: const [], lineNumber: 1)],
    );
    await _open(tester, speech, ayahs: [_ayah(1, _first), secondPage]);
    MushafPageContent page() => tester.widget(find.byType(MushafPageContent));
    expect(page().pageNumber, 1);
    expect(find.text('Juz 1'), findsOneWidget);
    expect(page().ayahs.map((ayah) => ayah.ayahNumber), [1]);
    expect(find.text('Ayah 1 / 2'), findsOneWidget);
    await _start(tester);
    speech.result!(_first, true);
    await tester.pumpAndSettle();
    await _tap(tester, 'Next ayah');
    expect(page().pageNumber, 2);
    expect(find.text('Juz 2'), findsOneWidget);
    expect(page().ayahs.map((ayah) => ayah.ayahNumber), [2]);
    expect(page().hiddenAyahs, contains('1:2'));
    expect(find.text('Ayah 2 / 2'), findsOneWidget);
    expect(find.textContaining('Surah practice finished'), findsNothing);
    await _tap(tester, 'Recite ayah');
    speech.result!(_second, true);
    await tester.pumpAndSettle();
    await _tap(tester, 'Next ayah');
    expect(find.textContaining('Surah practice finished'), findsOneWidget);
  });

  testWidgets('no voice initialization until explicit consent', (tester) async {
    final speech = _FakeSpeech();
    await _open(tester, speech);
    expect(speech.starts, 0);
    await _tap(tester, 'Recite ayah');
    expect(speech.starts, 0);
    expect(find.text('Optional voice word checking'), findsOneWidget);
    await _tap(tester, 'Cancel');
    expect(speech.starts, 0);
    expect(_hidden(tester), {'1:1', '1:2'});
  });

  testWidgets(
    'partial full words do not pass; final match reveals only target',
    (tester) async {
      final speech = _FakeSpeech();
      await _open(tester, speech);
      await _start(tester);
      speech.result!(_first, false);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
      speech.result!(_first, true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:2'});
      expect(
        find.text('Recognized words match the full ayah.'),
        findsOneWidget,
      );
      // Late native errors must not revoke or change a finalized result.
      speech.error!('late_error');
      await tester.pumpAndSettle();
      expect(
        find.text('Recognized words match the full ayah.'),
        findsOneWidget,
      );
    },
  );

  for (final text in ['بسم الله', 'بسم الله الرحمن الكريم', '$_first الرحيم']) {
    testWidgets('mismatch does not reveal or advance: $text', (tester) async {
      final speech = _FakeSpeech();
      await _open(tester, speech);
      await _start(tester);
      speech.result!(text, true);
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
      expect(
        find.textContaining('The recognized words do not match.'),
        findsOneWidget,
      );
      final next = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Next ayah'),
      );
      expect(next.onPressed, isNull);
    });
  }

  testWidgets('retry uses new attempt and ignores previous callbacks', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech);
    await _start(tester);
    final old = speech.result!;
    old('بسم', true);
    await tester.pumpAndSettle();
    await _tap(tester, 'Recite ayah');
    expect(speech.starts, 2);
    old(_first, true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:1', '1:2'});
    speech.result!(_first, true);
    await tester.pumpAndSettle();
    expect(_hidden(tester), {'1:2'});
  });

  testWidgets('hint reveals but does not initialize speech or count as match', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech);
    await _tap(tester, 'Reveal as a hint');
    expect(speech.starts, 0);
    expect(_hidden(tester), {'1:2'});
    expect(find.text('Revealed as a hint, not a voice match.'), findsOneWidget);
    await _tap(tester, 'Next ayah');
    expect(_hidden(tester), {'1:2'});
    expect(
      find.text('Recite from memory, then stop to check.'),
      findsOneWidget,
    );
  });

  testWidgets('missing complete text cannot request speech access', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech, referenceAvailable: false);
    await _tap(tester, 'Recite ayah');
    expect(speech.starts, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.textContaining('Complete matching text is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('background cancels and ignores late final results', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    var audioStops = 0;
    await _open(
      tester,
      speech,
      stopReference: () async {
        audioStops++;
      },
    );
    await _start(tester);
    final stops = audioStops;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    speech.result!(_first, true);
    await tester.pumpAndSettle();
    expect(speech.cancellations, greaterThan(0));
    expect(audioStops, greaterThan(stops));
    expect(_hidden(tester), {'1:1', '1:2'});
    expect(find.textContaining('Recognized words: '), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  });

  testWidgets('dispose cancels input and late callback is harmless', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    await _open(tester, speech);
    await _start(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    speech.result!(_first, true);
    expect(speech.cancellations, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reference audio alone cannot pass and stops before voice', (
    tester,
  ) async {
    final speech = _FakeSpeech();
    final events = <String>[];
    await _open(
      tester,
      speech,
      playReference: (_) async {
        events.add('play');
        return true;
      },
      stopReference: () async {
        events.add('stop');
      },
    );
    await _tap(tester, 'Listen to reference');
    expect(events, ['stop', 'play']);
    expect(_hidden(tester), {'1:1', '1:2'});
    await _start(tester);
    expect(events.last, 'stop');
    expect(speech.starts, 1);
  });

  testWidgets(
    'native speech errors leave the ayah hidden and retry available',
    (tester) async {
      final speech = _FakeSpeech();
      await _open(tester, speech);
      await _start(tester);
      speech.error!('permission_denied');
      await tester.pumpAndSettle();
      expect(_hidden(tester), {'1:1', '1:2'});
      expect(
        find.textContaining('Arabic speech recognition failed'),
        findsOneWidget,
      );
      await _tap(tester, 'Retry');
      expect(speech.starts, 2);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'small-phone layout and consent are localized in ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l10n = AppLocalizations(locale);
        final speech = _FakeSpeech();
        await _open(tester, speech, locale: locale, continuous: true);
        expect(find.textContaining(l10n.get('tab_hifz')), findsOneWidget);
        expect(find.text(l10n.get('hifz_hint')), findsOneWidget);
        await _tap(tester, l10n.get('hifz_start'));
        expect(find.text(l10n.get('mem_consent_title')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
