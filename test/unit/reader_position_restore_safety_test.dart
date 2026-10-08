import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/features/reader/reader_screen.dart').readAsStringSync();
  });

  String bodyOf(String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature no longer exists.');

    final openParen = source.indexOf('(', start);
    expect(openParen, isNot(-1));
    var parenDepth = 0;
    var closeParen = -1;
    for (var index = openParen; index < source.length; index++) {
      if (source[index] == '(') parenDepth++;
      if (source[index] == ')' && --parenDepth == 0) {
        closeParen = index;
        break;
      }
    }
    expect(closeParen, isNot(-1), reason: 'Unclosed signature: $signature');

    var bodyStart = closeParen + 1;
    while (bodyStart < source.length &&
        (source[bodyStart] == ' ' ||
            source[bodyStart] == '\n' ||
            source[bodyStart] == '\r')) {
      bodyStart++;
    }
    expect(source[bodyStart], '{', reason: '$signature has no body.');

    var braceDepth = 0;
    for (var index = bodyStart; index < source.length; index++) {
      if (source[index] == '{') braceDepth++;
      if (source[index] == '}' && --braceDepth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
    fail('Could not find the closing brace for $signature.');
  }

  test(
    'surah selection cancels stale restore and position-save work first',
    () {
      final cancelBody = bodyOf('void _cancelProgrammaticAyahScroll()');
      expect(cancelBody, contains('_restoreGuardToken++'));
      expect(cancelBody, contains('_startupRestoreTargetAyah = null'));
      expect(cancelBody, contains('_suppressAutoSaveUntilMs = 0'));
      expect(cancelBody, contains('_scrollToAyahRequestId++'));

      const selectorMarker = 'onChanged: (surah, {ayah}) {';
      final selectorAt = source.indexOf(selectorMarker);
      expect(selectorAt, isNot(-1));
      final selectorBodyStart = selectorAt + selectorMarker.length - 1;
      var depth = 0;
      var selectorBodyEnd = -1;
      for (var index = selectorBodyStart; index < source.length; index++) {
        if (source[index] == '{') depth++;
        if (source[index] == '}' && --depth == 0) {
          selectorBodyEnd = index + 1;
          break;
        }
      }
      expect(selectorBodyEnd, greaterThan(selectorBodyStart));
      final selectorBody = source.substring(selectorBodyStart, selectorBodyEnd);

      expect(
        selectorBody.indexOf('_scrollSaveTimer?.cancel()'),
        lessThan(selectorBody.indexOf('_selectedSurah = surah')),
      );
      expect(
        selectorBody.indexOf('_cancelProgrammaticAyahScroll()'),
        lessThan(selectorBody.indexOf('_selectedSurah = surah')),
      );
      expect(selectorBody, contains('_pendingScrollAyah = targetAyah'));
    },
  );

  test('offset restore is tied to the surah load that requested it', () {
    final restoreBody = bodyOf('void _restoreScrollOffset(');
    final versionGuard = restoreBody.indexOf(
      'loadVersion != _surahLoadVersion',
    );
    final firstScroll = restoreBody.indexOf('_scrollController.jumpTo(');

    expect(versionGuard, greaterThanOrEqualTo(0));
    expect(firstScroll, greaterThan(versionGuard));
    expect(restoreBody, contains('loadVersion: loadVersion'));
    expect(restoreBody, contains('activeRequestId != _scrollToAyahRequestId'));
    expect(
      RegExp(r'requestId:\s*activeRequestId').allMatches(restoreBody),
      hasLength(2),
    );
  });

  test('a new surah cannot paint at the previous list position', () {
    final loadStart = source.indexOf('Future<void> _loadSurah(');
    final loadEnd = source.indexOf('void _applySurahVerses(', loadStart);
    final loadBody = source.substring(loadStart, loadEnd);
    expect(
      loadBody.indexOf('_ayahs = []'),
      lessThan(loadBody.indexOf('await _isDeviceOffline()')),
    );
    expect(source, contains("key: ValueKey('ayah-list-\$_selectedSurah')"));
    expect(source, contains('ScrollController(keepScrollOffset: false)'));
  });

  test('post-frame restore and delayed ayah corrections reject stale loads', () {
    final applyBody = bodyOf('void _applySurahVerses(');
    expect(
      applyBody,
      contains('_restorePositionAfterSurahLoad(loadVersion: loadVersion)'),
    );
    expect(applyBody, contains('loadVersion != _surahLoadVersion'));

    final restoreBody = bodyOf('void _restorePositionAfterSurahLoad(');
    expect(restoreBody, contains('loadVersion != _surahLoadVersion'));
    expect(restoreBody, contains('requestId != _scrollToAyahRequestId'));
    expect(
      RegExp(r'requestId:\s*requestId').allMatches(restoreBody),
      hasLength(4),
      reason:
          'Both initial scrolls and their delayed corrections need the '
          'same request id so an older correction cannot override a surah pick.',
    );
  });
}
