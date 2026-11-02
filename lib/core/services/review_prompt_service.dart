import 'package:hive_flutter/hive_flutter.dart';

class ReviewPromptService {
  static const settingsBoxName = 'settings';
  static const readingDaysKey = 'review_prompt_reading_days';
  static const lastAttemptKey = 'review_prompt_last_attempt';
  static const eligibleReadingDays = 3;
  static const cooldown = Duration(days: 120);

  final Box<dynamic> _settingsBox;

  ReviewPromptService({Box<dynamic>? settingsBox})
    : _settingsBox = settingsBox ?? Hive.box(settingsBoxName);

  Set<String> get readingDays {
    final value = _settingsBox.get(readingDaysKey, defaultValue: <String>[]);
    if (value is! List) return {};
    return value.whereType<String>().toSet();
  }

  bool get isEligible => readingDays.length >= eligibleReadingDays;

  bool shouldRequestAtLaunch({DateTime? now}) {
    if (!isEligible) return false;
    final lastAttemptValue = _settingsBox.get(lastAttemptKey);
    if (lastAttemptValue is! String) return true;
    final lastAttempt = DateTime.tryParse(lastAttemptValue);
    if (lastAttempt == null) return true;
    return (now ?? DateTime.now()).difference(lastAttempt) >= cooldown;
  }

  Future<void> recordMeaningfulReadingDay({DateTime? date}) async {
    final days = readingDays;
    if (days.length >= eligibleReadingDays) return;

    final now = date ?? DateTime.now();
    final dayKey =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    if (days.add(dayKey)) {
      await _settingsBox.put(readingDaysKey, days.toList()..sort());
    }
  }

  Future<void> recordPromptAttempt({DateTime? now}) => _settingsBox.put(
    lastAttemptKey,
    (now ?? DateTime.now()).toIso8601String(),
  );

  Future<bool> requestAtLaunch({
    DateTime? now,
    required Future<bool> Function() isAvailable,
    required Future<void> Function() requestReview,
    bool Function()? canRequest,
  }) async {
    if (!shouldRequestAtLaunch(now: now) ||
        !await isAvailable() ||
        canRequest?.call() == false) {
      return false;
    }
    await recordPromptAttempt(now: now);
    await requestReview();
    return true;
  }
}
