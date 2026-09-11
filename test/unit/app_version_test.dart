import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/constants/app_version.dart';

/// The version on the Settings screen sat at 1.1.0 through the 1.1.1, 1.1.2 and
/// 1.1.3 releases because nothing tied it to the real one. This closes that gap:
/// `pubspec.yaml` is the single source of truth and the constant has to match.
void main() {
  test('appVersion matches the version declared in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml declares no version');

    // pubspec carries a build number ("1.1.3+65"); the UI shows only the
    // marketing version.
    final pubspecVersion = match!.group(1)!.split('+').first;

    expect(
      appVersion,
      pubspecVersion,
      reason:
          'Settings shows $appVersion but pubspec.yaml declares '
          '$pubspecVersion. Update lib/core/constants/app_version.dart to '
          'match when bumping the release version.',
    );
  });
}
