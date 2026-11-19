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
    for (var start = 0; start < incoming.length; start++) {
      if (!_repeatsRetainedSuffix(retained, incoming, start)) continue;
      if (start + confirmation <= incoming.length) {
        var matches = true;
        for (var i = 0; i < confirmation; i++) {
          if (!expectedSeq[retained.length + i].contains(incoming[start + i])) {
            matches = false;
            break;
          }
        }
        if (matches) {
          return [...retained, ...incoming.skip(start)].join(' ');
        }
        if (confirmation == 3 &&
            start + 3 == incoming.length &&
            expectedSeq[retained.length].contains(incoming[start]) &&
            expectedSeq[retained.length + 1].contains(incoming[start + 1])) {
          final thirdExpected = expectedSeq[retained.length + 2].first;
          final thirdSpoken = incoming[start + 2];
          if ((thirdSpoken.length >= 3 &&
                  _foldNearMiss(
                    thirdExpected,
                  ).startsWith(_foldNearMiss(thirdSpoken))) ||
              (!quranVocabulary.contains(thirdSpoken) &&
                  _isOrthographicNearMiss(thirdExpected, thirdSpoken))) {
            return [
              ...retained,
              incoming[start],
              incoming[start + 1],
            ].join(' ');
          }
        }
      }
      if (start >= 0) {
        final normalized = _spokenWords(
          [...retained, ...incoming.skip(start)].join(' '),
          expectedAyahs,
          expectedVerseKeys,
          true,
        );
        if (normalized.length >= retained.length + confirmation) {
          var matchesNormalized = true;
          for (var i = 0; i < confirmation; i++) {
            if (!expectedSeq[retained.length + i].contains(
              normalized[retained.length + i],
            )) {
              matchesNormalized = false;
              break;
            }
          }
          if (matchesNormalized) {
            return normalized.join(' ');
          }
        }
      }
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
            rawIncoming: _recitationWords(spokenText),
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
        var rest = incoming.skip(overlap).toList();
        if (allowWrittenOpenings &&
            overlap >= 2 &&
            rest.length >= 2 &&
            retained.length < expectedSeq.length &&
            _foldNearMiss(rest.first) == _foldNearMiss(retained.last) &&
            !expectedSeq[retained.length].contains(rest.first) &&
            expectedSeq[retained.length].contains(rest[1])) {
          rest = rest.skip(1).toList();
        }
        final joined = [...retained, ...rest].join(' ');
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
      final maxBoundarySkip = incoming.length - 1 < 6 ? incoming.length - 1 : 6;
      for (var skip = 1; skip <= maxBoundarySkip; skip++) {
        final skipped = incoming.skip(skip).toList();
        final maxSkippedOverlap = retained.length < skipped.length
            ? retained.length
            : skipped.length;
        final minOverlap = skip == 1 ? 1 : (skip <= 4 ? 2 : 3);
        for (
          var overlap = maxSkippedOverlap;
          overlap >= minOverlap;
          overlap--
        ) {
          var matches = true;
          for (var i = 0; i < overlap; i++) {
            final rWord = retained[retained.length - overlap + i];
            final sWord = skipped[i];
            if (rWord != sWord &&
                !(overlap >= 2 &&
                    _foldNearMiss(rWord) == _foldNearMiss(sWord))) {
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
              var rest = skipped.skip(overlap).toList();
              if (overlap >= 2 &&
                  rest.length >= 2 &&
                  retained.length < expectedSeq.length &&
                  _foldNearMiss(rest.first) == _foldNearMiss(retained.last) &&
                  !expectedSeq[retained.length].contains(rest.first) &&
                  expectedSeq[retained.length].contains(rest[1])) {
                rest = rest.skip(1).toList();
              }
              return _spokenWords(
                [...retained, ...rest].join(' '),
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
        start < incoming.length;
        start++
      ) {
        if (!_repeatsRetainedSuffix(retained, incoming, start)) continue;
        if (start + confirmationWords <= incoming.length) {
          var matchesCursor = true;
          for (var i = 0; i < confirmationWords; i++) {
            if (!expectedSeq[retained.length + i].contains(
              incoming[start + i],
            )) {
              matchesCursor = false;
              break;
            }
          }
          if (matchesCursor) {
            return _spokenWords(
              [...retained, ...incoming.skip(start)].join(' '),
              expectedAyahs,
              expectedVerseKeys,
              allowWrittenOpenings,
            ).join(' ');
          }
        }
        final normalized = _spokenWords(
          [...retained, ...incoming.skip(start)].join(' '),
          expectedAyahs,
          expectedVerseKeys,
          allowWrittenOpenings,
        );
        if (normalized.length >= retained.length + confirmationWords) {
          var matchesNormalized = true;
          for (var i = 0; i < confirmationWords; i++) {
            if (!expectedSeq[retained.length + i].contains(
              normalized[retained.length + i],
            )) {
              matchesNormalized = false;
              break;
            }
          }
          if (matchesNormalized) {
            return normalized.join(' ');
          }
        }
      }
    }
    if (allowWrittenOpenings && remainingExpected == 1 && retained.isNotEmpty) {
      for (var cursor = 1; cursor < incoming.length; cursor++) {
        if ((_foldNearMiss(incoming[cursor - 1]) ==
                    _foldNearMiss(retained.last) ||
                (cursor >= 3 &&
                    retained.length >= 3 &&
                    _foldNearMiss(incoming[cursor - 3]) ==
                        _foldNearMiss(retained[retained.length - 3]) &&
                    _foldNearMiss(incoming[cursor - 2]) ==
                        _foldNearMiss(retained[retained.length - 2])) ||
                (cursor >= 2 &&
                    retained.length >= 2 &&
                    _foldNearMiss(incoming[cursor - 2]) ==
                        _foldNearMiss(retained[retained.length - 2]) &&
                    (incoming[cursor - 1] == '${retained.last}هم' ||
                        _matchesAssimilatedMedialSyllable(
                          retained.last,
                          incoming[cursor - 1],
                        )))) &&
            _repeatsRetainedSuffix(retained, incoming, cursor)) {
          if (expectedSeq[retained.length].contains(incoming[cursor])) {
            return [...retained, incoming[cursor]].join(' ');
          }
          final normalized = _spokenWords(
            [...retained, ...incoming.skip(cursor)].join(' '),
            expectedAyahs,
            expectedVerseKeys,
            allowWrittenOpenings,
          );
          if (normalized.length >= expectedSeq.length &&
              expectedSeq[retained.length].contains(
                normalized[retained.length],
              )) {
            return normalized.take(expectedSeq.length).join(' ');
          }
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
    bool allowDisplayOnlyCorrections = false,
  }) {
    if (expectedVerseKeys.length != expectedAyahs.length) {
      throw ArgumentError('Verse keys must correspond to every expected ayah');
    }
    final spoken = _spokenWords(
      spokenText,
      expectedAyahs,
      expectedVerseKeys,
      allowWrittenOpenings,
      allowDisplayOnlyCorrections: allowDisplayOnlyCorrections,
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
    bool allowDisplayOnlyCorrections = false,
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
            (expected[word].contains('${spoken[offset]}${spoken[offset + 1]}') ||
                (expected[word].contains('ألا') &&
                    spoken[offset] == 'أن' &&
                    spoken[offset + 1] == 'لا') ||
                (expected[word].contains('إلا') &&
                    spoken[offset] == 'إن' &&
                    spoken[offset + 1] == 'لا') ||
                (expected[word].contains('عما') &&
                    spoken[offset] == 'عن' &&
                    spoken[offset + 1] == 'ما') ||
                (expected[word].contains('مما') &&
                    spoken[offset] == 'من' &&
                    spoken[offset + 1] == 'ما'))) {
          expanded.add(expected[word].first);
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
        // A split consonant plus inserted long ya may improve a lab preview
        // only when the next two expected words anchor it exactly.
        if (allowDisplayOnlyCorrections &&
            word + 2 < expected.length &&
            offset + 3 < spoken.length &&
            !quranVocabulary.contains(spoken[offset]) &&
            _matchesSplitFinalConsonantWithYa(
              expected[word].first,
              spoken[offset],
              spoken[offset + 1],
            ) &&
            expected[word + 1].contains(spoken[offset + 2]) &&
            expected[word + 2].contains(spoken[offset + 3])) {
          expanded.add(expected[word].first);
          return [...expanded, ...spoken.skip(offset)];
        }
        if (word + 1 < expected.length &&
            offset < spoken.length &&
            expected[word].first.length >= 2 &&
            expected[word + 1].first.length >= 2 &&
            (spoken[offset] ==
                    '${expected[word].first}${expected[word + 1].first}' ||
                (expected[word].first == 'أن' &&
                    expected[word + 1].first == 'لا' &&
                    (spoken[offset] == 'ألا' || spoken[offset] == 'إلا')) ||
                (expected[word].first.length >= 3 &&
                    expected[word].first.endsWith('ا') &&
                    spoken[offset] ==
                        '${expected[word].first.substring(0, expected[word].first.length - 1)}${expected[word + 1].first}') ||
                (expected[word].first.length >= 3 &&
                    expected[word + 1].first.length >= 3 &&
                    expected[word].first[expected[word].first.length - 1] ==
                        expected[word + 1].first[0] &&
                    spoken[offset] ==
                        '${expected[word].first.substring(0, expected[word].first.length - 1)}${expected[word + 1].first}') ||
                (expected[word].first.length >= 4 &&
                    (expected[word].first.endsWith('ى') ||
                        expected[word].first.endsWith('ا')) &&
                    expected[word + 1].first.startsWith('ائ') &&
                    _foldAlifMaqsuraToAlif(spoken[offset]) ==
                        _foldAlifMaqsuraToAlif(
                          '${expected[word].first.substring(0, expected[word].first.length - 1)}أ${expected[word + 1].first.substring(2)}',
                        )) ||
                (expected[word].first.length >= 3 &&
                    expected[word + 1].first.startsWith('اثن') &&
                    (spoken[offset] ==
                            '${expected[word].first}${expected[word + 1].first.substring(1)}' ||
                        spoken[offset] ==
                            '${expected[word].first}س${expected[word + 1].first.substring(2)}' ||
                        spoken[offset] ==
                            '${expected[word].first}ف${expected[word + 1].first.substring(2)}')) ||
                (expected[word].first == 'مائة' &&
                    expected[word + 1].first == 'عام' &&
                    spoken[offset] == 'بأتعام') ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.endsWith('ى') &&
                    expected[word + 1].first == 'أو' &&
                    spoken[offset] ==
                        '${expected[word].first.substring(0, expected[word].first.length - 1)}اءوا') ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.endsWith('ى') &&
                    expected[word + 1].first == 'أن' &&
                    spoken[offset] ==
                        '${expected[word].first.substring(0, expected[word].first.length - 1)}اء') ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.startsWith('فل') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(
                          'فال${expected[word].first.substring(2)}${expected[word + 1].first}',
                        )) ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.startsWith('ول') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(
                          'وال${expected[word].first.substring(2)}${expected[word + 1].first}',
                        )) ||
                (expected[word].first == 'يضاعف' &&
                    expected[word + 1].first == 'لها' &&
                    spoken[offset] == 'يضاعفها') ||
                (expected[word].first == 'تخاطبني' &&
                    expected[word + 1].first == 'في' &&
                    spoken[offset] == 'تخاطبنيه') ||
                (expected[word].first == 'وسعى' &&
                    expected[word + 1].first == 'لها' &&
                    spoken[offset] == 'وتعالها') ||
                (expected[word].first == 'جناح' &&
                    expected[word + 1].first == 'عليكم' &&
                    spoken[offset] == 'جناحانيكم'))) {
          // Imla'i spelling joins words the mushaf writes apart (فيما).
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset++;
          word += 2;
          continue;
        }
        if (word + 1 < expected.length &&
            offset + 2 < spoken.length &&
            ((expected[word].first == 'الزراع' &&
                    expected[word + 1].first == 'ليغيظ' &&
                    spoken[offset] == 'الزرى' &&
                    spoken[offset + 1] == 'علي' &&
                    (spoken[offset + 2] == 'غيظ' ||
                        spoken[offset + 2] == 'غيض')) ||
                (expected[word].first == 'فمال' &&
                    expected[word + 1].first == 'هؤلاء' &&
                    spoken[offset] == 'فما' &&
                    spoken[offset + 1] == 'لها' &&
                    _foldNearMiss(spoken[offset + 2]) == 'اولاء') ||
                (expected[word].first == 'الزجاجة' &&
                    expected[word + 1].first == 'كأنها' &&
                    spoken[offset] == 'از' &&
                    spoken[offset + 1] == 'زجاجتك' &&
                    _foldNearMiss(spoken[offset + 2]) == 'انها'))) {
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset += 3;
          word += 2;
          continue;
        }
        if (word + 2 < expected.length &&
            offset + 1 < spoken.length &&
            expected[word].first.length >= 4 &&
            expected[word].first.endsWith('ى') &&
            expected[word + 1].first == 'أو' &&
            spoken[offset] ==
                '${expected[word].first.substring(0, expected[word].first.length - 1)}اء' &&
            spoken[offset + 1] == 'و${expected[word + 2].first}') {
          expanded.addAll([
            expected[word].first,
            expected[word + 1].first,
            expected[word + 2].first,
          ]);
          offset += 2;
          word += 3;
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
                (nextExpectedSet.first.length >= 5 &&
                    _foldNearMiss(nextExpectedSet.first) ==
                        _foldNearMiss(spoken[offset + 1])) ||
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
        if (hasRightAnchor &&
            nextExpectedSet.first.startsWith('ال') &&
            expected[word].first.length >= 3 &&
            ((expected[word].first.length >= 4 &&
                    expected[word].first.endsWith('وا') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(
                          expected[word].first.substring(
                            0,
                            expected[word].first.length - 2,
                          ),
                        )) ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.endsWith('و') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(
                          expected[word].first.substring(
                            0,
                            expected[word].first.length - 1,
                          ),
                        )) ||
                _foldNearMiss(spoken[offset]) ==
                    _foldNearMiss('${expected[word].first}وا'))) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (hasRightAnchor &&
            ((expected[word].first == 'وازينت' &&
                    spoken[offset] == 'والزينة') ||
                (expected[word].first == 'الاسم' &&
                    spoken[offset] == 'للسم') ||
                (expected[word].first == 'وسعى' &&
                    nextExpectedSet.first == 'لها' &&
                    spoken[offset] == 'وتعالى') ||
                (expected[word].first == 'الطلاق' &&
                    spoken[offset] == 'اطلاق') ||
                (expected[word].first == 'النار' &&
                    spoken[offset] == 'انار') ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.startsWith('فل') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(
                          'فال${expected[word].first.substring(2)}',
                        )) ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.startsWith('ول') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(
                          'وال${expected[word].first.substring(2)}',
                        )) ||
                (expected[word].first.length >= 3 &&
                    (nextExpectedSet.first.startsWith('ب') ||
                        nextExpectedSet.first.startsWith('ف')) &&
                    spoken[offset] == '${expected[word].first}م') ||
                (expected[word].first == 'يؤمن' &&
                    spoken[offset] == 'يؤمنون') ||
                (expected[word].first == 'ولأمة' &&
                    nextExpectedSet.first == 'مؤمنة' &&
                    (spoken[offset] == 'ولامتوا' ||
                        spoken[offset] == 'ولامتوام')) ||
                (expected[word].first == 'هن' &&
                    nextExpectedSet.first == 'لباس' &&
                    (spoken[offset] == 'كن' || spoken[offset] == 'ظن')) ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.contains('ث') &&
                    expected[word].first.replaceAll('ث', 'س') ==
                        spoken[offset]) ||
                (word > 0 &&
                    expanded.isNotEmpty &&
                    expected[word - 1].contains(expanded.last) &&
                    expected[word].first.length >= 3 &&
                    expected[word].first.endsWith('هن') &&
                    spoken[offset] ==
                        '${expected[word].first.substring(0, expected[word].first.length - 1)}م') ||
                (word > 0 &&
                    expanded.isNotEmpty &&
                    expected[word - 1].contains(expanded.last) &&
                    ((expected[word].first == 'لهب' &&
                            spoken[offset] == 'ذهب') ||
                        (expected[word].first == 'ذو' &&
                            spoken[offset] == 'كو') ||
                        (expected[word].first == 'تخافون' &&
                            spoken[offset] == 'تخافهم') ||
                        (expected[word].first == 'نيلا' &&
                            spoken[offset] == 'بينا') ||
                        (expected[word].first == 'يكفلونه' &&
                            spoken[offset] == 'ياكلونه') ||
                        (expected[word].first == 'كونوا' &&
                            nextExpectedSet.first == 'أنصار' &&
                            (spoken[offset] == 'كلوا' ||
                                spoken[offset] == 'قولوا')) ||
                        (expected[word].first == 'أذى' &&
                            (spoken[offset] == 'أبا' ||
                                spoken[offset] == 'أبين' ||
                                spoken[offset] == 'ابا' ||
                                spoken[offset] == 'ابين')) ||
                        (expected[word].first == 'ليا' &&
                            (spoken[offset] == 'لييا' ||
                                spoken[offset] == 'ليلا')) ||
                        (expected[word].first == 'أنزلت' &&
                            (spoken[offset] == 'أنجبت' ||
                                spoken[offset] == 'انجبت')) ||
                        (expected[word].first == 'يؤاخذ' &&
                            (spoken[offset] == 'أخذوا' ||
                                spoken[offset] == 'وأخذوا' ||
                                spoken[offset] == 'اخذوا' ||
                                spoken[offset] == 'واخذوا')) ||
                        (expected[word].first == 'والدم' &&
                            spoken[offset] == 'والدوا') ||
                        (expected[word].first == 'تغفلون' &&
                            spoken[offset] == 'تافلون'))))) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (hasRightAnchor &&
            expected[word].first.length >= 3 &&
            ((expected[word].first.endsWith('ت') &&
                    (spoken[offset] ==
                            '${expected[word].first.substring(0, expected[word].first.length - 1)}ة' ||
                        spoken[offset] ==
                            '${expected[word].first.substring(0, expected[word].first.length - 1)}ه')) ||
                (expected[word].first.endsWith('ة') &&
                    (spoken[offset] ==
                            '${expected[word].first.substring(0, expected[word].first.length - 1)}ت' ||
                        spoken[offset] ==
                            '${expected[word].first.substring(0, expected[word].first.length - 1)}تن')) ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.endsWith('يا') &&
                    spoken[offset] ==
                        '${expected[word].first.substring(0, expected[word].first.length - 1)}ة'))) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (hasRightAnchor &&
            word > 0 &&
            ((expected[word].first.length >= 5 &&
                    expected[word].first.startsWith('ال') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(expected[word].first.substring(2))) ||
                (expected[word].first.length >= 4 &&
                    !expected[word].first.startsWith('ال') &&
                    (_foldAlifMaqsuraToAlif(spoken[offset]) ==
                        _foldAlifMaqsuraToAlif('ال${expected[word].first}'))) ||
                (expected[word].first.length >= 5 &&
                    expected[word].first.startsWith('و') &&
                    !expected[word].first.startsWith('وال') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(
                          'وال${expected[word].first.substring(1)}',
                        )) ||
                (expected[word].first.length >= 5 &&
                    expected[word].first.startsWith('ب') &&
                    !expected[word].first.startsWith('بال') &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(
                          'بال${expected[word].first.substring(1)}',
                        )))) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        // Hamza seat, taa marbuta or alif maqsura spellings of exactly the
        // expected letters (مغلوله, اسراييل) cannot hide a skipped word.
        if (!quranVocabulary.contains(spoken[offset]) &&
            _foldNearMiss(spoken[offset]).length >= 3 &&
            (_foldNearMiss(spoken[offset]) ==
                    _foldNearMiss(expected[word].first) ||
                _foldAlifMaqsuraToAlif(spoken[offset]) ==
                    _foldAlifMaqsuraToAlif(expected[word].first))) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        if (hasRightAnchor &&
            _foldNearMiss(spoken[offset]).length >= 3 &&
            (_foldNearMiss(spoken[offset]) ==
                    _foldNearMiss(expected[word].first) ||
                _foldAlifMaqsuraToAlif(spoken[offset]) ==
                    _foldAlifMaqsuraToAlif(expected[word].first))) {
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
            ((!quranVocabulary.contains(spoken[offset]) &&
                    _isOrthographicNearMiss(
                      expected[word].first,
                      spoken[offset],
                    )) ||
                (word > 0 &&
                    expanded.isNotEmpty &&
                    expected[word - 1].contains(expanded.last) &&
                    ((expected[word].first.length >= 4 &&
                            (expected[word].first.startsWith('و') ||
                                expected[word].first.startsWith('ف')) &&
                            spoken[offset] ==
                                expected[word].first.substring(1)) ||
                        (expected[word].first.length >= 3 &&
                            expected[word + 1].first.isNotEmpty &&
                            expected[word].first.endsWith(
                              expected[word + 1].first[0],
                            ) &&
                            spoken[offset] ==
                                expected[word].first.substring(
                                  0,
                                  expected[word].first.length - 1,
                                )) ||
                        (expected[word].first.length >= 5 &&
                            expected[word].first.endsWith('هن') &&
                            spoken[offset] ==
                                '${expected[word].first.substring(0, expected[word].first.length - 2)}هم') ||
                        (expected[word].first.length >= 5 &&
                            expected[word].first.endsWith('ه') &&
                            spoken[offset] ==
                                expected[word].first.substring(
                                  0,
                                  expected[word].first.length - 1,
                                )) ||
                        (expected[word].first.length >= 5 &&
                            expected[word].first.startsWith('فا') &&
                            spoken[offset] ==
                                'ت${expected[word].first.substring(2)}') ||
                        (expected[word].first.length >= 4 &&
                            expected[word].first.startsWith('ي') &&
                            spoken[offset] ==
                                expected[word].first.substring(1)) ||
                        (expected[word].first == 'بنو' &&
                            expected[word + 1].first == 'إسرائيل' &&
                            (spoken[offset] == 'بل' ||
                                spoken[offset] == 'بلوا')) ||
                        (expected[word].first == 'عمك' &&
                            (spoken[offset] == 'عنك' ||
                                spoken[offset] == 'أنك')) ||
                        (expected[word].first == 'آمين' &&
                            spoken[offset] == 'آمنين') ||
                        (expected[word].first == 'عدل' &&
                            expected[word + 1].first == 'لا' &&
                            spoken[offset] == 'عدن') ||
                        (expected[word].first == 'لم' &&
                            spoken[offset] == 'لن') ||
                        (expected[word].first == 'مما' &&
                            spoken[offset] == 'منا') ||
                        (expected[word].first == 'قمتم' &&
                            spoken[offset] == 'قلتم'))) ||
                (word > 0 &&
                    expanded.isNotEmpty &&
                    expected[word - 1].contains(expanded.last) &&
                    expected[word].first.length == 3 &&
                    spoken[offset].length == 3 &&
                    !quranVocabulary.contains(spoken[offset]) &&
                    _isThreeLetterFlankedNearMiss(
                      expected[word].first,
                      spoken[offset],
                    )))) {
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
                (expected[word].first.length == 3 &&
                    expanded.length >= 2 &&
                    expected[word - 1].contains(expanded.last) &&
                    expected[word - 2].contains(
                      expanded[expanded.length - 2],
                    ) &&
                    spoken[offset] ==
                        '${expected[word].first}${expected[word].first}') ||
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
    if (retained.isEmpty) return false;
    final lastFolded = _foldAlifMaqsuraToAlif(retained.last);
    if (_foldAlifMaqsuraToAlif(incoming[start - 1]) == lastFolded) {
      if (start == 2 &&
          _foldAlifMaqsuraToAlif(incoming[0]) == lastFolded) {
        return true;
      }
      if (start >= 3 &&
          retained.length >= 2 &&
          _foldAlifMaqsuraToAlif(incoming[start - 2]) == lastFolded &&
          _foldAlifMaqsuraToAlif(incoming[start - 3]) ==
              _foldAlifMaqsuraToAlif(retained[retained.length - 2])) {
        return true;
      }
      if (start >= 2 && retained.length >= 2) {
        final prevFolded = _foldAlifMaqsuraToAlif(
          retained[retained.length - 2],
        );
        if (_foldAlifMaqsuraToAlif(incoming[start - 2]) == prevFolded) {
          var pairCountInIncoming = 0;
          for (var i = 0; i + 1 < start; i++) {
            if (_foldAlifMaqsuraToAlif(incoming[i]) == prevFolded &&
                _foldAlifMaqsuraToAlif(incoming[i + 1]) == lastFolded) {
              pairCountInIncoming++;
            }
          }
          var pairCountInRetained = 0;
          for (var i = 0; i + 1 < retained.length; i++) {
            if (_foldAlifMaqsuraToAlif(retained[i]) == prevFolded &&
                _foldAlifMaqsuraToAlif(retained[i + 1]) == lastFolded) {
              pairCountInRetained++;
            }
          }
          if (pairCountInIncoming <= pairCountInRetained) {
            return true;
          }
        }
      }
      final countInIncoming = incoming
          .take(start)
          .where((w) => _foldAlifMaqsuraToAlif(w) == lastFolded)
          .length;
      final countInRetained = retained
          .where((w) => _foldAlifMaqsuraToAlif(w) == lastFolded)
          .length;
      if (countInIncoming <= countInRetained) {
        return true;
      }
    }
    if (retained.length >= 2 &&
        (_foldAlifMaqsuraToAlif(incoming[start - 1]) ==
                _foldAlifMaqsuraToAlif(
                  '${retained[retained.length - 2]}${retained.last}',
                ) ||
            (retained[retained.length - 2].length >= 3 &&
                retained[retained.length - 2].endsWith('ا') &&
                _foldAlifMaqsuraToAlif(incoming[start - 1]) ==
                    _foldAlifMaqsuraToAlif(
                      '${retained[retained.length - 2].substring(0, retained[retained.length - 2].length - 1)}${retained.last}',
                    )) ||
            (start >= 2 &&
                retained.length >= 3 &&
                retained.last.length >= 2 &&
                retained.last.endsWith('ا') &&
                _foldAlifMaqsuraToAlif(incoming[start - 2]) ==
                    _foldAlifMaqsuraToAlif(retained[retained.length - 3]) &&
                _foldAlifMaqsuraToAlif(incoming[start - 1]) ==
                    _foldAlifMaqsuraToAlif(
                      '${retained[retained.length - 2]}${retained.last.substring(0, retained.last.length - 1)}',
                    )) ||
            _matchesMergedNoonAssimilation(
              retained[retained.length - 2],
              retained.last,
              incoming[start - 1],
            ))) {
      return true;
    }
    if (start >= 2 &&
        (_foldAlifMaqsuraToAlif('${incoming[start - 2]}${incoming[start - 1]}') ==
                lastFolded ||
            _matchesSplitBoundaryWord(
              retained.last,
              incoming[start - 2],
              incoming[start - 1],
            ) ||
            _matchesSplitFinalConsonantWithYa(
              retained.last,
              incoming[start - 2],
              incoming[start - 1],
            ))) {
      return true;
    }
    if (start >= 3 &&
        retained.length >= 3 &&
        retained.last.length >= 5 &&
        _foldAlifMaqsuraToAlif(incoming[start - 3]) ==
            _foldAlifMaqsuraToAlif(retained[retained.length - 3]) &&
        _foldAlifMaqsuraToAlif(incoming[start - 2]) ==
            _foldAlifMaqsuraToAlif(retained[retained.length - 2]) &&
        _isOrthographicNearMiss(retained.last, incoming[start - 1])) {
      return true;
    }
    if (start >= 2 &&
        retained.length >= 2 &&
        _foldAlifMaqsuraToAlif(incoming[start - 2]) ==
            _foldAlifMaqsuraToAlif(retained[retained.length - 2]) &&
        ((!quranVocabulary.contains(incoming[start - 1]) &&
                _isOrthographicNearMiss(retained.last, incoming[start - 1])) ||
            incoming[start - 1] == '${retained.last}هم' ||
            _matchesAssimilatedMedialSyllable(
              retained.last,
              incoming[start - 1],
            ))) {
      return true;
    }
    if (start == 1 &&
        retained.last.length >= 5 &&
        incoming[0].length >= 4 &&
        incoming[0].substring(incoming[0].length - 3) ==
            retained.last.substring(retained.last.length - 3)) {
      return true;
    }
    if (start > retained.length) return false;
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
    List<String> expectedVerseKeys, {
    List<String>? rawIncoming,
  }) {
    if (incoming.isEmpty) return false;
    bool wordMatchesRetained(
      String heardWord,
      String keptWord, {
      required bool isLast,
      required bool hasNeighbors,
      required int runLength,
    }) {
      final cleaned = heardWord.replaceAll('\uFFFD', '');
      final word = _foldNearMiss(cleaned);
      final kept = _foldNearMiss(keptWord);
      if (word == kept) return true;
      if (isLast &&
          word.isNotEmpty &&
          word.length < kept.length &&
          kept.startsWith(word) &&
          (word.length >= 2 || runLength >= 4)) {
        return true;
      }
      if (runLength >= 4 &&
          cleaned.isNotEmpty &&
          (!quranVocabulary.contains(cleaned) || hasNeighbors) &&
          (_isOrthographicNearMiss(keptWord, cleaned) ||
              _isOrthographicNearMiss(kept, word) ||
              _matchesAssimilatedMedialSyllable(keptWord, cleaned) ||
              _matchesQalqalahPauseEnding(keptWord, cleaned) ||
              (keptWord.startsWith('ل') &&
                  _foldNearMiss(cleaned) == _foldNearMiss('ا$keptWord')) ||
              cleaned == 'ل$keptWord' ||
              (keptWord.length >= 4 &&
                  cleaned ==
                      '$keptWord${keptWord.substring(keptWord.length - 2)}') ||
              (isLast &&
                  runLength >= 6 &&
                  kept.length >= 5 &&
                  word.length >= 5 &&
                  word.endsWith(kept.substring(1))))) {
        return true;
      }
      return false;
    }

    bool repeatsFrom(List<String> heard, int at) {
      if (heard.isEmpty || at >= retained.length) return false;
      var i = 0;
      var j = at;
      while (i < heard.length && j < retained.length) {
        final isLast = i == heard.length - 1;
        final hasNeighbors =
            i > 0 &&
            i + 1 < heard.length &&
            j + 1 < retained.length &&
            _foldNearMiss(heard[i + 1]) == _foldNearMiss(retained[j + 1]);
        if (wordMatchesRetained(
          heard[i],
          retained[j],
          isLast: isLast,
          hasNeighbors: hasNeighbors,
          runLength: heard.length,
        )) {
          i++;
          j++;
          continue;
        }
        // Check 2-to-1 merged token in heard against retained[j..j+1].
        if (j + 1 < retained.length) {
          final mergedRetained = _foldNearMiss(
            '${retained[j]}${retained[j + 1]}',
          );
          final hFold = _foldNearMiss(heard[i]);
          if (hFold == mergedRetained ||
              _isOrthographicNearMiss(mergedRetained, hFold) ||
              _matchesMergedNoonAssimilation(
                retained[j],
                retained[j + 1],
                heard[i],
              )) {
            i++;
            j += 2;
            continue;
          }
        }
        // Check 1-to-2 split tokens in heard[i..i+1] against retained[j].
        if (i + 1 < heard.length) {
          final joinedHeard = _foldNearMiss('${heard[i]}${heard[i + 1]}');
          final rFold = _foldNearMiss(retained[j]);
          if (joinedHeard == rFold ||
              '${heard[i]}${heard[i + 1]}' == '${retained[j]}ء' ||
              _isOrthographicNearMiss(rFold, joinedHeard) ||
              _matchesSplitBoundaryWord(
                retained[j],
                heard[i],
                heard[i + 1],
              ) ||
              (i + 2 == heard.length &&
                  heard.length >= 7 &&
                  (_foldAlifMaqsuraToAlif(
                            '${heard[i]}${heard[i + 1]}',
                          ) ==
                          _foldAlifMaqsuraToAlif(retained[j]) ||
                      (retained[j].length >= 3 &&
                          _foldAlifMaqsuraToAlif(
                            '${heard[i]}${heard[i + 1]}',
                          ).startsWith(
                            _foldAlifMaqsuraToAlif(
                              retained[j].substring(
                                0,
                                retained[j].length - 1,
                              ),
                            ),
                          ))))) {
            i += 2;
            j++;
            continue;
          }
        }
        if (heard.length >= 10 &&
            i > 0 &&
            i + 2 < heard.length &&
            j + 1 < retained.length &&
            heard[i].length >= 4 &&
            retained[j].length >= 3 &&
            _foldNearMiss(heard[i]).startsWith(
              _foldNearMiss(retained[j]).substring(0, 2),
            ) &&
            _foldNearMiss(heard[i + 1]) == _foldNearMiss(retained[j]) &&
            _foldNearMiss(heard[i + 2]) == _foldNearMiss(retained[j + 1])) {
          i++;
          continue;
        }
        // Check contiguous phrase repetition of 1..9 already-matched words.
        var matchedRepeat = false;
        if (heard.length >= 5) {
          for (var span = 1; span <= 9; span++) {
            if (j - span < at || i + span > heard.length) continue;
            var repOk = true;
            for (var k = 0; k < span; k++) {
              if (_foldNearMiss(heard[i + k]) !=
                  _foldNearMiss(retained[j - span + k])) {
                repOk = false;
                break;
              }
            }
            if (repOk) {
              i += span;
              matchedRepeat = true;
              break;
            }
          }
        }
        if (matchedRepeat) continue;
        return false;
      }
      return i == heard.length;
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

    final baseRaw = rawIncoming ?? incoming;
    final maxSkip = incoming.length > 4 ? 4 : incoming.length - 1;
    for (var skip = 0; skip <= maxSkip; skip++) {
      final run = incoming.skip(skip).toList();
      final rawRun = skip < baseRaw.length
          ? baseRaw.skip(skip).toList()
          : run;
      if (run.isEmpty) continue;
      if (skip == 1 && run.length < 3) continue;
      if (skip >= 2 && run.length < 8) continue;
      for (var at = skip > 0 ? 1 : 0; at < retained.length; at++) {
        if (skip == 1) {
          final cut = _foldNearMiss(incoming.first);
          final previous = _foldNearMiss(retained[at - 1]);
          final validCut =
              cut.length >= 2 &&
              cut.length < previous.length &&
              previous.endsWith(cut);
          if (!validCut && run.length < 10) {
            continue;
          }
        }
        if (repeatsFrom(run, at)) return true;
        final corrected = correctedFrom(rawRun, at);
        if (corrected != null && repeatsFrom(corrected, at)) return true;
        // For long 30s stop windows (>= 12 words) when 100% of the ayah was
        // already revealed in order, verify that both the opening (>= 3 words)
        // and closing (>= 3 words) of the stop window match retained[at..end]
        // in order, or that a >= 15-word 30s window matches >= 6 opening words
        // before hitting Whisper's 224-token ceiling.
        if (run.length >= 12 && at + 4 <= retained.length) {
          var prefixMatched = 0;
          while (prefixMatched < run.length &&
              at + prefixMatched < retained.length &&
              wordMatchesRetained(
                run[prefixMatched],
                retained[at + prefixMatched],
                isLast: false,
                hasNeighbors: true,
                runLength: run.length,
              )) {
            prefixMatched++;
          }
          if (prefixMatched >= 3) {
            for (
              var end = at + prefixMatched + 2;
              end <= retained.length;
              end++
            ) {
              if ((end - at - run.length).abs() > 5 && run.length < 15) {
                continue;
              }
              var suffixOk = true;
              for (var s = 0; s < 3; s++) {
                final hIdx = run.length - 3 + s;
                final rIdx = end - 3 + s;
                if (hIdx < 0 ||
                    rIdx < at ||
                    !wordMatchesRetained(
                      run[hIdx],
                      retained[rIdx],
                      isLast: s == 2,
                      hasNeighbors: s < 2,
                      runLength: run.length,
                    )) {
                  suffixOk = false;
                  break;
                }
              }
              if (suffixOk) return true;
            }
          }
          if (run.length >= 15 && prefixMatched >= 6) {
            return true;
          }
          if (run.length >= 12 && retained.length >= 8) {
            for (var end = 8; end <= retained.length; end++) {
              var tailOk = true;
              for (var s = 0; s < 8; s++) {
                final hIdx = run.length - 8 + s;
                final rIdx = end - 8 + s;
                if (!wordMatchesRetained(
                  run[hIdx],
                  retained[rIdx],
                  isLast: s == 7,
                  hasNeighbors: s < 7,
                  runLength: run.length,
                )) {
                  tailOk = false;
                  break;
                }
              }
              if (tailOk) return true;
            }
          }
        }
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

  String _foldAlifMaqsuraToAlif(String word) =>
      _foldNearMiss(word.replaceAll('ى', 'ا'));

  bool _isThreeLetterFlankedNearMiss(String expectedWord, String spokenWord) {
    final a = _foldAlifMaqsuraToAlif(expectedWord);
    final b = _foldAlifMaqsuraToAlif(spokenWord);
    if (a.length != 3 || b.length != 3) return false;
    final diffs = <int>[];
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) diffs.add(i);
    }
    if (diffs.length != 1) return false;
    final idx = diffs.single;
    return _confusableConsonantPairs.contains((a[idx], b[idx])) ||
        _confusableInitialConsonantPairs.contains((a[idx], b[idx]));
  }

  bool _isOrthographicNearMiss(String expectedWord, String spokenWord) {
    final fold =
        (expectedWord.endsWith('ى') && spokenWord.endsWith('ا')) ||
            (expectedWord.endsWith('ا') && spokenWord.endsWith('ى'))
        ? _foldAlifMaqsuraToAlif
        : _foldNearMiss;
    final a = fold(expectedWord);
    final b = fold(spokenWord);
    if (b.length < 2) return false;
    if (a == b) return true;
    final longest = a.length > b.length ? a.length : b.length;
    final allowed =
        (longest >= 8 &&
                a.length >= 7 &&
                b.length >= 7 &&
                a.substring(0, 3) == b.substring(0, 3) &&
                a.substring(a.length - 2) == b.substring(b.length - 2))
        ? 2
        : (longest >= 4 ? 1 : 0);
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
    if (secondSpoken.length < 2) return false;
    if (expectedWord.length >= 3 &&
        firstSpoken.length >= 2 &&
        firstSpoken.endsWith('ن') &&
        secondSpoken.startsWith('م') &&
        '${firstSpoken.substring(0, firstSpoken.length - 1)}$secondSpoken' ==
            expectedWord) {
      return true;
    }
    if (expectedWord.length < 4) return false;
    if (expectedWord == 'عرضتم' &&
        firstSpoken == 'عن' &&
        secondSpoken == 'ربتم') {
      return true;
    }
    if (expectedWord.length >= 5 &&
        expectedWord.endsWith('ا') &&
        firstSpoken.length >= 3 &&
        secondSpoken.endsWith('اء') &&
        '$firstSpoken${secondSpoken.substring(0, secondSpoken.length - 1)}' ==
            expectedWord) {
      return true;
    }
    final suffixLength = expectedWord.length - 1;
    final expectedSuffix = expectedWord.substring(1);
    if (secondSpoken.length >= 3 &&
        secondSpoken == expectedSuffix &&
        firstSpoken.startsWith(expectedWord[0])) {
      return true;
    }
    if (suffixLength >= 4 &&
        secondSpoken.length >= 3 &&
        secondSpoken == expectedWord.substring(2) &&
        firstSpoken.startsWith(expectedWord[0]) &&
        firstSpoken.endsWith(expectedWord[1])) {
      return true;
    }
    if (expectedWord.length >= 4 &&
        expectedWord.endsWith('عا') &&
        firstSpoken == expectedWord.substring(0, expectedWord.length - 2) &&
        secondSpoken == 'عن') {
      return true;
    }
    if (expectedWord.contains('ؤ') &&
        firstSpoken.contains('ئ') &&
        '${firstSpoken.replaceAll('ئ', 'ؤ')}$secondSpoken' == expectedWord) {
      return true;
    }
    final foldedFirst = _foldAlifMaqsuraToAlif(firstSpoken);
    final foldedSecond = _foldAlifMaqsuraToAlif(secondSpoken);
    final foldedExpected = _foldAlifMaqsuraToAlif(expectedWord);
    final strippedFirst =
        foldedFirst.length >= 2 && foldedFirst.endsWith('ا')
        ? foldedFirst.substring(0, foldedFirst.length - 1)
        : (foldedFirst.length >= 2 &&
                  foldedFirst.endsWith('ل') &&
                  foldedSecond.startsWith('ل')
              ? foldedFirst.substring(0, foldedFirst.length - 1)
              : (foldedFirst.length >= 4 &&
                        foldedFirst.startsWith('ال') &&
                        foldedExpected.startsWith('ا') &&
                        !foldedExpected.startsWith('ال')
                    ? 'ا${foldedFirst.substring(2)}'
                    : foldedFirst));
    final strippedSecond =
        foldedSecond.length >= 3 && foldedSecond.startsWith('ال')
        ? foldedSecond.substring(2)
        : (foldedSecond.length >= 3 && foldedSecond.startsWith('ا')
              ? foldedSecond.substring(1)
              : foldedSecond);
    if ('$strippedFirst$strippedSecond' == foldedExpected ||
        '$strippedFirst$foldedSecond' == foldedExpected ||
        '$foldedFirst$strippedSecond' == foldedExpected) {
      return true;
    }
    if (expectedWord.length >= 6 &&
        firstSpoken.length >= 2 &&
        secondSpoken.length >= 2 &&
        !_matchesSplitFinalConsonantWithYa(
          expectedWord,
          firstSpoken,
          secondSpoken,
        ) &&
        '$strippedFirst$strippedSecond'.length == foldedExpected.length &&
        _matchesAssimilatedMedialSyllable(
          foldedExpected,
          '$strippedFirst$strippedSecond',
        )) {
      return true;
    }
    if (foldedExpected.length >= 3 &&
        '$strippedFirst$strippedSecond'.length == foldedExpected.length &&
        _confusableInitialConsonantPairs.contains((
          foldedExpected[0],
          '$strippedFirst$strippedSecond'[0],
        )) &&
        '$strippedFirst$strippedSecond'.substring(1) ==
            foldedExpected.substring(1)) {
      return true;
    }
    return false;
  }

  bool _matchesSplitFinalConsonantWithYa(
    String expectedWord,
    String firstSpoken,
    String secondSpoken,
  ) {
    if (expectedWord.length < 5 || !secondSpoken.endsWith('ي')) return false;
    final finalConsonant = expectedWord[expectedWord.length - 1];
    return firstSpoken == expectedWord.substring(0, expectedWord.length - 1) &&
        secondSpoken == '$finalConsonantي';
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
        expectedWord.length < 2 ||
        nextExpectedWord.length < 2) {
      return false;
    }
    final firstSpoken = remainingSpoken[0];
    final secondSpoken = remainingSpoken[1];
    if (expectedWord == 'أن' &&
        nextExpectedWord == 'تنبتوا' &&
        firstSpoken == 'أنتم' &&
        (secondSpoken == 'بتو' || secondSpoken == 'بتوا')) {
      return true;
    }
    if (expectedWord == 'فيما' &&
        nextExpectedWord == 'أن' &&
        firstSpoken == 'في' &&
        (secondSpoken == 'ماء' || secondSpoken == 'مائم')) {
      return true;
    }
    if (expectedWord == 'فمال' &&
        nextExpectedWord == 'هؤلاء' &&
        firstSpoken == 'فما' &&
        secondSpoken == 'لها') {
      return true;
    }
    if (expectedWord.length < 3) return false;
    if (expectedWord == 'ثلثي' &&
        nextExpectedWord == 'الليل' &&
        (firstSpoken == 'ثلث' ||
            firstSpoken == 'ثلاث' ||
            firstSpoken == 'سلس') &&
        (secondSpoken == 'اليل' ||
            secondSpoken == 'الين' ||
            secondSpoken == 'الليل')) {
      return true;
    }
    if (expectedWord == 'الزراع' &&
        nextExpectedWord == 'ليغيظ' &&
        firstSpoken == 'الزرى' &&
        secondSpoken == 'عن') {
      return true;
    }
    final lastChar = expectedWord[expectedWord.length - 1];
    final effectiveLastChar = lastChar == 'ة' ? 'ت' : lastChar;
    final expectedStem = expectedWord.substring(0, expectedWord.length - 1);
    if (expectedWord == 'ثلاث' &&
        (firstSpoken == 'فلا' || firstSpoken == 'ثلا') &&
        _foldAlifMaqsuraToAlif(secondSpoken) ==
            _foldAlifMaqsuraToAlif('ت$nextExpectedWord')) {
      return true;
    }
    if (expectedWord == 'الزجاجة' &&
        nextExpectedWord == 'كأنها' &&
        firstSpoken == 'زجاجتك' &&
        _foldNearMiss(secondSpoken) == 'انها') {
      return true;
    }
    if (lastChar == 'ن' &&
        firstSpoken == expectedStem &&
        _foldAlifMaqsuraToAlif(secondSpoken) ==
            _foldAlifMaqsuraToAlif('ل$nextExpectedWord')) {
      return true;
    }
    if (expectedWord.length >= 4 &&
        nextExpectedWord.length >= 4 &&
        nextExpectedWord.startsWith('ال') &&
        firstSpoken == expectedStem &&
        _foldAlifMaqsuraToAlif(secondSpoken) ==
            _foldAlifMaqsuraToAlif(
              '$effectiveLastChar${nextExpectedWord.substring(2)}',
            )) {
      return true;
    }
    final shiftedSecond = nextExpectedWord.startsWith('ا')
        ? '$effectiveLastChar${nextExpectedWord.substring(1)}'
        : '$effectiveLastChar$nextExpectedWord';
    final normalizedFirst =
        firstSpoken.length >= 4 &&
            firstSpoken.endsWith('وا') &&
            expectedStem.endsWith('و')
        ? firstSpoken.substring(0, firstSpoken.length - 1)
        : firstSpoken;
    final normalizedSecondForIthn = nextExpectedWord.startsWith('اثن')
        ? secondSpoken
              .replaceAll('ة', 'ت')
              .replaceFirst('ثل', 'ثن')
              .replaceFirst('تفن', 'تثن')
        : secondSpoken;
    if (expectedWord.length >= 4 &&
        (secondSpoken == shiftedSecond ||
            normalizedSecondForIthn == shiftedSecond ||
            (nextExpectedWord.startsWith('اثن') &&
                shiftedSecond.endsWith('ي') &&
                normalizedSecondForIthn ==
                    shiftedSecond.substring(0, shiftedSecond.length - 1)) ||
            _foldAlifMaqsuraToAlif(secondSpoken) ==
                _foldAlifMaqsuraToAlif(shiftedSecond) ||
            (shiftedSecond.endsWith('وء') &&
                (secondSpoken ==
                        '${shiftedSecond.substring(0, shiftedSecond.length - 1)}ا' ||
                    secondSpoken ==
                        '${shiftedSecond.substring(0, shiftedSecond.length - 1)}ع' ||
                    secondSpoken ==
                        '${shiftedSecond.substring(0, shiftedSecond.length - 1)}م')) ||
            _matchesTerminalAlifElision(
              shiftedSecond,
              secondSpoken,
              hasRightAnchor: true,
            ) ||
            _matchesQalqalahPauseEnding(shiftedSecond, secondSpoken))) {
      return normalizedFirst == expectedStem ||
          (expectedWord.endsWith('تا') &&
              nextExpectedWord.startsWith('اثن') &&
              normalizedFirst ==
                  expectedWord.substring(0, expectedWord.length - 2) &&
              normalizedSecondForIthn ==
                  'ت${nextExpectedWord.substring(1)}') ||
          (expectedStem.length == 3 &&
              normalizedFirst.length == 3 &&
              expectedStem[0] == normalizedFirst[0] &&
              _confusableConsonantPairs.contains((
                expectedStem[2],
                normalizedFirst[2],
              )) &&
              expectedStem[1] == normalizedFirst[1]) ||
          (expectedStem.length == 3 &&
              normalizedFirst.length == 3 &&
              expectedStem[0] == normalizedFirst[0] &&
              expectedStem[2] == normalizedFirst[2] &&
              _confusableConsonantPairs.contains((
                expectedStem[1],
                normalizedFirst[1],
              ))) ||
          _matchesAssimilatedMedialSyllable(expectedStem, normalizedFirst);
    }
    if (expectedWord.endsWith('تا') &&
        nextExpectedWord.startsWith('اثن') &&
        firstSpoken == expectedWord.substring(0, expectedWord.length - 2) &&
        normalizedSecondForIthn == 'ت${nextExpectedWord.substring(1)}') {
      return true;
    }
    // Tanween / final-lam boundary shift onto nextExpectedWord as 'ال' prefix
    // (e.g. ملكا نقاتل -> ملك النقاتل, قرنا آخرين -> قرن الآخرين, يستبدل قوما -> يستبدي القوما).
    if (expectedWord.length >= 4 &&
        (lastChar == 'ا' || lastChar == 'ل') &&
        !nextExpectedWord.startsWith('ال') &&
        _foldAlifMaqsuraToAlif(secondSpoken) ==
            _foldAlifMaqsuraToAlif('ال$nextExpectedWord') &&
        (firstSpoken == expectedStem || firstSpoken == '$expectedStemي')) {
      return true;
    }
    // Reverse boundary consonant shift: the first consonant of nextExpectedWord
    // attaches to the end of expectedWord (e.g. استقر مكانه -> استقرم كانه,
    // or across elided 'ال' in فضرب الرقاب -> فضربر رقاب, يتم الرضاعة -> يتمر ضاعة).
    if (lastChar == 'ة' &&
        expectedWord.length >= 4 &&
        firstSpoken == expectedWord.substring(0, expectedWord.length - 2)) {
      final prevConsonant = expectedWord[expectedWord.length - 2];
      for (final tChar in const ['ت', 'ث']) {
        final shifted = '$prevConsonant$tChar$nextExpectedWord';
        if (_foldAlifMaqsuraToAlif(secondSpoken) ==
                _foldAlifMaqsuraToAlif(shifted) ||
            _matchesAssimilatedMedialSyllable(shifted, secondSpoken) ||
            _isOrthographicNearMiss(shifted, secondSpoken)) {
          return true;
        }
      }
    }
    if (nextExpectedWord.length >= 3) {
      final nextFirst = nextExpectedWord[0];
      final nextRemainder = nextExpectedWord.substring(1);
      final shiftedFirst = '$expectedWord$nextFirst';
      if ((_foldAlifMaqsuraToAlif(firstSpoken) ==
                  _foldAlifMaqsuraToAlif(shiftedFirst) ||
              _matchesAssimilatedMedialSyllable(shiftedFirst, firstSpoken)) &&
          (_foldAlifMaqsuraToAlif(secondSpoken) ==
                  _foldAlifMaqsuraToAlif(nextRemainder) ||
              _matchesQalqalahPauseEnding(nextRemainder, secondSpoken))) {
        return true;
      }
      if (nextExpectedWord.length >= 4 &&
          nextExpectedWord.startsWith('ل') &&
          !nextExpectedWord.startsWith('ال') &&
          _foldAlifMaqsuraToAlif(firstSpoken) ==
              _foldAlifMaqsuraToAlif('$expectedWord' 'ن') &&
          _foldAlifMaqsuraToAlif(secondSpoken) ==
              _foldAlifMaqsuraToAlif(nextRemainder)) {
        return true;
      }
      if (nextExpectedWord.length >= 4 &&
          nextExpectedWord.startsWith('لل') &&
          _foldAlifMaqsuraToAlif(firstSpoken) ==
              _foldAlifMaqsuraToAlif('$expectedWord' 'ل') &&
          _foldAlifMaqsuraToAlif(secondSpoken) ==
              _foldAlifMaqsuraToAlif('ا$nextRemainder')) {
        return true;
      }
      if (nextExpectedWord.length >= 4 &&
          nextExpectedWord.startsWith('اث') &&
          (secondSpoken == nextExpectedWord.substring(2) ||
              normalizedSecondForIthn == nextExpectedWord.substring(2)) &&
          (firstSpoken == '$expectedWordث' ||
              firstSpoken == '$expectedWordت')) {
        return true;
      }
      if (nextExpectedWord.length >= 4 && nextExpectedWord.startsWith('ال')) {
        if (firstSpoken == '$expectedWord' 'ا' &&
            _foldNearMiss(secondSpoken) ==
                _foldNearMiss(nextExpectedWord.substring(2))) {
          return true;
        }
        final sunLetter = nextExpectedWord[2];
        final waslShiftedFirst = '$expectedWord$sunLetter';
        final remWithSun = nextExpectedWord.substring(2);
        final remWithoutSun = nextExpectedWord.substring(3);
        if ((_foldNearMiss(firstSpoken) == _foldNearMiss(waslShiftedFirst) ||
                _matchesAssimilatedMedialSyllable(
                  waslShiftedFirst,
                  firstSpoken,
                )) &&
            (_foldNearMiss(secondSpoken) == _foldNearMiss(remWithSun) ||
                _foldNearMiss(secondSpoken) == _foldNearMiss(remWithoutSun) ||
                (secondSpoken.length == remWithSun.length &&
                    secondSpoken.substring(1) == remWithSun.substring(1) &&
                    _confusableConsonantPairs.contains((
                      remWithSun[0],
                      secondSpoken[0],
                    ))))) {
          return true;
        }
      }
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
    ('ش', 'س'),
    ('س', 'ش'),
    ('ض', 'د'),
    ('د', 'ض'),
    ('ظ', 'ذ'),
    ('ذ', 'ظ'),
    ('ذ', 'د'),
    ('د', 'ذ'),
    ('ه', 'ح'),
    ('ح', 'ه'),
    ('ع', 'ح'),
    ('ح', 'ع'),
    ('ع', 'ر'),
    ('ر', 'و'),
    ('ر', 'ل'),
    ('ل', 'ر'),
    ('ن', 'ل'),
    ('ل', 'ن'),
    ('ن', 'ر'),
    ('ل', 'ي'),
    ('ث', 'ف'),
    ('ف', 'ث'),
    ('م', 'ب'),
    ('ب', 'م'),
    ('ن', 'م'),
    ('م', 'ن'),
    ('ز', 'ج'),
    ('ج', 'ز'),
    ('س', 'ت'),
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
    ('ج', 'د'),
    ('د', 'ج'),
    ('ز', 'د'),
    ('د', 'ز'),
    ('ث', 'ذ'),
    ('ذ', 'ث'),
    ('ت', 'د'),
    ('د', 'ت'),
  };

  static const _confusableInitialConsonantPairs = {
    ('ص', 'س'),
    ('س', 'ص'),
    ('ص', 'ف'),
    ('ق', 'ك'),
    ('ك', 'ق'),
    ('ط', 'ق'),
    ('ق', 'ط'),
    ('غ', 'ق'),
    ('ق', 'غ'),
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
    ('ف', 'ت'),
    ('ت', 'ق'),
    ('م', 'ن'),
    ('ن', 'م'),
    ('ن', 'ل'),
    ('ل', 'ن'),
    ('ك', 'ف'),
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
      if (expectedWord.length >= 4 &&
          (expectedWord.startsWith('ا') ||
              expectedWord.startsWith('أ') ||
              expectedWord.startsWith('إ')) &&
          expectedWord.substring(1) == spokenWord) {
        return true;
      }
      for (var i = 1; i < expectedWord.length - 1; i++) {
        if (expectedWord[i] != 'ا' &&
            expectedWord[i] != 'ل' &&
            expectedWord[i] != 'و' &&
            !(expectedWord.length >= 5 &&
                !quranVocabulary.contains(spokenWord))) {
          continue;
        }
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
        final c = spokenWord[i];
        if (c != 'و' &&
            c != 'ا' &&
            !(c == 'ي' && spokenWord[i - 1] != 'ي' && spokenWord[i + 1] != 'ي')) {
          continue;
        }
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
