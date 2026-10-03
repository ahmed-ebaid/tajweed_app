import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/constants/app_links.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/features/rules/rules_screen.dart';
import 'package:tajweed_practice/features/rules/tajweed_article_detail_screen.dart';
import 'package:tajweed_practice/features/rules/tajweed_article_share_content.dart';
import 'package:tajweed_practice/features/rules/tajweed_articles_repository.dart';

Widget subject(Widget child, String language, TargetPlatform platform) =>
    MaterialApp(
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(platform: platform),
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
    'Madd al-Farq appears once under Madd, not fundamentals or More',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final locale in AppLocalizations.supportedLocales) {
        final language = locale.languageCode;
        final l10n = AppLocalizations(locale);
        final article = TajweedArticlesRepository.all.singleWhere(
          (article) => article.id == 'madd_al_farq',
        );
        await tester.pumpWidget(
          subject(
            RulesScreen(
              key: ValueKey(language),
              languageCodeOverride: language,
            ),
            language,
            TargetPlatform.iOS,
          ),
        );
        await tester.pumpAndSettle();
        final farq = find.widgetWithText(ListTile, article.title(language));
        await tester.ensureVisible(farq);
        expect(farq, findsOneWidget);
        expect(
          tester.getTopLeft(find.text(l10n.get('rules_category_madd'))).dy,
          lessThan(tester.getTopLeft(farq).dy),
        );
        expect(find.text(l10n.get('rules_category_madd')), findsOneWidget);
        await tester.tap(farq);
        await tester.pumpAndSettle();
        expect(find.byType(TajweedArticleDetailScreen), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.share), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.get('rules_tab_more')));
        await tester.pumpAndSettle();
        expect(farq, findsNothing);
        await tester.tap(find.text(l10n.get('rules_tab_tajweed')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), article.title(language));
        await tester.pumpAndSettle();
        expect(farq, findsOneWidget);
        expect(
          find.text(l10n.get('rules_category_fundamentals')),
          findsNothing,
        );
        expect(find.text(l10n.get('rules_category_madd')), findsOneWidget);
        expect(tester.takeException(), isNull);
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
