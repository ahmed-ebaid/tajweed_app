import 'quran_vocabulary.g.dart';

/// Provides word-by-word comparison between the user's spoken text
/// (from speech-to-text) and the expected Quranic text for an ayah.
///
/// Text matching does not assess pronunciation or Tajweed.
class SpeechComparisonService {
  const SpeechComparisonService({this.requireExplicitAlifLamMeem = false});

  /// The compact ASR token does not show whether Meem was recited.
  final bool requireExplicitAlifLamMeem;

  /// Recitation words without Quranic pause marks or Arabic diacritics.
  List<String> recitationWords(String text) => _recitationWords(text);

  /// Join a new recording to an already matched prefix. Only an exact overlap
  /// with the end of that prefix may be repeated; unmatched words stay intact.
  String joinRecitationSegment({
    required String retainedPrefix,
    required String spokenText,
    required List<String> expectedAyahs,
    required List<String> expectedVerseKeys,
    bool allowWrittenOpenings = false,
  }) {
    if (expectedAyahs.length != expectedVerseKeys.length) {
      throw ArgumentError('Verse keys must correspond to every expected ayah');
    }
    final joined = _joinRecitationSegmentOnce(
      retainedPrefix: retainedPrefix,
      spokenText: spokenText,
      expectedAyahs: expectedAyahs,
      expectedVerseKeys: expectedVerseKeys,
      allowWrittenOpenings: allowWrittenOpenings,
    );
    if (!allowWrittenOpenings) return joined;
    final cursor = _cursorAnchoredJoin(
      retainedPrefix,
      spokenText,
      expectedAyahs,
      expectedVerseKeys,
    );
    if (cursor == null) return joined;
    int verified(String text) => matchingPrefixWordCounts(
      expectedAyahs: expectedAyahs,
      expectedVerseKeys: expectedVerseKeys,
      spokenText: text,
      allowWrittenOpenings: true,
    ).fold(0, (a, b) => a + b);
    // A short overlap on a common word (e.g. ولا) or a repeated phrase can
    // anchor the join too early; the exact next expected words win instead.
    final cursorVerified = verified(cursor);
    var total = 0;
    for (var verse = 0; verse < expectedAyahs.length; verse++) {
      total += _expectedRecitationWords(
        expectedAyahs[verse],
        expectedVerseKeys[verse],
      ).length;
    }
    if (cursorVerified > verified(joined)) return cursor;
    // Both reach the end: the cursor join drops trailing noise.
    return cursorVerified >= total ? cursor : joined;
  }

  /// Continues the retained prefix at the first place the incoming words
  /// recite exactly the next expected words: three of them, or every
  /// remaining word near the end. Words after the final expected word are
  /// dropped, so trailing noise cannot fail a completed recitation.
  String? _cursorAnchoredJoin(
    String retainedPrefix,
    String spokenText,
    List<String> expectedAyahs,
    List<String> expectedVerseKeys,
  ) {
    final retained = _spokenWords(
      retainedPrefix,
      expectedAyahs,
      expectedVerseKeys,
      true,
      trustedPrefix: true,
    );
    if (retained.isEmpty) return null;
    final expectedSeq = <Set<String>>[
      for (var verse = 0; verse < expectedAyahs.length; verse++)
        ..._expectedRecitationWords(
          expectedAyahs[verse],
          expectedVerseKeys[verse],
        ),
    ];
    for (var i = 0; i < retained.length; i++) {
      if (i >= expectedSeq.length || !expectedSeq[i].contains(retained[i])) {
        return null;
      }
    }
    final remaining = expectedSeq.length - retained.length;
    if (remaining < 2) return null;
    final incoming = _spokenWords(
      spokenText,
      expectedAyahs,
      expectedVerseKeys,
      true,
    );
    final confirmation = remaining < 3 ? remaining : 3;
    for (var start = 0; start + confirmation <= incoming.length; start++) {
      if (!_repeatsRetainedSuffix(retained, incoming, start)) continue;
      var matches = true;
      for (var i = 0; i < confirmation; i++) {
        if (!expectedSeq[retained.length + i].contains(incoming[start + i])) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      return [...retained, ...incoming.skip(start)].join(' ');
    }
    return null;
  }

  String _joinRecitationSegmentOnce({
    required String retainedPrefix,
    required String spokenText,
    required List<String> expectedAyahs,
    required List<String> expectedVerseKeys,
    bool allowWrittenOpenings = false,
  }) {
    List<String> words(String text) => _spokenWords(
      text,
      expectedAyahs,
      expectedVerseKeys,
      allowWrittenOpenings,
    );
    final retained = _spokenWords(
      retainedPrefix,
      expectedAyahs,
      expectedVerseKeys,
      allowWrittenOpenings,
      trustedPrefix: true,
    );
    final incoming = words(spokenText);
    final expectedSeq = <Set<String>>[
      for (var verse = 0; verse < expectedAyahs.length; verse++)
        ..._expectedRecitationWords(
          expectedAyahs[verse],
          expectedVerseKeys[verse],
        ),
    ];
    if (allowWrittenOpenings &&
        retained.isNotEmpty &&
        retained.length == expectedSeq.length) {
      var coversAll = true;
      for (var i = 0; i < retained.length; i++) {
        if (!expectedSeq[i].contains(retained[i])) {
          coversAll = false;
          break;
        }
      }
      // A later window repeating recited words cannot add expected words,
      // but every word it heard must repeat them in order (only its first and
      // last words may be cut by the window), so a wrong word keeps the ayah
      // open.
      if (coversAll &&
          _repeatsRetainedRun(
            retained,
            incoming,
            expectedAyahs,
            expectedVerseKeys,
          )) {
        return retained.join(' ');
      }
    }
    var verseStart = 0;
    for (var verse = 0; verse < expectedAyahs.length; verse++) {
      if (verseStart >= retained.length) break;
      final overlap = retained.length - verseStart;
      if (incoming.length >= overlap) {
        var matches = true;
        for (var i = 0; i < overlap; i++) {
          if (retained[verseStart + i] != incoming[i]) {
            matches = false;
            break;
          }
        }
        if (matches) {
          final joined = [...retained, ...incoming.skip(overlap)].join(' ');
          return allowWrittenOpenings
              ? _spokenWords(
                  joined,
                  expectedAyahs,
                  expectedVerseKeys,
                  allowWrittenOpenings,
                ).join(' ')
              : joined;
        }
      }
      final expected = _expectedRecitationWords(
        expectedAyahs[verse],
        expectedVerseKeys[verse],
      );
      if (retained.length < verseStart + expected.length) break;
      verseStart += expected.length;
    }

    final maxOverlap = retained.length < incoming.length
        ? retained.length
        : incoming.length;
    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      var matches = true;
      List<String>? expandedCandidate;
      for (var i = 0; i < overlap; i++) {
        if (retained[retained.length - overlap + i] != incoming[i]) {
          matches = false;
          break;
        }
      }
      if (!matches && allowWrittenOpenings) {
        final candidate = _spokenWords(
          [...retained.take(retained.length - overlap), ...incoming].join(' '),
          expectedAyahs,
          expectedVerseKeys,
          allowWrittenOpenings,
        );
        if (candidate.length >= retained.length) {
          matches = true;
          for (var i = 0; i < overlap; i++) {
            final idx = retained.length - overlap + i;
            if (candidate[idx] != retained[idx]) {
              matches = false;
              break;
            }
          }
          // The overlap was confirmed on expanded words (e.g. merged
          // مما -> من ما), so raw incoming tokens cannot be skipped 1:1.
          if (matches) expandedCandidate = candidate;
        }
      }
      if (matches &&
          incoming.length > overlap &&
          retained.length + overlap < expectedSeq.length) {
        final directJoined = [...retained, ...incoming].join(' ');
        final directWords = allowWrittenOpenings
            ? _spokenWords(
                directJoined,
                expectedAyahs,
                expectedVerseKeys,
                allowWrittenOpenings,
              )
            : [...retained, ...incoming];
        final strippedJoined = [
          ...retained,
          ...incoming.skip(overlap),
        ].join(' ');
        final strippedWords = allowWrittenOpenings
            ? _spokenWords(
                strippedJoined,
                expectedAyahs,
                expectedVerseKeys,
                allowWrittenOpenings,
              )
            : [...retained, ...incoming.skip(overlap)];
        if (directWords.length > retained.length + overlap &&
            strippedWords.length > retained.length &&
            !expectedSeq[retained.length].contains(
              strippedWords[retained.length],
            )) {
          var matchesDirectContinuation = true;
          for (var i = 0; i <= overlap; i++) {
            if (!expectedSeq[retained.length + i].contains(
              directWords[retained.length + i],
            )) {
              matchesDirectContinuation = false;
              break;
            }
          }
          if (matchesDirectContinuation) {
            matches = false;
          }
        }
      }
      if (matches) {
        if (expandedCandidate != null) {
          return [
            ...retained,
            ...expandedCandidate.skip(retained.length),
          ].join(' ');
        }
        final joined = [...retained, ...incoming.skip(overlap)].join(' ');
        return allowWrittenOpenings
            ? _spokenWords(
                joined,
                expectedAyahs,
                expectedVerseKeys,
                allowWrittenOpenings,
              ).join(' ')
            : joined;
      }
    }
    if (allowWrittenOpenings && incoming.length >= 2 && retained.isNotEmpty) {
      final maxBoundarySkip = incoming.length - 1 < 4 ? incoming.length - 1 : 4;
      for (var skip = 1; skip <= maxBoundarySkip; skip++) {
        final skipped = incoming.skip(skip).toList();
        final maxSkippedOverlap = retained.length < skipped.length
            ? retained.length
            : skipped.length;
        final minOverlap = skip == 1 ? 1 : 2;
        for (
          var overlap = maxSkippedOverlap;
          overlap >= minOverlap;
          overlap--
        ) {
          var matches = true;
          for (var i = 0; i < overlap; i++) {
            if (retained[retained.length - overlap + i] != skipped[i]) {
              matches = false;
              break;
            }
          }
          if (matches) {
            final isMidAyahAnchor =
                overlap <= 2 &&
                _isRepeatedAyahPrefixAnchor(
                  retainedLength: retained.length,
                  overlap: overlap,
                  expectedAyahs: expectedAyahs,
                  expectedVerseKeys: expectedVerseKeys,
                );
            if (!isMidAyahAnchor) {
              return _spokenWords(
                [...retained, ...skipped.skip(overlap)].join(' '),
                expectedAyahs,
                expectedVerseKeys,
                allowWrittenOpenings,
              ).join(' ');
            }
          }
        }
      }
    }
    if (allowWrittenOpenings &&
        incoming.length >= 2 &&
        retained.length > incoming.length) {
      for (var start = 0; start <= retained.length - incoming.length; start++) {
        var matchesSlice = true;
        for (var i = 0; i < incoming.length; i++) {
          if (retained[start + i] != incoming[i]) {
            matchesSlice = false;
            break;
          }
        }
        if (matchesSlice) {
          return retained.join(' ');
        }
      }
    }
    final remainingExpected = expectedSeq.length - retained.length;
    if (allowWrittenOpenings && remainingExpected >= 2) {
      final confirmationWords = remainingExpected < 3 ? remainingExpected : 3;
      for (
        var start = 1;
        start + confirmationWords <= incoming.length;
        start++
      ) {
        if (!_repeatsRetainedSuffix(retained, incoming, start)) continue;
        var matchesCursor = true;
        for (var i = 0; i < confirmationWords; i++) {
          if (!expectedSeq[retained.length + i].contains(incoming[start + i])) {
            matchesCursor = false;
            break;
          }
        }
        if (matchesCursor) {
          return [...retained, ...incoming.skip(start)].join(' ');
        }
      }
    }
    if (allowWrittenOpenings && remainingExpected == 1 && retained.isNotEmpty) {
      for (var cursor = 1; cursor < incoming.length; cursor++) {
        if (incoming[cursor - 1] == retained.last &&
            expectedSeq[retained.length].contains(incoming[cursor])) {
          return [...retained, incoming[cursor]].join(' ');
        }
      }
    }
    final combined = [...retained, ...incoming].join(' ');
    return allowWrittenOpenings
        ? _spokenWords(
            combined,
            expectedAyahs,
            expectedVerseKeys,
            allowWrittenOpenings,
          ).join(' ')
        : combined;
  }

  bool _isRepeatedAyahPrefixAnchor({
    required int retainedLength,
    required int overlap,
    required List<String> expectedAyahs,
    required List<String> expectedVerseKeys,
  }) {
    var total = 0;
    for (var verse = 0; verse < expectedAyahs.length; verse++) {
      final expected = _expectedRecitationWords(
        expectedAyahs[verse],
        expectedVerseKeys[verse],
      );
      if (retainedLength - overlap == total &&
          retainedLength < total + expected.length &&
          verse + 1 < expectedAyahs.length) {
        final nextExpected = _expectedRecitationWords(
          expectedAyahs[verse + 1],
          expectedVerseKeys[verse + 1],
        );
        if (nextExpected.length >= overlap) {
          var samePrefix = true;
          for (var i = 0; i < overlap; i++) {
            if (expected[i].first != nextExpected[i].first) {
              samePrefix = false;
              break;
            }
          }
          if (samePrefix) return true;
        }
      }
      total += expected.length;
    }
    return false;
  }

  /// Evaluate a final recognition segment against consecutive ayahs. Partial
  /// native hypotheses must not be committed: the recognizer can revise them.
  RecitationSequenceCheck checkSequence({
    required List<String> expectedAyahs,
    required String spokenText,
    List<String>? expectedVerseKeys,
    bool allowWrittenOpenings = false,
    bool allowAsrCorrections = true,
  }) {
    if (expectedVerseKeys != null &&
        expectedVerseKeys.length != expectedAyahs.length) {
      throw ArgumentError('Verse keys must correspond to every expected ayah');
    }
    final spoken = _spokenWords(
      spokenText,
      expectedAyahs,
      expectedVerseKeys,
      allowWrittenOpenings,
      allowAsrCorrections: allowAsrCorrections,
    );
    var offset = 0;
    var completed = 0;
    for (final text in expectedAyahs) {
      final expected = _expectedRecitationWords(
        text,
        expectedVerseKeys?[completed],
      );
      if (expected.isEmpty) {
        return RecitationSequenceCheck(completed, '', true, 0);
      }
      var word = 0;
      while (word < expected.length && offset + word < spoken.length) {
        if (!expected[word].contains(spoken[offset + word])) {
          return RecitationSequenceCheck(
            completed,
            '',
            true,
            word,
            matchedPrefixText: spoken.skip(offset).take(word).join(' '),
          );
        }
        word++;
      }
      if (word < expected.length) {
        return RecitationSequenceCheck(
          completed,
          spoken.skip(offset).join(' '),
          false,
          word,
          matchedPrefixText: spoken.skip(offset).take(word).join(' '),
        );
      }
      // Extra words after the last ayah cannot pass as a full-surah match.
      if (completed == expectedAyahs.length - 1 &&
          offset + word != spoken.length) {
        return RecitationSequenceCheck(completed, '', true, word);
      }
      completed++;
      offset += word;
    }
    return RecitationSequenceCheck(completed, '', false, 0);
  }

  /// Finds literal passage evidence in order, consuming each occurrence once.
  /// A passage may be a whole ayah or its retained prefix.
  /// This only gates credit; it must never be used to skip recitation progress.
  List<bool> literalAyahEvidence({
    required List<String> expectedAyahs,
    required List<String> expectedVerseKeys,
    required String spokenText,
  }) {
    if (expectedAyahs.length != expectedVerseKeys.length) {
      throw ArgumentError('Verse keys must correspond to every expected ayah');
    }
    final spoken = _recitationWords(spokenText);
    final evidence = <bool>[];
    var consumed = 0;
    for (var ayah = 0; ayah < expectedAyahs.length; ayah++) {
      final expected = _expectedRecitationWords(
        expectedAyahs[ayah],
        expectedVerseKeys[ayah],
      );
      final written = _recitationWords(expectedAyahs[ayah]);
      final opening = _disconnectedLetters[expectedVerseKeys[ayah]];
      var found = false;
      for (var start = consumed; start < spoken.length && !found; start++) {
        var word = 0;
        var end = start;
        if (opening != null &&
            _acceptWrittenOpening(opening) &&
            written.isNotEmpty &&
            written.first == opening &&
            spoken[end] == opening) {
          word = opening.length;
          end++;
        }
        while (word < expected.length &&
            end < spoken.length &&
            expected[word].contains(spoken[end])) {
          word++;
          end++;
        }
        if (expected.isNotEmpty && word == expected.length) {
          found = true;
          consumed = end;
        }
      }
      evidence.add(found);
    }
    return evidence;
  }

  /// Counts complete printed words in an exact, ordered transcript prefix.
  ///
  /// A recognizer can revise interim hypotheses; counts from an interim
  /// transcript must never be used to commit Hifz progress.
  List<int> matchingPrefixWordCounts({
    required List<String> expectedAyahs,
    required List<String> expectedVerseKeys,
    required String spokenText,
    bool allowWrittenOpenings = false,
  }) {
    if (expectedVerseKeys.length != expectedAyahs.length) {
      throw ArgumentError('Verse keys must correspond to every expected ayah');
    }
    final spoken = _spokenWords(
      spokenText,
      expectedAyahs,
      expectedVerseKeys,
      allowWrittenOpenings,
    );
    final counts = <int>[];
    var offset = 0;
    for (var ayahIndex = 0; ayahIndex < expectedAyahs.length; ayahIndex++) {
      final expected = _expectedRecitationWords(
        expectedAyahs[ayahIndex],
        expectedVerseKeys[ayahIndex],
      );
      var matched = 0;
      while (matched < expected.length && offset < spoken.length) {
        if (!expected[matched].contains(spoken[offset])) break;
        matched++;
        offset++;
      }
      final written = _recitationWords(expectedAyahs[ayahIndex]);
      final opening = _disconnectedLetters[expectedVerseKeys[ayahIndex]];
      final openingLength =
          opening != null && written.isNotEmpty && written.first == opening
          ? opening.length
          : 0;
      // Several spoken letter names occupy one printed opening word.
      counts.add(
        openingLength == 0
            ? matched
            : matched < openingLength
            ? 0
            : matched - openingLength + 1,
      );
      if (matched < expected.length) break;
    }
    return counts;
  }

  /// Strict ordered matching for a complete ayah in ordinary Arabic spelling.
  /// A partial transcript, extra word, or similar-looking substitution cannot
  /// complete an ayah. Display text is never changed by this normalization.
  RecitationWordCheck checkEntireAyah({
    required String expectedImlaei,
    required String spokenText,
    String? expectedVerseKey,
    bool allowWrittenOpenings = false,
    bool allowAsrCorrections = true,
  }) {
    final expected = _expectedRecitationWords(expectedImlaei, expectedVerseKey);
    final spoken = _spokenWords(
      spokenText,
      [expectedImlaei],
      expectedVerseKey == null ? null : [expectedVerseKey],
      allowWrittenOpenings,
      allowAsrCorrections: allowAsrCorrections,
    );
    var prefix = 0;
    while (prefix < expected.length &&
        prefix < spoken.length &&
        expected[prefix].contains(spoken[prefix])) {
      prefix++;
    }
    return RecitationWordCheck(
      matched:
          expected.isNotEmpty &&
          prefix == expected.length &&
          spoken.length == expected.length,
      firstMismatch: prefix,
      wordsExpected: expected.length,
      wordsSpoken: spoken.length,
    );
  }

  static const _disconnectedLetters = {
    '2:1': 'الم',
    '3:1': 'الم',
    '7:1': 'المص',
    '10:1': 'الر',
    '11:1': 'الر',
    '12:1': 'الر',
    '13:1': 'المر',
    '14:1': 'الر',
    '15:1': 'الر',
    '19:1': 'كهيعص',
    '20:1': 'طه',
    '26:1': 'طسم',
    '27:1': 'طس',
    '28:1': 'طسم',
    '29:1': 'الم',
    '30:1': 'الم',
    '31:1': 'الم',
    '32:1': 'الم',
    '36:1': 'يس',
    '38:1': 'ص',
    '40:1': 'حم',
    '41:1': 'حم',
    '42:1': 'حم',
    '42:2': 'عسق',
    '43:1': 'حم',
    '44:1': 'حم',
    '45:1': 'حم',
    '46:1': 'حم',
    '50:1': 'ق',
    '68:1': 'ن',
  };

  static const _letterNames = {
    'ا': {'ألف', 'الف', '1000', '١٠٠٠', '۱۰۰۰'},
    'ل': {'لام'},
    'م': {'ميم'},
    'ص': {'صاد'},
    'ر': {'را', 'راء'},
    'ك': {'كاف'},
    'ه': {'ها', 'هاء'},
    'ي': {'يا', 'ياء'},
    'ع': {'عين'},
    'ط': {'طا', 'طاء'},
    'س': {'سين'},
    'ح': {'حا', 'حاء'},
    'ق': {'قاف'},
    'ن': {'نون'},
  };

  bool _acceptWrittenOpening(String opening) =>
      !requireExplicitAlifLamMeem || opening != 'الم';

  List<Set<String>> _expectedRecitationWords(String text, String? verseKey) {
    final words = _recitationWords(text);
    final opening = _disconnectedLetters[verseKey];
    // Only expand an exact opening at its authoritative verse position.
    // Numeric Alif aliases must never affect ordinary Quran words.
    if (opening != null && words.isNotEmpty && words.first == opening) {
      return [
        for (final letter in opening.split('')) _letterNames[letter]!,
        for (final word in words.skip(1)) {word},
      ];
    }
    return [
      for (final word in words) {word},
    ];
  }

  List<String> _spokenWords(
    String text,
    List<String> expectedAyahs,
    List<String>? keys,
    bool allowWrittenOpenings, {
    bool allowAsrCorrections = true,
    bool trustedPrefix = false,
  }) {
    final spoken = _recitationWords(text);
    if (!allowWrittenOpenings || keys == null) return spoken;
    final expanded = <String>[];
    var offset = 0;
    for (var ayah = 0; ayah < expectedAyahs.length; ayah++) {
      final expected = _expectedRecitationWords(
        expectedAyahs[ayah],
        keys[ayah],
      );
      final written = _recitationWords(expectedAyahs[ayah]);
      final opening = _disconnectedLetters[keys[ayah]];
      var word = 0;
      if (allowAsrCorrections &&
          word == 0 &&
          expected.length >= 2 &&
          offset + 2 <= spoken.length &&
          !expected[0].contains(spoken[offset]) &&
          expected[0].contains(spoken[offset + 1])) {
        var matchesAfterStutter = true;
        final checkCount = expected.length < 2 ? expected.length : 2;
        for (var i = 0; i < checkCount && offset + 1 + i < spoken.length; i++) {
          if (!expected[i].contains(spoken[offset + 1 + i])) {
            matchesAfterStutter = false;
            break;
          }
        }
        if (matchesAfterStutter &&
            offset + 1 + checkCount <= spoken.length &&
            expected[0].first.length > spoken[offset].length &&
            expected[0].first.endsWith(spoken[offset])) {
          offset++;
        }
      }
      if (opening != null &&
          (trustedPrefix || _acceptWrittenOpening(opening)) &&
          written.isNotEmpty &&
          written.first == opening &&
          offset < spoken.length &&
          spoken[offset] == opening) {
        // Quran ASR transcribes spoken letter names as the printed opening.
        expanded.addAll([
          for (final letter in opening.split('')) _letterNames[letter]!.first,
        ]);
        offset++;
        word = opening.length;
      }
      if (allowAsrCorrections &&
          word == 0 &&
          ayah > 0 &&
          expected.length >= 4 &&
          offset + 1 < spoken.length &&
          expanded.length >= 2 &&
          !expected[0].contains(spoken[offset]) &&
          expected[0].contains(expanded[expanded.length - 2]) &&
          expected[1].contains(expanded.last) &&
          expected[2].contains(spoken[offset]) &&
          expected[3].contains(spoken[offset + 1])) {
        expanded.addAll([expected[0].first, expected[1].first]);
        word = 2;
      }
      while (word < expected.length && offset < spoken.length) {
        if (expected[word].contains(spoken[offset])) {
          expanded.add(spoken[offset++]);
          word++;
          continue;
        }
        if (!allowAsrCorrections) return [...expanded, ...spoken.skip(offset)];
        final verseVariants = _verifiedVerseAsrVariants[keys[ayah]];
        if (verseVariants != null &&
            word + 2 < expected.length &&
            offset + 2 < spoken.length &&
            (verseVariants[expected[word].first]?.contains(spoken[offset]) ??
                false) &&
            expected[word + 1].contains(spoken[offset + 1]) &&
            expected[word + 2].contains(spoken[offset + 2])) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (offset + 1 < spoken.length &&
            expected[word].contains('${spoken[offset]}${spoken[offset + 1]}')) {
          expanded.add('${spoken[offset]}${spoken[offset + 1]}');
          offset += 2;
          word++;
          continue;
        }
        Set<String>? nextExpectedSet;
        if (word + 1 < expected.length) {
          nextExpectedSet = expected[word + 1];
        } else if (ayah + 1 < expectedAyahs.length) {
          final nextAyahExpected = _expectedRecitationWords(
            expectedAyahs[ayah + 1],
            keys[ayah + 1],
          );
          if (nextAyahExpected.isNotEmpty) {
            nextExpectedSet = nextAyahExpected.first;
          }
        }
        if (keys[ayah].startsWith('98:') &&
            nextExpectedSet != null &&
            offset + 1 < spoken.length &&
            nextExpectedSet.contains(spoken[offset + 1]) &&
            (_bayyinahAsrVariants[expected[word].first]?.contains(
                  spoken[offset],
                ) ??
                false)) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (keys[ayah] == '98:5' &&
            expected[word].first == 'حنفاء' &&
            offset + 2 < spoken.length &&
            spoken[offset] == 'اكل' &&
            spoken[offset + 1] == 'فاء' &&
            nextExpectedSet != null &&
            nextExpectedSet.contains(spoken[offset + 2])) {
          expanded.add(expected[word].first);
          offset += 2;
          word++;
          continue;
        }
        if (keys[ayah] == '98:6' &&
            word + 2 < expected.length &&
            expected[word].contains('نار') &&
            expected[word + 1].contains('جهنم') &&
            offset + 1 < spoken.length &&
            spoken[offset] == 'نارج' &&
            expected[word + 2].contains(spoken[offset + 1])) {
          expanded.addAll(['نار', 'جهنم']);
          offset++;
          word += 2;
          continue;
        }
        if (nextExpectedSet != null &&
            offset + 1 < spoken.length &&
            nextExpectedSet.contains(spoken[offset + 1]) &&
            _matchesAssimilatedBoundaryWord(
              expected[word].first,
              nextExpectedSet.first,
              spoken[offset],
            )) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (offset + 2 < spoken.length &&
            nextExpectedSet != null &&
            nextExpectedSet.contains(spoken[offset + 2]) &&
            _matchesSplitBoundaryWord(
              expected[word].first,
              spoken[offset],
              spoken[offset + 1],
            )) {
          expanded.add(expected[word].first);
          offset += 2;
          word++;
          continue;
        }
        if (word + 1 < expected.length &&
            offset < spoken.length &&
            expected[word].first.length >= 2 &&
            expected[word + 1].first.length >= 2 &&
            spoken[offset] ==
                '${expected[word].first}${expected[word + 1].first}') {
          // Imla'i spelling joins words the mushaf writes apart (فيما).
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset++;
          word += 2;
          continue;
        }
        if (word + 1 < expected.length &&
            offset < spoken.length &&
            _matchesMergedNoonAssimilation(
              expected[word].first,
              expected[word + 1].first,
              spoken[offset],
            )) {
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset++;
          word += 2;
          continue;
        }
        if (word + 1 < expected.length &&
            offset < spoken.length &&
            _matchesAttachedPronounSplit(
              expected[word].first,
              expected[word + 1].first,
              spoken.sublist(offset),
            )) {
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset += 2;
          word += 2;
          continue;
        }
        if (word + 1 < expected.length &&
            offset < spoken.length &&
            _matchesBoundaryConsonantShift(
              expected[word].first,
              expected[word + 1].first,
              spoken.sublist(offset),
            )) {
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset += 2;
          word += 2;
          continue;
        }
        if (word + 1 < expected.length &&
            offset < spoken.length &&
            _matchesMergedFinalYaAssimilation(
              expected[word].first,
              expected[word + 1].first,
              spoken[offset],
            )) {
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset++;
          word += 2;
          continue;
        }
        if (word + 2 < expected.length &&
            offset + 1 < spoken.length &&
            expected[word + 2].contains(spoken[offset + 1]) &&
            _matchesMergedVerbPhrase(
              expected[word].first,
              expected[word + 1].first,
              spoken[offset],
            )) {
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset++;
          word += 2;
          continue;
        }
        if (nextExpectedSet != null &&
            offset + 1 < spoken.length &&
            _matchesAssimilatedFinalNoonWord(
              expected[word].first,
              nextExpectedSet.first,
              spoken[offset],
              spoken[offset + 1],
            )) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        final hasRightAnchor =
            nextExpectedSet != null &&
            offset + 1 < spoken.length &&
            (nextExpectedSet.contains(spoken[offset + 1]) ||
                (nextExpectedSet.first.length >= 4 &&
                    spoken[offset + 1] == '${nextExpectedSet.first}ا') ||
                _matchesQalqalahPauseEnding(
                  nextExpectedSet.first,
                  spoken[offset + 1],
                ) ||
                _matchesAssimilatedMedialSyllable(
                  nextExpectedSet.first,
                  spoken[offset + 1],
                ));
        if (_matchesMaqsuraToHamzaEnding(
              expected[word].first,
              spoken[offset],
            ) ||
            _matchesTerminalAlifElision(
              expected[word].first,
              spoken[offset],
              hasRightAnchor: hasRightAnchor,
            ) ||
            _matchesTerminalYaInsertion(
              expected[word].first,
              spoken[offset],
              hasRightAnchor: hasRightAnchor,
            )) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (hasRightAnchor &&
            _matchesAssimilatedMedialSyllable(
              expected[word].first,
              spoken[offset],
            )) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        // Hamza seat, taa marbuta or alif maqsura spellings of exactly the
        // expected letters (مغلوله, اسراييل) cannot hide a skipped word.
        if (!quranVocabulary.contains(spoken[offset]) &&
            _foldNearMiss(spoken[offset]).length >= 3 &&
            _foldNearMiss(spoken[offset]) ==
                _foldNearMiss(expected[word].first)) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        // The same letters split at a different place (الربال ايقومون).
        if (offset + 1 < spoken.length) {
          final heard = '${spoken[offset]}${spoken[offset + 1]}';
          var consumed = 0;
          for (final count in const [2, 3]) {
            if (word + count > expected.length) break;
            final written = [
              for (var i = 0; i < count; i++) expected[word + i].first,
            ];
            if (written.join() == heard &&
                written.every((w) => w.length >= 2)) {
              consumed = count;
              break;
            }
          }
          if (consumed > 0) {
            for (var i = 0; i < consumed; i++) {
              expanded.add(expected[word + i].first);
            }
            offset += 2;
            word += consumed;
            continue;
          }
        }
        // A non-Quran ASR spelling close to the expected word, followed by the
        // next two expected words, is a misrecognition rather than a skip.
        if (word + 2 < expected.length &&
            offset + 2 < spoken.length &&
            expected[word + 1].contains(spoken[offset + 1]) &&
            expected[word + 2].contains(spoken[offset + 2]) &&
            !quranVocabulary.contains(spoken[offset]) &&
            _isOrthographicNearMiss(expected[word].first, spoken[offset])) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (word == expected.length - 1 &&
            word > 0 &&
            (_matchesQalqalahPauseEnding(
                  expected[word].first,
                  spoken[offset],
                ) ||
                _matchesAssimilatedMedialSyllable(
                  expected[word].first,
                  spoken[offset],
                ) ||
                (expected[word].first == 'أمر' &&
                    spoken[offset] == 'أمح' &&
                    (hasRightAnchor || expanded.last == 'كل')))) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        return [...expanded, ...spoken.skip(offset)];
      }
      if (word < expected.length) break;
    }
    if (allowAsrCorrections &&
        offset < spoken.length &&
        expectedAyahs.isNotEmpty) {
      final lastExpected = _expectedRecitationWords(
        expectedAyahs.last,
        keys.last,
      );
      final remaining = spoken.length - offset;
      if (lastExpected.length >= 2 && remaining == lastExpected.length) {
        var repeatsLastAyah = true;
        for (var i = 0; i < lastExpected.length; i++) {
          if (!lastExpected[i].contains(spoken[offset + i])) {
            repeatsLastAyah = false;
            break;
          }
        }
        if (repeatsLastAyah) {
          return expanded;
        }
      }
    }
    return [...expanded, ...spoken.skip(offset)];
  }

  /// Words skipped before [start] may be garbled overlap context, but once a
  /// skipped word is an exact retained word, the rest must repeat the retained
  /// suffix exactly, so a new wrong word is never skipped.
  bool _repeatsRetainedSuffix(
    List<String> retained,
    List<String> incoming,
    int start,
  ) {
    if (start == 0) return true;
    if (retained.isEmpty || start > retained.length) return false;
    final known = retained.toSet();
    for (var k = 0; k < start; k++) {
      if (!known.contains(incoming[k])) continue;
      final length = start - k;
      if (length > retained.length) return false;
      for (var i = 0; i < length; i++) {
        if (incoming[k + i] != retained[retained.length - length + i]) {
          return false;
        }
      }
      return true;
    }
    return true;
  }

  bool _repeatsRetainedRun(
    List<String> retained,
    List<String> incoming,
    List<String> expectedAyahs,
    List<String> expectedVerseKeys,
  ) {
    if (incoming.isEmpty) return false;
    bool repeatsFrom(List<String> heard, int at) {
      if (heard.isEmpty || at + heard.length > retained.length) return false;
      for (var i = 0; i < heard.length; i++) {
        final word = _foldNearMiss(heard[i]);
        final kept = _foldNearMiss(retained[at + i]);
        final cutShort =
            i == heard.length - 1 &&
            word.length >= 2 &&
            word.length < kept.length &&
            kept.startsWith(word);
        if (word != kept && !cutShort) return false;
      }
      return true;
    }

    // Applies the same anchored ASR spelling corrections as a recitation that
    // starts at the ayah opening, to a window that starts at expected word [at].
    List<String>? correctedFrom(List<String> heard, int at) {
      var start = 0;
      for (var verse = 0; verse < expectedAyahs.length; verse++) {
        final expected = _expectedRecitationWords(
          expectedAyahs[verse],
          expectedVerseKeys[verse],
        );
        if (at < start + expected.length) {
          final written = _recitationWords(expectedAyahs[verse]);
          final local = at - start - (expected.length - written.length);
          if (local < 0 || (at > start && local == 0)) return null;
          return _spokenWords(
            heard.join(' '),
            [written.skip(local).join(' '), ...expectedAyahs.skip(verse + 1)],
            [expectedVerseKeys[verse], ...expectedVerseKeys.skip(verse + 1)],
            true,
          );
        }
        start += expected.length;
      }
      return null;
    }

    for (final leadingCut in [false, true]) {
      final run = leadingCut ? incoming.skip(1).toList() : incoming;
      if (run.isEmpty || run.length > retained.length) continue;
      if (leadingCut && run.length < 3) continue;
      for (var at = leadingCut ? 1 : 0; at < retained.length; at++) {
        if (leadingCut) {
          // The window started inside the previous word, so only its ending
          // was heard.
          final cut = _foldNearMiss(incoming.first);
          final previous = _foldNearMiss(retained[at - 1]);
          if (cut.length < 2 ||
              cut.length >= previous.length ||
              !previous.endsWith(cut)) {
            continue;
          }
        }
        if (repeatsFrom(run, at)) return true;
        final corrected = correctedFrom(run, at);
        if (corrected != null && repeatsFrom(corrected, at)) return true;
      }
    }
    return false;
  }

  static const _nearMissFolding = {
    'ة': 'ه',
    'ى': 'ي',
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ؤ': 'و',
    'ئ': 'ي',
    'ء': '',
  };

  String _foldNearMiss(String word) =>
      word.split('').map((c) => _nearMissFolding[c] ?? c).join();

  bool _isOrthographicNearMiss(String expectedWord, String spokenWord) {
    String fold(String word) => _foldNearMiss(word);
    final a = fold(expectedWord);
    final b = fold(spokenWord);
    if (b.length < 2) return false;
    if (a == b) return true;
    final longest = a.length > b.length ? a.length : b.length;
    final allowed = longest >= 4 ? 1 : 0;
    if ((a.length - b.length).abs() > allowed) return false;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = <int>[i];
      for (var j = 1; j <= b.length; j++) {
        final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        current.add(
          [substitution, deletion, insertion].reduce((x, y) => x < y ? x : y),
        );
      }
      previous = current;
    }
    return previous.last <= allowed;
  }

  static const _bayyinahAsrVariants = {
    'جاءتهم': {'جاءته', 'جاءتون'},
    'حنفاء': {'انفاء', 'خلفاء'},
    'الزكاة': {'تكاد'},
    'والمشركين': {'والمشفكين'},
    'جهنم': {'جهن', 'جهمة', 'جهر'},
    'أولئك': {'الئك', 'ألئك'},
    'جزاءهم': {'جزاءون'},
    'جزاؤهم': {'جزاءون'},
    'رضي': {'ردي', 'فزي'},
    'خشي': {'خش'},
  };

  static const _verifiedVerseAsrVariants = {
    '2:196': {
      'وأتموا': {'وأتم'},
    },
    '2:255': {
      'يئوده': {'يأوده'},
    },
    '2:286': {
      'نسينا': {'سينا'},
    },
    '3:156': {
      'غزى': {'غزا'},
    },
    '4:92': {
      'خطأ': {'خطئا'},
    },
    '9:36': {
      'اثنا': {'اثنى'},
    },
    '24:35': {
      'كمشكاة': {'كمشكات'},
    },
    '47:15': {
      'مصفى': {'مصفا'},
    },
    '48:25': {
      'محله': {'محلة'},
    },
    '60:4': {
      'برآء': {'براء'},
    },
  };

  bool _matchesAssimilatedBoundaryWord(
    String expectedWord,
    String nextExpectedWord,
    String spokenWord,
  ) {
    if (spokenWord.length == expectedWord.length + 1 &&
        spokenWord.startsWith(expectedWord) &&
        spokenWord.endsWith('ا') &&
        nextExpectedWord.isNotEmpty &&
        (expectedWord.endsWith(nextExpectedWord[0]) ||
            (expectedWord.length >= 4 &&
                (nextExpectedWord.startsWith('ا') ||
                    nextExpectedWord.startsWith('إ') ||
                    nextExpectedWord.startsWith('أ'))))) {
      return true;
    }
    if (expectedWord.length >= 4 &&
        spokenWord.endsWith('وا') &&
        spokenWord.length == expectedWord.length + 2 &&
        nextExpectedWord.isNotEmpty) {
      final stem = spokenWord.substring(0, expectedWord.length);
      if (stem == expectedWord ||
          _matchesAssimilatedMedialSyllable(expectedWord, stem)) {
        return true;
      }
    }
    if (expectedWord.length >= 3 &&
        (spokenWord == 'و$expectedWord' || spokenWord == 'ف$expectedWord') &&
        nextExpectedWord.isNotEmpty) {
      return true;
    }
    return false;
  }

  bool _matchesQalqalahPauseEnding(String expectedWord, String spokenWord) {
    if (expectedWord.length < 3) return false;
    final last = expectedWord[expectedWord.length - 1];
    if (last != 'ب' &&
        last != 'ق' &&
        last != 'ط' &&
        last != 'ج' &&
        last != 'د') {
      return false;
    }
    return spokenWord == '$expectedWordة' ||
        spokenWord == '$expectedWordه' ||
        spokenWord == '$expectedWordا';
  }

  bool _matchesSplitBoundaryWord(
    String expectedWord,
    String firstSpoken,
    String secondSpoken,
  ) {
    if (expectedWord.length < 4 || secondSpoken.length < 3) return false;
    final suffixLength = expectedWord.length - 1;
    final expectedSuffix = expectedWord.substring(1);
    if (secondSpoken == expectedSuffix &&
        firstSpoken.startsWith(expectedWord[0])) {
      return true;
    }
    if (suffixLength >= 4 &&
        secondSpoken == expectedWord.substring(2) &&
        firstSpoken.startsWith(expectedWord[0]) &&
        firstSpoken.endsWith(expectedWord[1])) {
      return true;
    }
    return false;
  }

  bool _matchesMergedNoonAssimilation(
    String expectedWord,
    String nextExpectedWord,
    String spokenWord,
  ) {
    if (expectedWord.length < 2 ||
        !expectedWord.endsWith('ن') ||
        nextExpectedWord.length < 2) {
      return false;
    }
    final stem = expectedWord.substring(0, expectedWord.length - 1);
    if (spokenWord == '$stem$nextExpectedWord') {
      return true;
    }
    if (spokenWord.startsWith(stem) && spokenWord.length > stem.length + 1) {
      final tail = spokenWord.substring(stem.length);
      if (_matchesAssimilatedMedialSyllable(nextExpectedWord, tail)) {
        return true;
      }
    }
    if (expectedWord.length == 2 &&
        spokenWord.startsWith('$stemم') &&
        spokenWord.length > stem.length + 2) {
      final tail = spokenWord.substring(stem.length + 1);
      if (tail == nextExpectedWord ||
          _matchesAssimilatedMedialSyllable(nextExpectedWord, tail)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesBoundaryConsonantShift(
    String expectedWord,
    String nextExpectedWord,
    List<String> remainingSpoken,
  ) {
    if (remainingSpoken.length < 2 ||
        expectedWord.length < 4 ||
        nextExpectedWord.length < 2) {
      return false;
    }
    final firstSpoken = remainingSpoken[0];
    final secondSpoken = remainingSpoken[1];
    final lastChar = expectedWord[expectedWord.length - 1];
    final expectedStem = expectedWord.substring(0, expectedWord.length - 1);
    final shiftedSecond = nextExpectedWord.startsWith('ال')
        ? '$lastChar${nextExpectedWord.substring(1)}'
        : '$lastChar$nextExpectedWord';
    if (secondSpoken == shiftedSecond ||
        _matchesQalqalahPauseEnding(shiftedSecond, secondSpoken)) {
      return firstSpoken == expectedStem ||
          (expectedStem.length == 3 &&
              firstSpoken.length == 3 &&
              expectedStem[0] == firstSpoken[0] &&
              _confusableConsonantPairs.contains((
                expectedStem[2],
                firstSpoken[2],
              )) &&
              expectedStem[1] == firstSpoken[1]) ||
          (expectedStem.length == 3 &&
              firstSpoken.length == 3 &&
              expectedStem[0] == firstSpoken[0] &&
              expectedStem[2] == firstSpoken[2] &&
              _confusableConsonantPairs.contains((
                expectedStem[1],
                firstSpoken[1],
              ))) ||
          _matchesAssimilatedMedialSyllable(expectedStem, firstSpoken);
    }
    return false;
  }

  bool _matchesMergedFinalYaAssimilation(
    String expectedWord,
    String nextExpectedWord,
    String spokenWord,
  ) {
    if (expectedWord.length < 2 ||
        nextExpectedWord.length < 3 ||
        !nextExpectedWord.startsWith('ي')) {
      return false;
    }
    if (spokenWord == '$expectedWord${nextExpectedWord.substring(1)}') {
      return true;
    }
    if (expectedWord.length >= 3 &&
        expectedWord.endsWith('ا') &&
        spokenWord ==
            '${expectedWord.substring(0, expectedWord.length - 1)}$nextExpectedWord') {
      return true;
    }
    return false;
  }

  bool _matchesMergedVerbPhrase(
    String expectedWord,
    String nextExpectedWord,
    String spokenWord,
  ) {
    if (expectedWord == 'فوسطن' &&
        nextExpectedWord == 'به' &&
        spokenWord == 'فاستنبيه') {
      return true;
    }
    return false;
  }

  bool _matchesAttachedPronounSplit(
    String expectedWord,
    String nextExpectedWord,
    List<String> remainingSpoken,
  ) {
    if (remainingSpoken.length < 2 ||
        expectedWord.length < 3 ||
        nextExpectedWord.length < 2) {
      return false;
    }
    final firstSpoken = remainingSpoken[0];
    final secondSpoken = remainingSpoken[1];
    final prefix = nextExpectedWord[0];
    if (firstSpoken == '$expectedWord$prefix' &&
        secondSpoken == nextExpectedWord.substring(1)) {
      return true;
    }
    return false;
  }

  bool _matchesAssimilatedFinalNoonWord(
    String expectedWord,
    String nextExpectedWord,
    String spokenWord,
    String nextSpokenWord,
  ) {
    if (expectedWord.length < 4 ||
        !expectedWord.endsWith('ن') ||
        !nextExpectedWord.startsWith('ل')) {
      return false;
    }
    if (nextSpokenWord != nextExpectedWord) return false;
    final stem = expectedWord.substring(0, expectedWord.length - 1);
    return spokenWord == '$stemم' || spokenWord == '$stemن';
  }

  bool _matchesMaqsuraToHamzaEnding(String expectedWord, String spokenWord) {
    if (expectedWord.length < 4 || !expectedWord.endsWith('اء')) {
      return false;
    }
    final stem = expectedWord.substring(0, expectedWord.length - 2);
    return spokenWord == '$stemى';
  }

  bool _matchesTerminalAlifElision(
    String expectedWord,
    String spokenWord, {
    required bool hasRightAnchor,
  }) {
    if (!hasRightAnchor ||
        expectedWord.length < 3 ||
        !expectedWord.endsWith('ا')) {
      return false;
    }
    return spokenWord == expectedWord.substring(0, expectedWord.length - 1);
  }

  bool _matchesTerminalYaInsertion(
    String expectedWord,
    String spokenWord, {
    required bool hasRightAnchor,
  }) {
    if (!hasRightAnchor ||
        expectedWord.length < 3 ||
        !spokenWord.endsWith('ي')) {
      return false;
    }
    return spokenWord.substring(0, spokenWord.length - 1) == expectedWord;
  }

  static const _confusableConsonantPairs = {
    ('ق', 'ك'),
    ('ك', 'ق'),
    ('ق', 'ط'),
    ('ط', 'ق'),
    ('ط', 'ت'),
    ('ت', 'ط'),
    ('ص', 'س'),
    ('س', 'ص'),
    ('ض', 'د'),
    ('د', 'ض'),
    ('ظ', 'ذ'),
    ('ذ', 'ظ'),
    ('ه', 'ح'),
    ('ح', 'ه'),
    ('ع', 'ح'),
    ('ح', 'ع'),
    ('خ', 'غ'),
    ('غ', 'خ'),
    ('ن', 'د'),
    ('د', 'ن'),
    ('ئ', 'ع'),
    ('ع', 'ئ'),
    ('ض', 'ب'),
    ('ب', 'ض'),
    ('د', 'ب'),
    ('ب', 'د'),
    ('د', 'ر'),
    ('ر', 'د'),
    ('د', 'ل'),
    ('ل', 'د'),
  };

  static const _confusableInitialConsonantPairs = {
    ('ص', 'س'),
    ('س', 'ص'),
    ('ص', 'ف'),
    ('ا', 'إ'),
    ('إ', 'ا'),
    ('ا', 'أ'),
    ('أ', 'ا'),
    ('إ', 'أ'),
    ('أ', 'إ'),
    ('ه', 'ح'),
    ('ح', 'ه'),
    ('ع', 'ح'),
    ('ح', 'ع'),
    ('أ', 'ع'),
    ('ع', 'أ'),
    ('أ', 'آ'),
    ('آ', 'أ'),
    ('ت', 'ط'),
    ('ط', 'ت'),
    ('ت', 'ف'),
    ('ت', 'ق'),
  };

  bool _matchesAssimilatedMedialSyllable(
    String expectedWord,
    String spokenWord,
  ) {
    if (expectedWord.length < 4 || spokenWord.length < 3) return false;
    if (expectedWord.length == spokenWord.length) {
      final diffs = <int>[];
      for (var i = 0; i < expectedWord.length; i++) {
        if (expectedWord[i] != spokenWord[i]) {
          diffs.add(i);
          if (diffs.length > 2) return false;
        }
      }
      if (diffs.isEmpty) return true;
      if (diffs.length == 1) {
        final diffIndex = diffs.single;
        if (diffIndex == 0 && expectedWord.length >= 4) {
          return _confusableInitialConsonantPairs.contains((
            expectedWord[0],
            spokenWord[0],
          ));
        }
        if (diffIndex <= 0 || diffIndex >= expectedWord.length - 1) {
          return false;
        }
        return _confusableConsonantPairs.contains((
          expectedWord[diffIndex],
          spokenWord[diffIndex],
        ));
      }
      if (expectedWord.length >= 4 &&
          expectedWord.substring(2) == spokenWord.substring(2) &&
          expectedWord.startsWith('كع') &&
          (spokenWord.startsWith('قا') || spokenWord.startsWith('خا'))) {
        return true;
      }
      if (diffs.length == 2 &&
          expectedWord.length >= 4 &&
          diffs[1] < expectedWord.length - 1) {
        bool validAt(int idx) {
          if (idx == 0) {
            return _confusableInitialConsonantPairs.contains((
              expectedWord[0],
              spokenWord[0],
            ));
          }
          return _confusableConsonantPairs.contains((
            expectedWord[idx],
            spokenWord[idx],
          ));
        }

        return validAt(diffs[0]) && validAt(diffs[1]);
      }
      return false;
    }
    if (expectedWord.length == spokenWord.length + 1) {
      if (expectedWord.length >= 5 &&
          (expectedWord.startsWith('ا') ||
              expectedWord.startsWith('أ') ||
              expectedWord.startsWith('إ')) &&
          expectedWord.substring(1) == spokenWord) {
        return true;
      }
      for (var i = 1; i < expectedWord.length - 1; i++) {
        if (expectedWord[i] != 'ا' && expectedWord[i] != 'ل') continue;
        final withoutMedial =
            expectedWord.substring(0, i) + expectedWord.substring(i + 1);
        if (withoutMedial == spokenWord) return true;
      }
      if (expectedWord.length >= 4 && expectedWord.startsWith(spokenWord[0])) {
        for (var i = 1; i < expectedWord.length - 1; i++) {
          if (expectedWord[i] != 'ؤ' && expectedWord[i] != 'ئ') continue;
          final withoutMedialHamza =
              expectedWord.substring(0, i) + expectedWord.substring(i + 1);
          if (withoutMedialHamza == spokenWord ||
              _matchesAssimilatedMedialSyllable(
                withoutMedialHamza,
                spokenWord,
              )) {
            return true;
          }
        }
      }
      if (expectedWord.length >= 4 &&
          expectedWord.endsWith('ي') &&
          spokenWord == expectedWord.substring(0, expectedWord.length - 1)) {
        return true;
      }
      if (expectedWord.length >= 4 &&
          (expectedWord.startsWith('أع') || expectedWord.startsWith('اع')) &&
          spokenWord == expectedWord.substring(1)) {
        return true;
      }
    }
    if (spokenWord.length == expectedWord.length + 1 &&
        expectedWord.length >= 2 &&
        spokenWord.endsWith('ي') &&
        spokenWord.substring(0, spokenWord.length - 1) == expectedWord) {
      return true;
    }
    if (expectedWord.length == spokenWord.length + 2 &&
        expectedWord.length >= 5 &&
        expectedWord.startsWith('ال') &&
        !spokenWord.startsWith('ال')) {
      for (var i = 2; i < expectedWord.length - 1; i++) {
        if (expectedWord[i] != 'ا') continue;
        final withoutAlAndMedialAlif =
            expectedWord.substring(2, i) + expectedWord.substring(i + 1);
        if (withoutAlAndMedialAlif == spokenWord) return true;
      }
    }
    if (spokenWord.length == expectedWord.length + 1 &&
        expectedWord.length >= 3 &&
        spokenWord == '$expectedWordي') {
      return true;
    }
    if (spokenWord.length == expectedWord.length + 1 &&
        expectedWord.length >= 4 &&
        spokenWord.startsWith(expectedWord[0])) {
      for (var i = 1; i < spokenWord.length - 1; i++) {
        if (spokenWord[i] != 'و' && spokenWord[i] != 'ا') continue;
        final withoutInserted =
            spokenWord.substring(0, i) + spokenWord.substring(i + 1);
        if (withoutInserted == expectedWord) return true;
      }
    }
    return false;
  }

  List<String> _recitationWords(String text) {
    final normalized = text
        .replaceAll(
          RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'),
          '',
        )
        .replaceAll('\u0671', '\u0627')
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u2069]'), '')
        .replaceAll(RegExp(r'[.,!?:;،؛؟]'), ' ')
        .trim();
    return normalized.isEmpty ? [] : normalized.split(RegExp(r'\s+'));
  }

  /// Compare speech-to-text output against the expected ayah text.
  ///
  /// Returns a [SpeechComparisonResult] with per-word matching status.
  SpeechComparisonResult compare({
    required String expectedArabic,
    required String spokenText,
  }) {
    final expectedWords = _tokenize(expectedArabic);
    final spokenWords = _tokenize(spokenText);

    final matches = <WordMatch>[];
    int spokenIdx = 0;

    for (int i = 0; i < expectedWords.length; i++) {
      final expected = expectedWords[i];

      if (spokenIdx < spokenWords.length) {
        final spoken = spokenWords[spokenIdx];
        final similarity = _similarity(expected, spoken);

        if (similarity >= 0.7) {
          matches.add(
            WordMatch(
              expected: expected,
              spoken: spoken,
              status: similarity >= 0.9
                  ? WordStatus.correct
                  : WordStatus.partial,
              similarity: similarity,
            ),
          );
          spokenIdx++;
        } else {
          // Check if the next spoken word matches (user may have inserted extra)
          if (spokenIdx + 1 < spokenWords.length &&
              _similarity(expected, spokenWords[spokenIdx + 1]) >= 0.7) {
            spokenIdx++; // skip the extra word
            matches.add(
              WordMatch(
                expected: expected,
                spoken: spokenWords[spokenIdx],
                status: WordStatus.partial,
                similarity: _similarity(expected, spokenWords[spokenIdx]),
              ),
            );
            spokenIdx++;
          } else {
            matches.add(
              WordMatch(
                expected: expected,
                spoken: spoken,
                status: WordStatus.missed,
                similarity: similarity,
              ),
            );
          }
        }
      } else {
        // User stopped early — remaining words are missing
        matches.add(
          WordMatch(
            expected: expected,
            spoken: '',
            status: WordStatus.missed,
            similarity: 0.0,
          ),
        );
      }
    }

    final correctCount = matches
        .where((m) => m.status == WordStatus.correct)
        .length;
    final overallAccuracy = matches.isEmpty
        ? 0.0
        : correctCount / matches.length;

    return SpeechComparisonResult(
      wordMatches: matches,
      overallAccuracy: overallAccuracy,
      wordsExpected: expectedWords.length,
      wordsSpoken: spokenWords.length,
    );
  }

  /// Tokenize Arabic text: strip tashkeel, split on whitespace.
  List<String> _tokenize(String text) {
    final stripped = _removeTashkeel(text).trim();
    if (stripped.isEmpty) return [];
    return stripped.split(RegExp(r'\s+'));
  }

  /// Remove Arabic diacritics for loose comparison.
  String _removeTashkeel(String text) {
    return text.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F]'), '');
  }

  /// Compute character-level similarity between two Arabic strings
  /// using Jaccard similarity on character bigrams.
  double _similarity(String a, String b) {
    final cleanA = _removeTashkeel(a);
    final cleanB = _removeTashkeel(b);

    if (cleanA == cleanB) return 1.0;
    if (cleanA.isEmpty || cleanB.isEmpty) return 0.0;

    final bigramsA = _bigrams(cleanA);
    final bigramsB = _bigrams(cleanB);

    if (bigramsA.isEmpty && bigramsB.isEmpty) {
      return cleanA == cleanB ? 1.0 : 0.0;
    }

    final intersection = bigramsA.intersection(bigramsB).length;
    final union = bigramsA.union(bigramsB).length;

    return union > 0 ? intersection / union : 0.0;
  }

  Set<String> _bigrams(String s) {
    if (s.length < 2) return {s};
    return {for (int i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
  }
}

// ── Result models ───────────────────────────────────────────────────────────

class RecitationWordCheck {
  final bool matched;
  final int firstMismatch;
  final int wordsExpected;
  final int wordsSpoken;

  const RecitationWordCheck({
    required this.matched,
    required this.firstMismatch,
    required this.wordsExpected,
    required this.wordsSpoken,
  });
}

class RecitationSequenceCheck {
  final int completedAyahs;
  final String remainingText;
  final bool mismatch;
  final int wordIndex;

  /// Exact spoken prefix of the first unfinished ayah, even on a mismatch.
  /// Empty for a final ayah followed by extra words: that ayah is not accepted.
  final String matchedPrefixText;

  const RecitationSequenceCheck(
    this.completedAyahs,
    this.remainingText,
    this.mismatch,
    this.wordIndex, {
    this.matchedPrefixText = '',
  });
}

enum WordStatus { correct, partial, missed }

class WordMatch {
  final String expected;
  final String spoken;
  final WordStatus status;
  final double similarity;

  const WordMatch({
    required this.expected,
    required this.spoken,
    required this.status,
    required this.similarity,
  });
}

class SpeechComparisonResult {
  final List<WordMatch> wordMatches;
  final double overallAccuracy;
  final int wordsExpected;
  final int wordsSpoken;

  const SpeechComparisonResult({
    required this.wordMatches,
    required this.overallAccuracy,
    required this.wordsExpected,
    required this.wordsSpoken,
  });

  /// Returns words that need improvement (partial or missed).
  List<WordMatch> get wordsNeedingWork =>
      wordMatches.where((m) => m.status != WordStatus.correct).toList();
}
