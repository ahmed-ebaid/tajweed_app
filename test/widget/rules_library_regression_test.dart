import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/constants/app_links.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/features/rules/rules_screen.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/tajweed_article_detail_screen.dart';
import 'package:tajweed_practice/features/rules/tajweed_article_share_content.dart';
import 'package:tajweed_practice/features/rules/tajweed_articles_repository.dart';

Widget subject(
  Widget child,
  String language,
  TargetPlatform platform, {
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(platform: platform, brightness: brightness),
  home: child,
);

void main() {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final calls = <MethodCall>[];
  var failShare = false;
  setUp(() {
    calls.clear();
    failShare = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (failShare) throw PlatformException(code: 'share_failed');
          return 'success';
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'Madd al-Farq is an expandable sorted row inside the shared Madd group',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      for (final configuration in [
        (const Size(390, 844), Brightness.light),
        (const Size(390, 844), Brightness.dark),
        (const Size(1024, 1366), Brightness.light),
        (const Size(1024, 1366), Brightness.dark),
      ]) {
        tester.view.physicalSize = configuration.$1;
        for (final locale in AppLocalizations.supportedLocales) {
          final language = locale.languageCode;
          final l10n = AppLocalizations(locale);
          final article = TajweedArticlesRepository.all.singleWhere(
            (article) => article.id == 'madd_al_farq',
          );
          await tester.pumpWidget(
            subject(
              RulesScreen(
                key: ValueKey('$language-$configuration'),
                languageCodeOverride: language,
              ),
              language,
              TargetPlatform.iOS,
              brightness: configuration.$2,
            ),
          );
          await tester.pumpAndSettle();
          final farq = find.byKey(const ValueKey('madd_al_farq'));
          final farqHeader = find
              .descendant(of: farq, matching: find.byType(InkWell))
              .first;
          final maddGroup = find.byKey(const ValueKey('rules_category_madd'));
          await tester.ensureVisible(farqHeader);
          await tester.pumpAndSettle();
          expect(farq, findsOneWidget);
          expect(
            find.descendant(of: maddGroup, matching: farq),
            findsOneWidget,
          );
          expect(
            find.descendant(of: farq, matching: find.byType(ListTile)),
            findsNothing,
          );
          expect(
            find.descendant(
              of: farq,
              matching: find.byIcon(Icons.menu_book_rounded),
            ),
            findsNothing,
          );
          expect(
            find.descendant(of: farq, matching: find.byIcon(Icons.expand_more)),
            findsOneWidget,
          );
          final maddRules = RulesRepository.all.where(
            (definition) => definition.rule.name.startsWith('madd'),
          );
          final rows = [
            (article.title(language), farq),
            ...maddRules.map(
              (definition) => (
                definition.name(language),
                find.byKey(ValueKey(definition.rule)),
              ),
            ),
          ]..sort((a, b) => a.$1.compareTo(b.$1));
          for (var index = 0; index < rows.length; index++) {
            expect(
              find.descendant(of: maddGroup, matching: rows[index].$2),
              findsOneWidget,
            );
            if (index > 0) {
              expect(
                tester.getTopLeft(rows[index - 1].$2).dy,
                lessThan(tester.getTopLeft(rows[index].$2).dy),
              );
            }
          }
          expect(
            tester.getTopLeft(find.text(l10n.get('rules_category_madd'))).dy,
            lessThan(tester.getTopLeft(farq).dy),
          );
          expect(find.text(l10n.get('rules_category_madd')), findsOneWidget);
          final naturalMadd = RulesRepository.all.singleWhere(
            (definition) => definition.rule.name == 'maddTabeei',
          );
          final naturalRow = find.byKey(ValueKey(naturalMadd.rule));
          await tester.ensureVisible(farqHeader);
          await tester.pumpAndSettle();
          await tester.tap(farqHeader);
          await tester.pumpAndSettle();
          final naturalHeader = find
              .descendant(of: naturalRow, matching: find.byType(InkWell))
              .first;
          await tester.ensureVisible(naturalHeader);
          await tester.pumpAndSettle();
          await tester.tap(naturalHeader);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: farq, matching: find.byIcon(Icons.expand_more)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: naturalRow,
              matching: find.byIcon(Icons.expand_less),
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(naturalHeader);
          await tester.pumpAndSettle();
          await tester.tap(naturalHeader);
          await tester.pumpAndSettle();
          await tester.ensureVisible(farqHeader);
          await tester.pumpAndSettle();
          await tester.tap(farqHeader);
          await tester.pumpAndSettle();
          expect(find.byType(TajweedArticleDetailScreen), findsNothing);
          expect(
            find.descendant(of: farq, matching: find.byIcon(Icons.expand_less)),
            findsOneWidget,
          );
          final details = find.descendant(
            of: farq,
            matching: find.widgetWithText(TextButton, l10n.get('full_details')),
          );
          await tester.ensureVisible(details);
          await tester.pumpAndSettle();
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(find.byType(TajweedArticleDetailScreen), findsOneWidget);
          expect(find.byIcon(CupertinoIcons.share), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          final naturalPill = find.text(naturalMadd.name(language)).first;
          await tester.ensureVisible(naturalPill);
          await tester.pumpAndSettle();
          await tester.tap(naturalPill);
          await tester.pumpAndSettle();
          expect(farq, findsNothing);
          expect(naturalRow, findsOneWidget);
          await tester.ensureVisible(find.text(l10n.allRules));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.allRules));
          await tester.pumpAndSettle();
          expect(farq, findsOneWidget);
          await tester.tap(find.text(l10n.get('rules_tab_more')));
          await tester.pumpAndSettle();
          expect(farq, findsNothing);
          await tester.tap(find.text(l10n.get('rules_tab_tajweed')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField),
            article.title(language),
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            article.title(language),
          );
          expect(farq, findsOneWidget, reason: '$language $configuration');
          expect(
            find.text(l10n.get('rules_category_fundamentals')),
            findsNothing,
          );
          expect(find.text(l10n.get('rules_category_madd')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'all articles share localized content on iPhone, iPad and Android',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final size in [const Size(390, 844), const Size(1024, 1366)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          for (final locale in AppLocalizations.supportedLocales) {
            for (final article in TajweedArticlesRepository.all) {
              final language = locale.languageCode;
              await tester.pumpWidget(
                subject(
                  TajweedArticleDetailScreen(
                    key: ValueKey('${article.id}-$language-$platform-$size'),
                    article: article,
                    languageCode: language,
                  ),
                  language,
                  platform,
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.byTooltip(AppLocalizations(locale).get('share_rule')),
              );
              await tester.pumpAndSettle();
              final call = calls.last;
              expect(call.method, 'share');
              final args = Map<String, dynamic>.from(call.arguments as Map);
              expect(
                args['text'],
                TajweedArticleShareContent.build(article, language),
              );
              expect(
                args['text'],
                contains(article.body(language).split('\n\n').first),
              );
              expect(args['text'], contains(AppLinks.appStore));
              expect(args['subject'], article.title(language));
              expect(args['originWidth'], greaterThan(0));
              expect(args['originHeight'], greaterThan(0));
              expect(tester.takeException(), isNull);
            }
          }
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets('share failure is surfaced instead of silently succeeding', (
    tester,
  ) async {
    failShare = true;
    final article = TajweedArticlesRepository.all.first;
    await tester.pumpWidget(
      subject(
        TajweedArticleDetailScreen(article: article, languageCode: 'ar'),
        'ar',
        TargetPlatform.iOS,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.share));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizations(const Locale('ar')).get('share_failed')),
      findsOneWidget,
    );
  });
}
