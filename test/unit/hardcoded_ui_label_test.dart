import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against English UI labels being hardcoded next to an interpolated
/// value, e.g. `'Ayah $n'`.
///
/// Four of these shipped: the bookmarks sheet title, the page-bookmark label,
/// the juz quick-result subtitle and the word-detail header. Each rendered a
/// Latin word inside an otherwise fully-Arabic UI, and the bookmark ones were
/// worse than cosmetic because the label was persisted at creation time, so it
/// never followed a later language change.
///
/// A reader-facing label with a number in it must come from
/// AppLocalizations.get(...), never from a literal.
///
/// Deliberately excluded: `Surah $n`. That literal is used as a fallback for
/// the `name_simple` field, which is the English transliteration by
/// definition, so an English value there is correct rather than a defect.
void main() {
  test('no hardcoded English ayah/page/verse labels in lib/', () {
    // A capitalised English unit word immediately followed by a Dart
    // interpolation is the shape of a reader-facing label.
    final offending = RegExp(r'(?<![A-Za-z])(Ayah|Page|Verse|Juz) \$');

    final offenders = <String>[];
    final libDir = Directory('lib');
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comments explain code rather than render to the user.
        if (line.trimLeft().startsWith('//')) continue;
        if (offending.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Hardcoded English UI label(s) found. Use AppLocalizations.get(...) '
          'plus localized digits instead:\n${offenders.join('\n')}',
    );
  });
}
