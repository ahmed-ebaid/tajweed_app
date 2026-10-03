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
