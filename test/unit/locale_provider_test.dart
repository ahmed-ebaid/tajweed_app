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

  test('defaults to Arabic when no language preference is saved', () {
    final provider = LocaleProvider();

    expect(provider.locale, const Locale('ar'));
    expect(provider.isRtl, isTrue);
  });

  test('preserves a saved language preference', () async {
    await Hive.box('settings').put('locale', 'en');

    final provider = LocaleProvider();

    expect(provider.locale, const Locale('en'));
    expect(provider.isRtl, isFalse);
  });
}
