import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/providers/locale_provider.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/features/reader/widgets/tajweed_text.dart';
import 'package:tajweed_practice/features/reader/widgets/word_detail_sheet.dart';

String coloredText(InlineSpan root, Color color) {
  final result = StringBuffer();
  root.visitChildren((span) {
    if (span is TextSpan && span.style?.color == color) {
      result.write(span.text ?? '');
    }
    return true;
  });
  return result.toString();
}

void main() {
  late Directory temp;
  late LocaleProvider locale;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('word_detail_test_');
    Hive.init(temp.path);
    await Hive.openBox<dynamic>('settings');
    locale = LocaleProvider(deviceLocales: () => [const Locale('ar')]);
  });

  tearDown(() async {
    locale.dispose();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  final ayah = AyahMapper.fromApi({
    'verse_key': '36:59',
    'words': [
      {
        'char_type_name': 'word',
        'text_uthmani_tajweed':
            'وَ<rule class=ham_wasl>ٱ</rule>مۡتَ'
            '<rule class=madda_normal>ـٰ</rule>زُو'
            '<rule class=slnt>اۡ</rule>',
      },
    ],
  });

  Widget subject(Widget child, {bool dark = false}) =>
      ChangeNotifierProvider.value(
        value: locale,
        child: MaterialApp(
          locale: locale.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: Scaffold(body: child),
        ),
      );

  testWidgets('36:59 word header colors only the madd carrier', (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        subject(
          WordDetailSheet(
            rule: TajweedRule.maddTabeei,
            word: ayah.words.single,
            ayah: ayah,
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      final header = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const Key('word_detail_header')),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(coloredText(header.text, TajweedRule.maddTabeei.color), 'تَـٰ');
      expect(header.text.toPlainText(), ayah.words.single.arabic);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('both reader layouts pass the original annotated word on tap', (
    tester,
  ) async {
    for (final compact in [false, true]) {
      TajweedWord? tappedWord;
      TajweedRule? tappedRule;
      await tester.pumpWidget(
        subject(
          Builder(
            builder: (context) => TajweedText(
              ayah: ayah,
              compactFlow: compact,
              onRuleTapped: (rule, word, _) {
                tappedRule = rule;
                tappedWord = word;
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => WordDetailSheet(rule: rule, word: word),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final richFinder = find
          .descendant(
            of: find.byType(TajweedText),
            matching: find.byType(RichText),
          )
          .first;
      final paragraph = tester.renderObject<RenderParagraph>(richFinder);
      expect(coloredText(paragraph.text, TajweedRule.maddTabeei.color), 'تَـٰ');
      final start = paragraph.text.toPlainText().indexOf('ـٰ');
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + 2),
          )
          .first;
      await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
      await tester.pumpAndSettle();
      expect(tappedRule, TajweedRule.maddTabeei);
      expect(identical(tappedWord, ayah.words.single), isTrue);
      expect(tappedWord!.spans, hasLength(3));
      final header = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const Key('word_detail_header')),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(coloredText(header.text, TajweedRule.maddTabeei.color), 'تَـٰ');
      Navigator.of(tester.element(find.byType(WordDetailSheet))).pop();
      await tester.pumpAndSettle();
    }
  });

  for (final fixture in [
    (
      name: 'Hud 11:58 Idgham with Ghunnah',
      verseKey: '11:58',
      html: 'بِرَحۡمَ<rule class=idgham_ghunnah>ةٍ</rule>',
      rule: TajweedRule.idghamWithGhunnah,
      expected: 'ةٍ',
      expectedWord: 'بِرَحۡمَةٍ مِّنَّا',
      expectedHeaderColor: 'ةٍمِّ',
      otherRule: null,
      continuation: 'مِّنَّا',
      continuationHtml:
          '<rule class=idgham_ghunnah>م</rule>ِّ'
          '<rule class=ghunnah>نّ</rule>َا',
    ),
    (
      name: 'Hud 11:61 Madd Tabeei beside Ikhafa',
      verseKey: '11:61',
      html:
          'صَ<rule class=madda_normal>ـٰ</rule>'
          'لِ<rule class=ikhafa>حًا‌ۚ</rule>',
      rule: TajweedRule.maddTabeei,
      expected: 'صَـٰ',
      expectedWord: 'صَـٰلِحًاۚ',
      expectedHeaderColor: 'صَـٰ',
      otherRule: TajweedRule.ikhfa,
      continuation: null,
      continuationHtml: null,
    ),
  ]) {
    testWidgets(
      '${fixture.name} keeps the selected highlight precise after a real tap',
      (tester) async {
        final fixtureAyah = AyahMapper.fromApi({
          'verse_key': fixture.verseKey,
          'words': [
            {'char_type_name': 'word', 'text_uthmani_tajweed': fixture.html},
          ],
        });
        final contextAyah = AyahMapper.fromApi({
          'verse_key': fixture.verseKey,
          'words': [
            {'char_type_name': 'word', 'text_uthmani_tajweed': fixture.html},
            if (fixture.continuationHtml case final continuationHtml?)
              {
                'char_type_name': 'word',
                'text_uthmani_tajweed': continuationHtml,
              },
          ],
        });
        for (final compact in [false, true]) {
          for (final dark in [false, true]) {
            await tester.pumpWidget(
              subject(
                Builder(
                  builder: (context) => TajweedText(
                    ayah: fixtureAyah,
                    compactFlow: compact,
                    onRuleTapped: (rule, tappedWord, _) {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => WordDetailSheet(
                          rule: rule,
                          word: tappedWord,
                          ayah: contextAyah,
                        ),
                      );
                    },
                  ),
                ),
                dark: dark,
              ),
            );
            await tester.pumpAndSettle();

            final richFinder = find
                .descendant(
                  of: find.byType(TajweedText),
                  matching: find.byType(RichText),
                )
                .first;
            final paragraph = tester.renderObject<RenderParagraph>(richFinder);
            final colored = coloredText(paragraph.text, fixture.rule.color);
            expect(colored, fixture.expected, reason: fixture.name);
            final start = paragraph.text.toPlainText().indexOf(colored);
            expect(start, isNonNegative, reason: fixture.name);
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: start,
                extentOffset: start + colored.length,
              ),
            );
            expect(boxes, isNotEmpty, reason: fixture.name);
            await tester.tapAt(
              paragraph.localToGlobal(boxes.first.toRect().center),
            );
            await tester.pumpAndSettle();

            final header = tester.widget<RichText>(
              find
                  .descendant(
                    of: find.byKey(const Key('word_detail_header')),
                    matching: find.byType(RichText),
                  )
                  .first,
            );
            expect(
              coloredText(header.text, fixture.rule.color),
              fixture.expectedHeaderColor,
              reason: '${fixture.name}, compact=$compact, dark=$dark',
            );
            if (fixture.otherRule case final otherRule?) {
              expect(
                coloredText(header.text, otherRule.color),
                isEmpty,
                reason: '${fixture.name} keeps the adjacent rule neutral',
              );
            }
            expect(
              header.text.toPlainText(),
              fixture.expectedWord,
              reason: fixture.name,
            );
            if (fixture.continuation case final continuation?) {
              final contextTajweed = find.descendant(
                of: find.byType(WordDetailSheet),
                matching: find.byType(TajweedText),
              );
              final contextRich = find.descendant(
                of: contextTajweed.first,
                matching: find.byType(RichText),
              );
              final contextText = tester.widget<RichText>(contextRich.first);
              expect(
                contextText.text.toPlainText(),
                contains(continuation),
                reason: '${fixture.name} keeps the cross-word rule context',
              );
              expect(
                coloredText(contextText.text, fixture.rule.color),
                contains('ةٍم'),
                reason: '${fixture.name} highlights both sides of Idgham',
              );
            }
            expect(tester.takeException(), isNull, reason: fixture.name);
            Navigator.of(tester.element(find.byType(WordDetailSheet))).pop();
            await tester.pumpAndSettle();
          }
        }
      },
    );
  }

  testWidgets('every Quran cross-word rule opens the complete rule context', (
    tester,
  ) async {
    final fixtures = [
      (
        name: 'idgham with ghunnah',
        rule: TajweedRule.idghamWithGhunnah,
        left: 'هُ<rule class=idgham_ghunnah>دًى</rule>',
        right: '<rule class=idgham_ghunnah>م</rule>ِّن',
        selectableIndices: [0, 1],
      ),
      (
        name: 'idgham without ghunnah',
        rule: TajweedRule.idghamWithoutGhunnah,
        left: 'هُ<rule class=idgham_wo_ghunnah>دًى</rule>',
        right: '<rule class=idgham_wo_ghunnah>ل</rule>ِّلۡمُتَّقِينَ',
        selectableIndices: [0, 1],
      ),
      (
        name: 'idgham shafawi',
        rule: TajweedRule.idghamShafawi,
        left: 'قُلُوبِه<rule class=idgham_shafawi>ِم</rule>',
        right: '<rule class=idgham_shafawi>م</rule>َّرَ',
        selectableIndices: [0, 1],
      ),
      (
        name: 'ikhfa',
        rule: TajweedRule.ikhfa,
        left: 'مِ<rule class=ikhfa>ن</rule>',
        right: '<rule class=ikhfa>ق</rule>َ',
        selectableIndices: [0, 1],
      ),
      (
        name: 'ikhfa shafawi',
        rule: TajweedRule.ikhfaShafawi,
        left: 'ه<rule class=ikhafa_shafawi>ُم</rule>',
        right: '<rule class=ikhafa_shafawi>ب</rule>ِمُؤْمِنِينَ',
        selectableIndices: [0, 1],
      ),
      (
        name: 'iqlab',
        rule: TajweedRule.iqlab,
        left: 'أَبَد<rule class=iqlab>َۢا</rule>',
        right: '<rule class=iqlab>ب</rule>ِمَا',
        selectableIndices: [0, 1],
      ),
      (
        name: 'madd munfasil',
        rule: TajweedRule.maddMunfasil,
        left: 'بِم<rule class=madda_obligatory_monfasel>َآ</rule>',
        right: 'أُ<rule class=ikhafa>نز</rule>ِلَ',
        selectableIndices: [0],
      ),
    ];

    for (final fixture in fixtures) {
      final ayah = AyahMapper.fromApi({
        'verse_key': '2:4',
        'words': [
          {'char_type_name': 'word', 'text_uthmani_tajweed': fixture.left},
          {'char_type_name': 'word', 'text_uthmani_tajweed': fixture.right},
        ],
      });
      for (final selectedIndex in fixture.selectableIndices) {
        final selectedWord = ayah.words[selectedIndex];
        final expectedFullContext = ayah.words
            .map((word) => word.arabic)
            .join(' ');
        await tester.pumpWidget(
          subject(
            Builder(
              builder: (context) => TajweedText(
                ayah: ayah,
                onRuleTapped: (rule, word, _) {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) =>
                        WordDetailSheet(rule: rule, word: word, ayah: ayah),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final selectedStyle = TextSpan(
          children: TajweedText.buildStyledWordSpans(
            selectedWord,
            baseStyle: const TextStyle(color: Colors.black),
            suppressedRules: TajweedRule.values
                .where((rule) => rule != fixture.rule)
                .toSet(),
          ),
        );
        final tapText = coloredText(selectedStyle, fixture.rule.color);
        expect(tapText, isNotEmpty, reason: fixture.name);
        final localStart = selectedWord.arabic.indexOf(tapText);
        expect(localStart, isNonNegative, reason: fixture.name);
        final precedingText = ayah.words
            .take(selectedIndex)
            .map((word) => word.arabic)
            .join(' ');
        final start = precedingText.isEmpty
            ? localStart
            : precedingText.length + 1 + localStart;
        final paragraph = tester.renderObject<RenderParagraph>(
          find
              .descendant(
                of: find.byType(TajweedText),
                matching: find.byType(RichText),
              )
              .first,
        );
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: start,
            extentOffset: start + tapText.length,
          ),
        );
        expect(boxes, isNotEmpty, reason: fixture.name);
        await tester.tapAt(
          paragraph.localToGlobal(boxes.first.toRect().center),
        );
        await tester.pumpAndSettle();

        final header = tester.widget<RichText>(
          find
              .descendant(
                of: find.byKey(const Key('word_detail_header')),
                matching: find.byType(RichText),
              )
              .first,
        );
        expect(
          header.text.toPlainText(),
          expectedFullContext,
          reason:
              '${fixture.name}, selected word $selectedIndex; '
              'spans=${ayah.words.map((word) => word.spans.map((s) => '${s.start}:${s.end}:${s.rule}').toList()).toList()}',
        );
        final coloredHeader = coloredText(header.text, fixture.rule.color);
        for (final word in ayah.words.where(
          (word) => word.spans.any((span) => span.rule == fixture.rule),
        )) {
          final wordStyle = TextSpan(
            children: TajweedText.buildStyledWordSpans(
              word,
              baseStyle: const TextStyle(color: Colors.black),
              suppressedRules: TajweedRule.values
                  .where((rule) => rule != fixture.rule)
                  .toSet(),
            ),
          );
          expect(
            coloredHeader,
            contains(coloredText(wordStyle, fixture.rule.color)),
            reason: '${fixture.name} must color each annotated side',
          );
        }
        Navigator.of(tester.element(find.byType(WordDetailSheet))).pop();
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('every rule preserves neutral letters and other annotations', (
    tester,
  ) async {
    for (final rule in TajweedRule.values) {
      final other = rule == TajweedRule.qalqalah
          ? TajweedRule.ghunnah
          : TajweedRule.qalqalah;
      final word = TajweedWord(
        arabic: 'بَتُثِ',
        spans: [
          TajweedSpan(start: 2, end: 4, rule: rule),
          TajweedSpan(start: 4, end: 6, rule: other),
        ],
      );
      await tester.pumpWidget(subject(WordDetailSheet(rule: rule, word: word)));
      await tester.pumpAndSettle();
      final rich = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const Key('word_detail_header')),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(coloredText(rich.text, rule.color), 'تُ', reason: rule.name);
      expect(coloredText(rich.text, other.color), isEmpty, reason: rule.name);
      expect(rich.text.toPlainText(), word.arabic);
    }
  });

  testWidgets('tanween narrowing is retained in the word detail header', (
    tester,
  ) async {
    for (final fixture in [
      (
        html: 'صَعِي<rule class=ikhafa>دًا</rule>',
        rule: TajweedRule.ikhfa,
        expected: 'دً',
      ),
      (
        html: 'ش<rule class=idgham_ghunnah>َىۡءٍ</rule>',
        rule: TajweedRule.idghamWithGhunnah,
        expected: 'ءٍ',
      ),
    ]) {
      final word = AyahMapper.fromApi({
        'verse_key': '18:45',
        'words': [
          {'char_type_name': 'word', 'text_uthmani_tajweed': fixture.html},
        ],
      }).words.single;
      await tester.pumpWidget(
        subject(WordDetailSheet(rule: fixture.rule, word: word)),
      );
      await tester.pumpAndSettle();
      final rich = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const Key('word_detail_header')),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(coloredText(rich.text, fixture.rule.color), fixture.expected);
      expect(rich.text.toPlainText(), word.arabic);
    }
  });

  test('dagger alif does not consume a separately annotated ghunnah', () {
    final word = AyahMapper.fromApi({
      'verse_key': '2:25',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani_tajweed':
              'جَ<rule class=ghunnah>نّ</rule>َ'
              '<rule class=madda_normal>ـٰ</rule>تٍ',
        },
      ],
    }).words.single;
    final styled = TextSpan(
      children: TajweedText.buildStyledWordSpans(
        word,
        baseStyle: const TextStyle(color: Colors.black),
      ),
    );
    expect(coloredText(styled, TajweedRule.ghunnah.color), 'نَّ');
    expect(coloredText(styled, TajweedRule.maddTabeei.color), 'ـٰ');
    expect(styled.toPlainText(), word.arabic);
  });

  test(
    'carrier extension handles double tatweel but leaves ordinary madd alone',
    () {
      for (final fixture in [
        (
          html: 'وَٱمۡتَ<rule class=madda_normal>ـٰ</rule>زُواۡ',
          expected: 'تَـٰ',
        ),
        (
          html: 'وَٱمۡتَ<rule class=madda_normal>ــٰ</rule>زُواۡ',
          expected: 'تَــٰ',
        ),
        (html: 'قَ<rule class=madda_normal>ا</rule>لَ', expected: 'ا'),
      ]) {
        final word = AyahMapper.fromApi({
          'verse_key': '36:59',
          'words': [
            {'char_type_name': 'word', 'text_uthmani_tajweed': fixture.html},
          ],
        }).words.single;
        final styled = TextSpan(
          children: TajweedText.buildStyledWordSpans(
            word,
            baseStyle: const TextStyle(color: Colors.black),
          ),
        );
        expect(
          coloredText(styled, TajweedRule.maddTabeei.color),
          fixture.expected,
        );
        expect(styled.toPlainText(), word.arabic);
      }
    },
  );

  testWidgets('localized sheets fit narrow screens in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in AppLocalizations.supportedLocales) {
      await tester.runAsync(() => locale.setLocale(language));
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          subject(
            WordDetailSheet(
              rule: TajweedRule.maddTabeei,
              word: ayah.words.single,
              ayah: ayah,
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${language.languageCode}, dark=$dark',
        );
      }
    }
  });
}
