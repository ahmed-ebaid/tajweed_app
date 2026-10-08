import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/providers/locale_provider.dart';
import 'package:tajweed_practice/features/rules/rule_detail_screen.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/widgets/rule_guidance_text.dart';
import 'package:tajweed_practice/features/rules/widgets/rule_example_text.dart';

void main() {
  late Directory temp;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('AmiriQuran')
      ..addFont(rootBundle.load('assets/fonts/AmiriQuran.ttf'));
    await loader.load();
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rule_layout_test_');
    Hive.init(temp.path);
    await Hive.openBox<dynamic>('settings');
  });
  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  testWidgets('all rule examples fit every locale with enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final supported in AppLocalizations.supportedLocales) {
      final locale = LocaleProvider(deviceLocales: () => [supported]);
      for (final brightness in Brightness.values) {
        for (final definition in RulesRepository.all) {
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: locale,
              child: MaterialApp(
                locale: supported,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.6)),
                  child: child!,
                ),
                home: RuleDetailScreen(
                  key: ValueKey(
                    '${supported.languageCode}-$brightness-${definition.rule}',
                  ),
                  definition: definition,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final label =
              '${supported.languageCode}/${definition.rule.name}/$brightness';
          expect(tester.takeException(), isNull, reason: label);
          final examples = find.byType(RuleExampleText);
          expect(
            examples,
            findsNWidgets(
              definition.rule == TajweedRule.waqf
                  ? 0
                  : definition.exampleArabic.length,
            ),
            reason: label,
          );
          for (final element in examples.evaluate()) {
            final text = find.descendant(
              of: find.byWidget(element.widget),
              matching: find.byType(Text),
            );
            final widget = tester.widget<Text>(text);
            expect(widget.maxLines, isNull, reason: label);
            expect(
              widget.overflow,
              isNot(TextOverflow.ellipsis),
              reason: label,
            );
            final rect = tester.getRect(text);
            expect(rect.left, greaterThanOrEqualTo(0), reason: label);
            expect(rect.right, lessThanOrEqualTo(320), reason: label);
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      locale.dispose();
    }
  });

  testWidgets('rule headings fit and bullets follow the first text baseline', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final definition = RulesRepository.findByRule(TajweedRule.silent)!;
    final shares = <MethodCall>[];
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          shares.add(call);
          return 'success';
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
    });
    for (final language in ['ar', 'es', 'ur', 'en']) {
      final locale = LocaleProvider(deviceLocales: () => [Locale(language)]);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: locale,
          child: MaterialApp(
            locale: locale.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: RuleDetailScreen(
              key: ValueKey(language),
              definition: definition,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: language);
      if (language == 'ar') {
        // One app-bar label and one large title; no duplicate subtitle.
        expect(find.text(definition.rule.arabicName), findsNWidgets(2));
      }
      for (final bullet in find.text('•').evaluate()) {
        final row = find
            .ancestor(
              of: find.byWidget(bullet.widget),
              matching: find.byType(Row),
            )
            .first;
        final guidance = find.descendant(
          of: row,
          matching: find.byType(RuleGuidanceText),
        );
        final bulletBox = bullet.renderObject! as RenderBox;
        final textBox = tester.renderObject<RenderBox>(
          find.descendant(of: guidance, matching: find.byType(RichText)),
        );
        double baseline(RenderBox box) =>
            box.localToGlobal(Offset.zero).dy +
            box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;
        expect(baseline(bulletBox), closeTo(baseline(textBox), 0.1));
      }
      await tester.tap(
        find.byTooltip(AppLocalizations(locale.locale).get('share_rule')),
      );
      await tester.pumpAndSettle();
      final payload = shares.last.arguments as Map;
      final sharedText = payload['text'] as String;
      expect(sharedText, isNot(contains('(و۟)')));
      expect(sharedText, isNot(contains('(بۡ)')));
      expect(sharedText, isNot(contains('(۟)')));
      expect(sharedText, isNot(contains('(ۡ)')));
      for (final example in definition.exampleArabic) {
        expect(sharedText, contains(example));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      locale.dispose();
    }
  });

  testWidgets(
    'Hamzat al-Wasl guidance uses Quranic small-head sukoon in all languages',
    (tester) async {
      const languages = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
      const examples = [
        'ٱهۡدِنَا',
        'ٱلۡحَمۡدُ',
        'ٱسۡتَغۡفِرُوا',
        'ٱدۡخُلُوا',
        'يَدۡخُلُ',
        'ٱضۡرِبُوا',
        'يَضۡرِبُ',
      ];
      const ordinarySukoon = '\u0652';
      const roundedZero = '\u06DF';
      final definition = RulesRepository.findByRule(TajweedRule.hamzatWasl)!;

      for (final language in languages) {
        final locale = LocaleProvider(deviceLocales: () => [Locale(language)]);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: locale,
            child: MaterialApp(
              locale: locale.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: RuleDetailScreen(
                key: ValueKey('hamzat-wasl-$language'),
                definition: definition,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final guidance = find
            .byType(RuleGuidanceText)
            .evaluate()
            .map((element) => (element.widget as RuleGuidanceText).text)
            .join('\n');
        for (final example in examples) {
          expect(
            guidance,
            contains(example),
            reason: '$language guidance is missing $example',
          );
        }
        expect(guidance, isNot(contains(ordinarySukoon)), reason: language);
        expect(guidance, isNot(contains(roundedZero)), reason: language);
        expect(tester.takeException(), isNull, reason: language);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        locale.dispose();
      }
    },
  );
}
