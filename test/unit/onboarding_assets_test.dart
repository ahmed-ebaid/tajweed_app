import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Locales that ship a localized onboarding screenshot set.
const _locales = <String>['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];

/// The six onboarding guide pages, in display order.
const _files = <String>[
  '01-tajweed-rules.png',
  '02-tafseer.png',
  '03-listen-ayah.png',
  '04-bookmark-ayah.png',
  '05-hizb-boundary.png',
  '06-mushaf-bookmark.png',
];

void main() {
  group('onboarding screenshot assets', () {
    test('every locale ships all six guide images', () {
      final missing = <String>[];
      for (final locale in _locales) {
        for (final file in _files) {
          final path = 'assets/onboarding/$locale/$file';
          if (!File(path).existsSync()) missing.add(path);
        }
      }
      expect(missing, isEmpty, reason: 'Missing onboarding assets: $missing');
    });

    // Guards against the mistake that shipped 03-listen-ayah.png and
    // 04-bookmark-ayah.png as the same bytes: the capture run produced one
    // reader screenshot that was hand-copied to several asset names, so two
    // onboarding pages illustrated a feature neither of them showed.
    test('no two guide images within a locale are byte-identical', () {
      final duplicates = <String>[];
      for (final locale in _locales) {
        final bytesByFile = <String, List<int>>{};
        for (final file in _files) {
          final asset = File('assets/onboarding/$locale/$file');
          if (asset.existsSync()) bytesByFile[file] = asset.readAsBytesSync();
        }

        final names = bytesByFile.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final left = bytesByFile[names[i]]!;
            final right = bytesByFile[names[j]]!;
            if (left.length == right.length &&
                const IterableEquality().equals(left, right)) {
              duplicates.add('$locale/${names[i]} == $locale/${names[j]}');
            }
          }
        }
      }
      expect(
        duplicates,
        isEmpty,
        reason:
            'These onboarding pages show the exact same image, so at least '
            'one of them illustrates the wrong feature: $duplicates',
      );
    });

    test('every guide image is declared in pubspec assets', () {
      final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
      final declared = ((pubspec['flutter'] as Map)['assets'] as List)
          .map((e) => e.toString())
          .toList();

      for (final locale in _locales) {
        final dir = 'assets/onboarding/$locale/';
        final covered = declared.any(
          (entry) =>
              entry == dir ||
              entry == 'assets/onboarding/' ||
              _files.any((file) => entry == '$dir$file'),
        );
        expect(covered, isTrue, reason: '$dir is not declared in pubspec.yaml');
      }
    });
  });
}

/// Minimal element-wise list comparison so the test needs no extra package.
class IterableEquality {
  const IterableEquality();

  bool equals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
