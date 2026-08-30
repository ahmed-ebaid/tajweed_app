import 'package:hive_flutter/hive_flutter.dart';

class OnboardingService {
  static const settingsBoxName = 'settings';
  static const dismissalKey = 'onboarding_dismissed';

  final Box<dynamic> _settingsBox;
  bool _presentedThisRuntime = false;

  OnboardingService({Box<dynamic>? settingsBox})
    : _settingsBox = settingsBox ?? Hive.box(settingsBoxName);

  bool get isDismissed =>
      _settingsBox.get(dismissalKey, defaultValue: false) as bool;

  bool get shouldShowAutomatically => !_presentedThisRuntime && !isDismissed;

  void markPresented() {
    _presentedThisRuntime = true;
  }

  Future<void> updateDismissal({
    required bool initialValue,
    required bool currentValue,
  }) async {
    if (initialValue == currentValue) return;
    if (currentValue) {
      await _settingsBox.put(dismissalKey, true);
    } else {
      await _settingsBox.delete(dismissalKey);
    }
  }
}
