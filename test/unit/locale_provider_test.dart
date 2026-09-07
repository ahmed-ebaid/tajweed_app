import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/providers/locale_provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('locale_provider_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('follows the device language when none has been chosen', () {
    final provider = LocaleProvider(deviceLocales: () => const [Locale('tr')]);

    expect(provider.locale, const Locale('tr'));
    expect(provider.followsDeviceLanguage, isTrue);
  });

  test('falls back to Arabic when the device language is unsupported', () {
    final provider = LocaleProvider(
      deviceLocales: () => const [Locale('ja'), Locale('ko')],
    );

    expect(provider.locale, const Locale('ar'));
    expect(provider.isRtl, isTrue);
  });

  test('walks the device preference order to the first supported language', () {
    final provider = LocaleProvider(
      deviceLocales: () => const [Locale('ja'), Locale('de'), Locale('en')],
    );

    expect(provider.locale, const Locale('de'));
  });

  test('matches a device locale that carries a country code', () {
    final provider = LocaleProvider(
      deviceLocales: () => const [Locale('es', 'MX')],
    );

    expect(provider.locale.languageCode, 'es');
  });

  test('preserves a saved language preference', () async {
    await Hive.box('settings').put('locale', 'en');

    final provider = LocaleProvider(deviceLocales: () => const [Locale('tr')]);

    expect(provider.locale, const Locale('en'));
    expect(provider.isRtl, isFalse);
    expect(provider.followsDeviceLanguage, isFalse);
  });

  test(
    'an explicit Arabic choice is not mistaken for following the device',
    () async {
      await Hive.box('settings').put('locale', 'ar');

      final provider = LocaleProvider(
        deviceLocales: () => const [Locale('en')],
      );

      expect(provider.locale, const Locale('ar'));
      expect(provider.followsDeviceLanguage, isFalse);
    },
  );

  test(
    'setLocale persists the choice and stops following the device',
    () async {
      final provider = LocaleProvider(
        deviceLocales: () => const [Locale('en')],
      );
      expect(provider.followsDeviceLanguage, isTrue);

      await provider.setLocale(const Locale('fr'));

      expect(provider.locale, const Locale('fr'));
      expect(provider.followsDeviceLanguage, isFalse);
      expect(Hive.box('settings').get('locale'), 'fr');
    },
  );

  test('resolving the device language does not persist it', () {
    LocaleProvider(deviceLocales: () => const [Locale('de')]);

    expect(Hive.box('settings').get('locale'), isNull);
  });
}
