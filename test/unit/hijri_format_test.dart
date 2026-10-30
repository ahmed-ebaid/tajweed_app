import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/l10n/hijri_format.dart';
import 'package:tajweed_practice/core/services/hijri_calendar_service.dart';

void main() {
  const date = HijriDate(1445, 9, 1);

  test('formats the Hijri date in English and Arabic', () {
    expect(
      formatHijriDate(date, AppLocalizations(const Locale('en'))),
      '1 Ramadan 1445 AH',
    );
    expect(
      formatHijriDate(date, AppLocalizations(const Locale('ar'))),
      '١ رمضان ١٤٤٥ هـ',
    );
  });

  test('every supported locale has all twelve Hijri month names', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final months = hijriMonthNames[locale.languageCode];
      expect(months, isNotNull, reason: locale.languageCode);
      expect(months, hasLength(12), reason: locale.languageCode);
      expect(
        formatHijriDate(date, AppLocalizations(locale)),
        contains(months![8]),
      );
    }
  });
}
