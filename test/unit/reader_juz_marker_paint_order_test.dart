import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guard for juz-marker paint ordering in the reader.
///
/// `ReaderScreen` builds its services in field initialisers, so there is no
/// seam to substitute a fake Hive box through and no way to drive the paint
/// sequence from a widget test. The invariants below are therefore asserted
/// against the source itself, matching the other audit tests in this suite.
///
/// The bug being guarded: juz markers are real entries in the verse list, not
/// an overlay. When the boundaries arrived after the first paint they inserted
/// widgets *above* the restored reading position, pushing it down, and the
/// scroll restore then animated it back — read on device as the page "jumping
/// up" a moment after open. The boundaries must therefore be seeded from cache
/// before the text paints, and must not be rewritten afterwards.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/features/reader/reader_screen.dart').readAsStringSync();
  });

  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(
      start,
      isNot(-1),
      reason: '$signature no longer exists; update this audit.',
    );
    const marker = ') async {';
    final markerAt = source.indexOf(marker, start);
    expect(
      markerAt,
      isNot(-1),
      reason: '$signature is no longer an async method; update this audit.',
    );
    final open = markerAt + marker.length - 1;
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      final ch = source[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return source.substring(open, i + 1);
      }
    }
    fail('Could not find the end of $signature.');
  }

  group('juz markers are known before the first paint', () {
    test('_loadSurah seeds boundaries from cache', () {
      final body = bodyOf('Future<void> _loadSurah({bool allowFallback');
      expect(
        body.contains('_loadJuzBoundaries(useCacheOnly: true'),
        isTrue,
        reason:
            '_loadSurah must seed juz boundaries from cache. Without this the '
            'markers appear after the first paint and shift the restored '
            'reading position.',
      );
    });

    test('the seed is awaited before any verses are applied', () {
      final body = bodyOf('Future<void> _loadSurah({bool allowFallback');
      final seed = body.indexOf('await _loadJuzBoundaries(useCacheOnly: true');
      final firstPaint = body.indexOf('_applySurahVerses(');
      expect(
        seed,
        isNot(-1),
        reason: 'The cached juz read must be awaited, not fired and forgotten.',
      );
      expect(firstPaint, isNot(-1));
      expect(
        seed < firstPaint,
        isTrue,
        reason:
            'The juz seed must complete before _applySurahVerses clears the '
            'spinner, otherwise the list geometry changes after first paint.',
      );
    });

    test('the seed cannot reach the network', () {
      final body = bodyOf('Future<void> _loadSurah({bool allowFallback');
      expect(
        body.contains('_loadJuzBoundaries(useCacheOnly: false'),
        isFalse,
        reason:
            'A networked juz read before the first paint would reintroduce the '
            'blocking fetch that the cached-content fast path removed.',
      );
    });
  });

  group('juz markers are not rewritten after the first paint', () {
    test('_loadSurahExtras only fetches when nothing was cached', () {
      final body = bodyOf('Future<void> _loadSurahExtras({');
      final guard = body.indexOf('if (!_hasCachedJuzList())');
      final call = body.indexOf('_loadJuzBoundaries(');
      expect(
        guard,
        isNot(-1),
        reason:
            'The post-paint juz refresh must be guarded by _hasCachedJuzList; '
            'juz boundaries are immutable, so refetching them only risks '
            'shifting layout under a reader who is already in position.',
      );
      expect(call, isNot(-1));
      expect(
        guard < call,
        isTrue,
        reason: 'The guard must precede the juz fetch, not follow it.',
      );
    });

    test('_hasCachedJuzList reads the juz list cache key', () {
      expect(
        source.contains('bool _hasCachedJuzList()'),
        isTrue,
        reason: '_hasCachedJuzList no longer exists; update this audit.',
      );
      final start = source.indexOf('bool _hasCachedJuzList()');
      final body = source.substring(start, source.indexOf('}', start));
      expect(
        body.contains('_juzListCacheKey'),
        isTrue,
        reason:
            'The guard must key off the cached juz list, not off whether the '
            'computed boundary map happens to be empty — a surah wholly inside '
            'one juz legitimately has no boundaries.',
      );
    });
  });
}
