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
      expect(sharedText, contains('(و۟)'));
      expect(sharedText, contains('(بۡ)'));
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
}
