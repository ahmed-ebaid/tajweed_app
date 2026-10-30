import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/services/hijri_calendar_service.dart';
import 'package:tajweed_practice/core/services/seasonal_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SeasonalIconService.channelName);
  const calendarChannel = MethodChannel(HijriCalendarService.channelName);
  late Directory tempDir;
  late Box<dynamic> settingsBox;
  late List<MethodCall> calls;
  String? currentIcon;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('seasonal_icon_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox<dynamic>(
      SeasonalIconService.settingsBoxName,
    );
    calls = [];
    currentIcon = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(calendarChannel, (call) async {
          final milliseconds =
              (call.arguments as Map)['millisecondsSinceEpoch'] as int;
          final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
          return {'year': 1445, 'month': date.month == 3 ? 9 : 11, 'day': 10};
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'supportsAlternateIcons':
              return true;
            case 'getIconName':
              return currentIcon;
            case 'setIconName':
              currentIcon = (call.arguments as Map)['name'] as String?;
              return null;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(calendarChannel, null);
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  SeasonalIconService service({bool platformSupported = true}) =>
      SeasonalIconService(
        settingsBox: settingsBox,
        platformSupported: platformSupported,
      );

  test('selects seasonal icons using the system Hijri date', () {
    final expectations = {
      const HijriDate(1445, 8, 29): SeasonalIcon.standard,
      const HijriDate(1445, 9, 1): SeasonalIcon.ramadan,
      const HijriDate(1445, 9, 30): SeasonalIcon.ramadan,
      const HijriDate(1445, 10, 1): SeasonalIcon.eidAlFitr,
      const HijriDate(1445, 10, 3): SeasonalIcon.eidAlFitr,
      const HijriDate(1445, 10, 4): SeasonalIcon.standard,
      const HijriDate(1445, 12, 7): SeasonalIcon.standard,
      const HijriDate(1445, 12, 8): SeasonalIcon.eidAlAdha,
      const HijriDate(1445, 12, 13): SeasonalIcon.eidAlAdha,
      const HijriDate(1445, 12, 14): SeasonalIcon.standard,
    };
    expectations.forEach((date, icon) {
      expect(SeasonalIconService.iconFor(date), icon, reason: '$date');
    });
  });

  test(
    'switches to the seasonal icon once and leaves it alone after',
    () async {
      final ramadanDay = DateTime(2024, 3, 20);

      expect(await service().applyForDate(now: ramadanDay), isTrue);
      expect(currentIcon, 'AppIcon-Ramadan');

      calls.clear();
      expect(await service().applyForDate(now: ramadanDay), isFalse);
      expect(calls.where((call) => call.method == 'setIconName'), isEmpty);
    },
  );

  test('restores the standard icon after the season ends', () async {
    currentIcon = 'AppIcon-EidAlFitr';

    expect(await service().applyForDate(now: DateTime(2024, 5, 1)), isTrue);
    expect(currentIcon, isNull);
  });

  test('keeps the existing icon if the native calendar fails', () async {
    currentIcon = 'AppIcon-Ramadan';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(calendarChannel, (call) async {
          throw PlatformException(code: 'calendar_failed');
        });
    expect(await service().applyForDate(), isFalse);
    expect(currentIcon, 'AppIcon-Ramadan');
    expect(calls.where((call) => call.method == 'setIconName'), isEmpty);
  });

  test(
    'turning the setting off restores and keeps the standard icon',
    () async {
      currentIcon = 'AppIcon-Ramadan';
      final ramadanDay = DateTime(2024, 3, 20);

      await service().setEnabled(false, now: ramadanDay);
      expect(currentIcon, isNull);
      expect(service().isEnabled, isFalse);
      expect(await service().applyForDate(now: ramadanDay), isFalse);
      expect(currentIcon, isNull);
    },
  );

  test('does nothing on unsupported platforms', () async {
    final changed = await service(
      platformSupported: false,
    ).applyForDate(now: DateTime(2024, 3, 20));

    expect(changed, isFalse);
    expect(calls, isEmpty);
  });

  test('every alternate icon is registered in the iOS project', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final names = SeasonalIcon.values
        .map((icon) => icon.iosIconName)
        .whereType<String>()
        .join(' ');
    final setting = 'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "$names";';
    expect(setting.allMatches(project).length, 3);

    for (final icon in SeasonalIcon.values) {
      final name = icon.iosIconName;
      if (name == null) continue;
      final contents = File(
        'ios/Runner/Assets.xcassets/$name.appiconset/Contents.json',
      );
      expect(contents.existsSync(), isTrue, reason: name);
      final catalog = jsonDecode(contents.readAsStringSync()) as Map;
      final images = catalog['images'] as List;
      for (final idiom in ['iphone', 'ipad', 'ios-marketing']) {
        expect(
          images.any((image) => image['idiom'] == idiom),
          isTrue,
          reason: '$name must include explicit $idiom slots',
        );
      }
      for (final image in images) {
        expect(
          File('${contents.parent.path}/${image['filename']}').existsSync(),
          isTrue,
          reason: '$name: ${image['filename']}',
        );
      }
      expect(
        File('${contents.parent.path}/$name-1024.png').existsSync(),
        isTrue,
        reason: name,
      );
    }
  });

  test('seasonal icon setting is translated in all supported locales', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final localizations = AppLocalizations(locale);
      for (final key in ['seasonal_icon', 'seasonal_icon_subtitle']) {
        expect(
          localizations.get(key),
          isNot(key),
          reason: '${locale.languageCode}: $key',
        );
      }
    }
  });
}
