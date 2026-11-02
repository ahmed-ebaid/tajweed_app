import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/services/review_prompt_service.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> settingsBox;
  late ReviewPromptService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('review_prompt_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox<dynamic>(
      ReviewPromptService.settingsBoxName,
    );
    service = ReviewPromptService(settingsBox: settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('requires reading on three distinct calendar days', () async {
    final firstDay = DateTime(2026, 10, 1);
    await service.recordMeaningfulReadingDay(date: firstDay);
    await service.recordMeaningfulReadingDay(
      date: firstDay.add(const Duration(hours: 8)),
    );
    expect(service.isEligible, isFalse);

    await service.recordMeaningfulReadingDay(date: DateTime(2026, 10, 2));
    expect(service.isEligible, isFalse);
    await service.recordMeaningfulReadingDay(date: DateTime(2026, 10, 3));
    expect(service.isEligible, isTrue);
    expect(service.readingDays, hasLength(3));
  });

  test('prompts only when eligible and outside the 120-day cooldown', () async {
    final now = DateTime(2026, 10, 30, 12);
    for (var day = 1; day <= 3; day++) {
      await service.recordMeaningfulReadingDay(date: DateTime(2026, 10, day));
    }

    expect(service.shouldRequestAtLaunch(now: now), isTrue);
    await service.recordPromptAttempt(now: now);
    expect(
      service.shouldRequestAtLaunch(now: now.add(const Duration(days: 119))),
      isFalse,
    );
    expect(
      service.shouldRequestAtLaunch(now: now.add(const Duration(days: 120))),
      isTrue,
    );
  });

  test(
    'does not consume an attempt when presentation is no longer safe',
    () async {
      for (var day = 1; day <= 3; day++) {
        await service.recordMeaningfulReadingDay(date: DateTime(2026, 10, day));
      }
      var safe = true;
      var requests = 0;
      final requested = await service.requestAtLaunch(
        isAvailable: () async {
          safe = false;
          return true;
        },
        requestReview: () async => requests++,
        canRequest: () => safe,
      );
      expect(requested, isFalse);
      expect(requests, 0);
      expect(settingsBox.get(ReviewPromptService.lastAttemptKey), isNull);
    },
  );

  test(
    'does not consume an attempt when native review is unavailable',
    () async {
      var reviewRequested = false;
      final now = DateTime(2026, 10, 30);
      for (var day = 1; day <= 3; day++) {
        await service.recordMeaningfulReadingDay(date: DateTime(2026, 10, day));
      }

      final requested = await service.requestAtLaunch(
        now: now,
        isAvailable: () async => false,
        requestReview: () async {
          reviewRequested = true;
        },
      );

      expect(requested, isFalse);
      expect(reviewRequested, isFalse);
      expect(service.shouldRequestAtLaunch(now: now), isTrue);
    },
  );

  test(
    'requests the native prompt once eligible and records its cooldown',
    () async {
      var availabilityChecked = false;
      var reviewRequested = false;
      final now = DateTime(2026, 10, 30);
      for (var day = 1; day <= 3; day++) {
        await service.recordMeaningfulReadingDay(date: DateTime(2026, 10, day));
      }

      final requested = await service.requestAtLaunch(
        now: now,
        isAvailable: () async {
          availabilityChecked = true;
          return true;
        },
        requestReview: () async {
          reviewRequested = true;
        },
      );

      expect(requested, isTrue);
      expect(availabilityChecked, isTrue);
      expect(reviewRequested, isTrue);
      expect(service.shouldRequestAtLaunch(now: now), isFalse);
    },
  );

  test('review and feedback copy is translated in all supported locales', () {
    const keys = [
      'rate_app',
      'rate_app_subtitle',
      'feedback_section',
      'send_feedback',
      'send_feedback_subtitle',
      'feedback_email_subject',
      'open_link_failed',
    ];
    for (final locale in AppLocalizations.supportedLocales) {
      final localizations = AppLocalizations(locale);
      for (final key in keys) {
        expect(
          localizations.get(key),
          isNotEmpty,
          reason: '${locale.languageCode}: $key',
        );
        expect(
          localizations.get(key),
          isNot(key),
          reason: '${locale.languageCode}: $key',
        );
      }
    }
  });
}
