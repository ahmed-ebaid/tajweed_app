// Captures the onboarding guide itself (not the reader screenshots it embeds)
// so the callout bubbles can be positioned against real rendered pixels.
//
// This has to run on a simulator rather than flutter_tester: flutter_tester
// runs with --disable-asset-fonts and does not decode the bundled PNGs, so the
// guide renders as empty frames and box glyphs there.
//
// Run via:
//   SCREENSHOT_OUTPUT_DIR=build/onboarding-guide flutter drive \
//     --driver=test_driver/app_store_screenshots_driver.dart \
//     --target=integration_test/onboarding_guide_preview_test.dart \
//     -d <simulator-udid> --dart-define=SCREENSHOT_LOCALE=en

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/providers/locale_provider.dart';
import 'package:tajweed_practice/core/services/onboarding_service.dart';
import 'package:tajweed_practice/features/onboarding/onboarding_screen.dart';

const _locale = String.fromEnvironment(
  'SCREENSHOT_LOCALE',
  defaultValue: 'en',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture onboarding guide pages', (tester) async {
    await Hive.initFlutter();
    for (final box in const ['settings', 'onboarding']) {
      if (!Hive.isBoxOpen(box)) await Hive.openBox(box);
    }


    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          locale: Locale(_locale),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale(_locale)],
          home: OnboardingScreen(service: OnboardingService()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var page = 1; page <= 6; page++) {
      if (page > 1) {
        await tester.tap(find.byKey(const Key('onboarding_next')));
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await binding.takeScreenshot('guide-page-$page');
    }
  });
}
