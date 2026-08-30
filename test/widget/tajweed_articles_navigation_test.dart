import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/features/rules/rules_screen.dart';

void main() {
  testWidgets('opens a localized educational article from the rules library', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RulesScreen(languageCodeOverride: 'en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tajweed Rules'), findsOneWidget);
    expect(find.text('More Topics'), findsOneWidget);
    expect(find.text('Core Recitation Rules'), findsOneWidget);
    expect(find.text('More Tajweed Topics'), findsNothing);

    await tester.tap(find.text('Tafkhim'));
    await tester.pumpAndSettle();

    expect(find.text('Tafkhim'), findsOneWidget);
    expect(
      find.text('How full letters are pronounced and when heaviness changes.'),
      findsOneWidget,
    );
    expect(find.text('The seven full letters'), findsWidgets);
    expect(find.text('Degrees of Tafkhim'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarqiq'));
    await tester.pumpAndSettle();

    expect(find.text('When Ra is light'), findsWidgets);
    expect(find.text('Lam and Alif'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('More Topics'));
    await tester.pumpAndSettle();

    expect(find.text('More Tajweed Topics'), findsOneWidget);
    expect(find.text('Core Recitation Rules'), findsNothing);
    expect(find.text('Isti‘adhah and Basmalah'), findsOneWidget);
  });
}
