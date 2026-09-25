import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guard for the surah-cache write path in the reader.
///
/// `ReaderScreen` builds its services in field initialisers, so there is no
/// seam to substitute a fake cache through and no way to drive the race from a
/// widget test. The invariants below are therefore asserted against the source
/// itself, in the same spirit as the other audit tests in this suite.
///
/// The bug being guarded: `_selectedSurah` is mutated *synchronously* by the
/// surah picker before it starts a new load, so a load that is still awaiting
/// the network can resume with the field pointing at a different surah. If the
/// cold path re-reads the field after an await it will persist one surah's
/// verses under another surah's key, and because same-language cache entries
/// are never revalidated that corruption is permanent.
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
    // Skip past the parameter list: named parameters are themselves braced,
    // so the first `{` after the signature is not the body.
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
    fail('Could not find the closing brace for $signature.');
  }

  /// Strips `//` comments so prose about awaits and `_selectedSurah` does not
  /// register as real code.
  String stripComments(String code) => code
      .split('\n')
      .map((line) {
        final at = line.indexOf('//');
        return at == -1 ? line : line.substring(0, at);
      })
      .join('\n');

  test('_loadSurah captures the surah number before its first await', () {
    final body = stripComments(bodyOf('Future<void> _loadSurah('));
    final capture = body.indexOf('final surahNumber = _selectedSurah;');

    expect(
      capture,
      isNot(-1),
      reason:
          '_loadSurah must capture _selectedSurah once into a local before '
          'any await, so a superseded load cannot adopt the new selection.',
    );

    final firstAwait = body.indexOf('await ');
    expect(
      capture,
      lessThan(firstAwait),
      reason: 'The capture must happen before the first await.',
    );
  });

  test('_loadSurah never re-reads _selectedSurah after an await', () {
    final body = stripComments(bodyOf('Future<void> _loadSurah('));
    final firstAwait = body.indexOf('await ');

    final offenders = <int>[];
    var from = firstAwait;
    while (true) {
      final hit = body.indexOf('_selectedSurah', from);
      if (hit == -1) break;
      from = hit + 1;
      // Assigning the field is fine — the fallback path legitimately switches
      // the selection inside a guarded setState. Only reads are unsafe.
      final after = body.substring(hit + '_selectedSurah'.length).trimLeft();
      if (after.startsWith('=') && !after.startsWith('==')) continue;
      offenders.add(hit);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Reading _selectedSurah after an await lets a superseded load use '
          'the surah the user has since switched to. Use the captured '
          'surahNumber local instead.',
    );
  });

  test('every saveSurahCache call is preceded by a load-version guard', () {
    const guard = 'if (!mounted || loadVersion != _surahLoadVersion) return;';
    const call = 'await _quranOfflineSync.saveSurahCache(';

    var from = 0;
    var found = 0;
    while (true) {
      final hit = source.indexOf(call, from);
      if (hit == -1) break;
      found++;
      from = hit + call.length;

      final guardAt = source.lastIndexOf(guard, hit);
      expect(
        guardAt,
        isNot(-1),
        reason: 'saveSurahCache at offset $hit has no preceding guard.',
      );

      // The guard has to be the statement immediately before the write, not
      // one that some other await has since invalidated.
      final between = source.substring(guardAt + guard.length, hit);
      expect(
        between.contains('await '),
        isFalse,
        reason:
            'The load-version guard before saveSurahCache at offset $hit is '
            'separated from it by an await, so the write can still race a '
            'newer load. Move the guard directly above the write.',
      );
    }

    expect(
      found,
      greaterThan(0),
      reason: 'No saveSurahCache call sites found; update this audit.',
    );
  });

  test('saveSurahCache is never keyed off _selectedSurah directly', () {
    const call = 'await _quranOfflineSync.saveSurahCache(';

    var from = 0;
    while (true) {
      final hit = source.indexOf(call, from);
      if (hit == -1) break;
      from = hit + call.length;

      final close = source.indexOf(');', hit);
      final args = source.substring(hit, close);
      expect(
        args.contains('_selectedSurah'),
        isFalse,
        reason:
            'saveSurahCache must be keyed off the surah number captured at '
            'the start of the load, not off the live _selectedSurah field.',
      );
    }
  });
}
