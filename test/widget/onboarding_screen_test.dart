import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/l10n/onboarding_localizations.dart';
import 'package:tajweed_practice/core/services/onboarding_service.dart';
import 'package:tajweed_practice/features/onboarding/onboarding_screen.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> settingsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onboarding_widget_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox<dynamic>(
      OnboardingService.settingsBoxName,
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Widget app({required Widget home, Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }

  testWidgets('launcher opens only when automatic guide is eligible', (
    tester,
  ) async {
    final service = OnboardingService(settingsBox: settingsBox);
    await tester.pumpWidget(
      app(
        home: FirstRunOnboardingLauncher(
          service: service,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick guide'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_close')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    await tester.pumpWidget(
      app(
        home: FirstRunOnboardingLauncher(
          service: service,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick guide'), findsNothing);
  });

  testWidgets('paging exposes six guides and Back Next Done controls', (
    tester,
  ) async {
    final service = OnboardingService(settingsBox: settingsBox);
    await tester.pumpWidget(app(home: OnboardingScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Discover Tajweed rules'), findsOneWidget);
    final back = tester.widget<OutlinedButton>(
      find.byKey(const Key('onboarding_back')),
    );
    expect(back.onPressed, isNull);

    const titles = [
      'Read Tafseer',
      'Listen to an ayah',
      'Bookmark an ayah',
      'Explore Hizb boundaries',
      'Bookmark a Mushaf page',
    ];
    for (final title in titles) {
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('manual replay reflects and can change dismissal checkbox', (
    tester,
  ) async {
    await tester.runAsync(
      () => settingsBox.put(OnboardingService.dismissalKey, true),
    );
    final service = OnboardingService(settingsBox: settingsBox);
    await tester.pumpWidget(app(home: OnboardingScreen(service: service)));
    await tester.pumpAndSettle();

    Checkbox checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, isTrue);

    await tester.tap(find.byKey(const Key('onboarding_dont_show_again')));
    await tester.pump();
    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
  });

  testWidgets('Arabic guide uses RTL and localized controls', (tester) async {
    final service = OnboardingService(settingsBox: settingsBox);
    await tester.pumpWidget(
      app(
        locale: const Locale('ar'),
        home: OnboardingScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دليل سريع'), findsOneWidget);
    expect(find.text('السابق'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(PageView))),
      TextDirection.rtl,
    );
  });

  testWidgets('callout labels inherit the active locale direction', (
    tester,
  ) async {
    final service = OnboardingService(settingsBox: settingsBox);

    await tester.pumpWidget(app(home: OnboardingScreen(service: service)));
    await tester.pumpAndSettle();
    Text callout = tester.widget(find.text('Tajweed rule'));
    expect(callout.textDirection, isNull);
    expect(
      Directionality.of(tester.element(find.text('Tajweed rule'))),
      TextDirection.ltr,
    );

    await tester.pumpWidget(
      app(
        locale: const Locale('ar'),
        home: OnboardingScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
    callout = tester.widget(find.text('حكم التجويد'));
    expect(callout.textDirection, isNull);
    expect(
      Directionality.of(tester.element(find.text('حكم التجويد'))),
      TextDirection.rtl,
    );
  });

  testWidgets('uses screenshots captured for the active locale', (
    tester,
  ) async {
    final service = OnboardingService(settingsBox: settingsBox);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        app(
          locale: locale,
          home: OnboardingScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      final asset = image.image as AssetImage;
      expect(
        asset.assetName,
        'assets/onboarding/${locale.languageCode}/01-tajweed-rules.png',
      );
    }
  });

  testWidgets('callout labels are never truncated in any locale', (
    tester,
  ) async {
    // Guards the bug where each callout carried a hand-tuned fixed `Size`, so
    // its own label ellipsised ("Doub…", "Bookm…") even in English. Asserting
    // the rendered paragraph never exceeds its line budget catches that for
    // every locale, including ones nobody manually reviews.
    final service = OnboardingService(settingsBox: settingsBox);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        app(
          locale: locale,
          // A fresh key per locale resets the PageView, which would otherwise
          // still sit on the last page from the previous iteration.
          home: OnboardingScreen(
            key: ValueKey(locale.languageCode),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(OnboardingScreen)),
      );

      for (var page = 0; page < 6; page++) {
        if (page > 0) {
          await tester.tap(find.byKey(const Key('onboarding_next')));
          await tester.pumpAndSettle();
        }

        final label = l10n.get('onboarding_mockup_callout_${page + 1}');
        final finder = find.text(label);
        expect(
          finder,
          findsOneWidget,
          reason: 'callout $page missing for ${locale.languageCode}',
        );

        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason:
              'callout "$label" (page $page, ${locale.languageCode}) is '
              'truncated — the bubble is too small for its own text',
        );
      }
    }
  });

  testWidgets('Hizb guide highlights the marker that opens the tooltip', (
    tester,
  ) async {
    final service = OnboardingService(settingsBox: settingsBox);
    await tester.pumpWidget(app(home: OnboardingScreen(service: service)));
    await tester.pumpAndSettle();

    for (var page = 0; page < 4; page++) {
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Tap this marker'), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding_hizb_marker_highlight')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('onboarding_hizb_marker_pointer')),
      findsOneWidget,
    );
  });

  testWidgets('guide fits phone and tablet layouts', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final service = OnboardingService(settingsBox: settingsBox);

    for (final size in [const Size(390, 844), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(app(home: OnboardingScreen(service: service)));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'layout overflowed at $size',
      );
    }
  });

  test('all onboarding keys are translated in every supported locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = AppLocalizations(locale);
      for (final key in onboardingTranslationKeys) {
        expect(
          l10n.get(key),
          isNot(key),
          reason: '$key is missing for ${locale.languageCode}',
        );
        expect(
          onboardingTranslation(locale.languageCode, key),
          isNotNull,
          reason: '$key falls back for ${locale.languageCode}',
        );
      }
    }
  });
}
