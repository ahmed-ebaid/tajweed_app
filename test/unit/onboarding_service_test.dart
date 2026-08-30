import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/services/onboarding_service.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> settingsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onboarding_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox<dynamic>(
      OnboardingService.settingsBoxName,
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('shows automatically once per runtime when not dismissed', () {
    final service = OnboardingService(settingsBox: settingsBox);

    expect(service.shouldShowAutomatically, isTrue);
    service.markPresented();
    expect(service.shouldShowAutomatically, isFalse);
    expect(service.isDismissed, isFalse);
  });

  test('persisted dismissal prevents a later automatic launch', () async {
    final service = OnboardingService(settingsBox: settingsBox);

    await service.updateDismissal(initialValue: false, currentValue: true);

    expect(
      OnboardingService(settingsBox: settingsBox).shouldShowAutomatically,
      isFalse,
    );
  });

  test('manual replay does not change an untouched dismissal', () async {
    await settingsBox.put(OnboardingService.dismissalKey, true);
    final service = OnboardingService(settingsBox: settingsBox);

    await service.updateDismissal(initialValue: true, currentValue: true);

    expect(settingsBox.get(OnboardingService.dismissalKey), isTrue);
  });

  test('explicitly clearing checkbox enables future launches', () async {
    await settingsBox.put(OnboardingService.dismissalKey, true);
    final service = OnboardingService(settingsBox: settingsBox);

    await service.updateDismissal(initialValue: true, currentValue: false);

    expect(settingsBox.containsKey(OnboardingService.dismissalKey), isFalse);
    expect(
      OnboardingService(settingsBox: settingsBox).shouldShowAutomatically,
      isTrue,
    );
  });
}
