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

  /// Recitation words preserving Arabic vowel diacritics (harakat).
  List<String> vocalizedWords(String text) => _vocalizedWords(text);

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
    var endsAtAyahBoundary = false;
    var verseWordsTotal = 0;
    var remainingInCurrentAyah = remaining;
    for (var verse = 0; verse < expectedAyahs.length; verse++) {
      final verseLen = _expectedRecitationWords(
        expectedAyahs[verse],
        expectedVerseKeys[verse],
      ).length;
      if (retained.length < verseWordsTotal + verseLen) {
        remainingInCurrentAyah = verseWordsTotal + verseLen - retained.length;
        break;
      }
      verseWordsTotal += verseLen;
      if (verseWordsTotal == retained.length) {
        endsAtAyahBoundary = true;
        if (verse + 1 < expectedAyahs.length) {
          remainingInCurrentAyah = _expectedRecitationWords(
            expectedAyahs[verse + 1],
            expectedVerseKeys[verse + 1],
          ).length;
        }
        break;
      }
    }
    int confirmationFor(int start) {
      if (endsAtAyahBoundary &&
          start >= 2 &&
          retained.length >= 2 &&
          _foldAlifMaqsuraToAlif(incoming[start - 2]) ==
              _foldAlifMaqsuraToAlif(retained[retained.length - 2]) &&
          _foldAlifMaqsuraToAlif(incoming[start - 1]) ==
              _foldAlifMaqsuraToAlif(retained.last)) {
        return 1;
      }
      if (remainingInCurrentAyah == 2 &&
          !endsAtAyahBoundary &&
          retained.isNotEmpty &&
          (start == 0 ||
              _foldNearMiss(incoming[start - 1]) ==
                  _foldNearMiss(retained.last))) {
        return 2;
      }
      return remaining < 3 ? remaining : 3;
    }
    // If the incoming window begins with an exact suffix of the retained
    // prefix, it is already anchored and must not skip past an immediate
    // wrong word after that suffix.
    var anchoredAtStart = false;
    final maxStartOverlap = retained.length < incoming.length
        ? retained.length
        : incoming.length;
    for (var overlap = maxStartOverlap; overlap >= 1; overlap--) {
      var exact = true;
      for (var i = 0; i < overlap; i++) {
        if (retained[retained.length - overlap + i] != incoming[i]) {
          exact = false;
          break;
        }
      }
      if (exact) {
        anchoredAtStart = true;
        break;
      }
    }
    for (var start = 0; start < incoming.length; start++) {
      if (anchoredAtStart && start > 0) break;
      final isClippedMaddBeforeFinalRefrain =
          start == 1 &&
          remainingInCurrentAyah == 2 &&
          retained.length >= 2 &&
          (retained.last == 'آلاء' ||
              (retained.last == 'ذو' &&
                  expectedSeq[retained.length].first == 'الجلال')) &&
          incoming.length >= 3 &&
          expectedSeq[retained.length].contains(incoming[1]) &&
          (expectedSeq[retained.length + 1].contains(incoming[2]) ||
              _foldNearMiss(
                expectedSeq[retained.length + 1].first,
              ).startsWith(_foldNearMiss(incoming[2])) ||
              (!quranVocabulary.contains(incoming[2]) &&
                  _isOrthographicNearMiss(
                    expectedSeq[retained.length + 1].first,
                    incoming[2],
                  )));
      if (!_repeatsRetainedSuffix(retained, incoming, start) &&
          !isClippedMaddBeforeFinalRefrain) {
        continue;
      }
      final confirmation = isClippedMaddBeforeFinalRefrain
          ? 2
          : confirmationFor(start);
      if (start == 1 && retained.length >= 2 && incoming.length >= 3) {
        var matchesEarlierInRetained = false;
        for (var j = 0; j + 1 < retained.length - 1; j++) {
          if (_foldNearMiss(retained[j]) == _foldNearMiss(incoming[0]) &&
              _foldNearMiss(retained[j + 1]) == _foldNearMiss(incoming[1])) {
            final laterMatchLen = retained.length - (j + 1) < incoming.length - 1
                ? retained.length - (j + 1)
                : incoming.length - 1;
            if (laterMatchLen >= 2) {
              var matchesLater = true;
              for (var k = 0; k < laterMatchLen; k++) {
                if (_foldNearMiss(incoming[1 + k]) !=
                    _foldNearMiss(retained[j + 1 + k])) {
                  matchesLater = false;
                  break;
                }
              }
              if (matchesLater) {
                var alsoMatchesCursor =
                    retained.length + laterMatchLen <= expectedSeq.length;
                if (alsoMatchesCursor) {
                  for (var k = 0; k < laterMatchLen; k++) {
                    if (!expectedSeq[retained.length + k].contains(
                      incoming[1 + k],
                    )) {
                      alsoMatchesCursor = false;
                      break;
                    }
                  }
                }
                if (!alsoMatchesCursor) {
                  matchesEarlierInRetained = true;
                  break;
                }
              }
            }
          }
        }
        if (matchesEarlierInRetained) continue;
      }
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
        if (normalized.length > retained.length &&
            expectedSeq[retained.length].contains(
              normalized[retained.length],
            ) &&
            isClippedMaddBeforeFinalRefrain) {
          return [...retained, expectedSeq[retained.length].first].join(' ');
        }
      }
      if (isClippedMaddBeforeFinalRefrain) {
        return [...retained, expectedSeq[retained.length].first].join(' ');
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
    final remainingExpected = expectedSeq.length - retained.length;
    var currentAyahStart = 0;
    var currentAyahEnd = 0;
    for (var verse = 0; verse < expectedAyahs.length; verse++) {
      final verseLen = _expectedRecitationWords(
        expectedAyahs[verse],
        expectedVerseKeys[verse],
      ).length;
      if (retained.length < currentAyahStart + verseLen) {
        currentAyahEnd = currentAyahStart + verseLen;
        break;
      }
      currentAyahStart += verseLen;
      currentAyahEnd = currentAyahStart;
    }
    final remainingInCurrentAyah = currentAyahEnd - retained.length;
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
            rawIncoming: _applyHarakahConflicts(
              _recitationWords(spokenText),
              _vocalizedWords(spokenText),
              expectedAyahs,
              expectedVerseKeys,
            ),
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
        if (matches &&
            allowWrittenOpenings &&
            overlap == 1 &&
            incoming.length >= 3 &&
            retained.length >= 2) {
          for (var j = 0; j + 1 < retained.length - 1; j++) {
            if (_foldNearMiss(retained[j]) == _foldNearMiss(incoming[0]) &&
                _foldNearMiss(retained[j + 1]) == _foldNearMiss(incoming[1])) {
              final laterMatchLen =
                  retained.length - (j + 1) < incoming.length - 1
                  ? retained.length - (j + 1)
                  : incoming.length - 1;
              if (laterMatchLen >= 2) {
                var matchesLater = true;
                for (var k = 0; k < laterMatchLen; k++) {
                  if (_foldNearMiss(incoming[1 + k]) !=
                      _foldNearMiss(retained[j + 1 + k])) {
                    matchesLater = false;
                    break;
                  }
                }
                if (matchesLater) {
                  var alsoMatchesCursor =
                      retained.length + laterMatchLen <= expectedSeq.length;
                  if (alsoMatchesCursor) {
                    for (var k = 0; k < laterMatchLen; k++) {
                      if (!expectedSeq[retained.length + k].contains(
                        incoming[1 + k],
                      )) {
                        alsoMatchesCursor = false;
                        break;
                      }
                    }
                  }
                  if (!alsoMatchesCursor) {
                    matches = false;
                    break;
                  }
                }
              }
            }
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
        if (matches &&
            allowWrittenOpenings &&
            overlap == 1 &&
            incoming.length >= 3 &&
            retained.length >= 2) {
          for (var j = 0; j + 1 < retained.length - 1; j++) {
            if (_foldNearMiss(retained[j]) == _foldNearMiss(incoming[0]) &&
                _foldNearMiss(retained[j + 1]) == _foldNearMiss(incoming[1])) {
              final laterMatchLen =
                  retained.length - (j + 1) < incoming.length - 1
                  ? retained.length - (j + 1)
                  : incoming.length - 1;
              if (laterMatchLen >= 2) {
                var matchesLaterRetained = true;
                for (var k = 0; k < laterMatchLen; k++) {
                  if (_foldNearMiss(incoming[1 + k]) !=
                      _foldNearMiss(retained[j + 1 + k])) {
                    matchesLaterRetained = false;
                    break;
                  }
                }
                if (matchesLaterRetained) {
                  var alsoMatchesCursor =
                      retained.length + laterMatchLen <= expectedSeq.length;
                  if (alsoMatchesCursor) {
                    for (var k = 0; k < laterMatchLen; k++) {
                      if (!expectedSeq[retained.length + k].contains(
                        incoming[1 + k],
                      )) {
                        alsoMatchesCursor = false;
                        break;
                      }
                    }
                  }
                  if (!alsoMatchesCursor) {
                    matches = false;
                    break;
                  }
                }
              }
            }
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
            final retainedBeforeOverlap = retained
                .take(retained.length - overlap)
                .toList();
            final normalizedWithSkippedPrefix =
                retainedBeforeOverlap.length >= skip
                ? _spokenWords(
                    [
                      ...retainedBeforeOverlap.take(
                        retainedBeforeOverlap.length - skip,
                      ),
                      ...incoming,
                    ].join(' '),
                    expectedAyahs,
                    expectedVerseKeys,
                    allowWrittenOpenings,
                  )
                : const <String>[];
            final matchesNormalizedBeforeOverlap =
                normalizedWithSkippedPrefix.length >= retained.length &&
                [
                  for (var i = 0; i < retained.length; i++)
                    normalizedWithSkippedPrefix[i] == retained[i],
                ].every((ok) => ok);
            final isClippedRefrainBoundarySkip =
                skip == 1 &&
                overlap >= 1 &&
                retained.length >= 2 &&
                retained.last == 'ربكما' &&
                retained[retained.length - 2] == 'آلاء' &&
                skipped.length > overlap &&
                retained.length < expectedSeq.length &&
                expectedSeq[retained.length].first == 'تكذبان';
            if (retainedBeforeOverlap.isNotEmpty &&
                !matchesNormalizedBeforeOverlap &&
                !isClippedRefrainBoundarySkip &&
                !_repeatsRetainedSuffix(
                  retainedBeforeOverlap,
                  incoming,
                  skip,
                )) {
              continue;
            }
            if (overlap == 1 &&
                skipped.length > 1 &&
                retained.length < expectedSeq.length &&
                !expectedSeq[retained.length].contains(skipped[1])) {
              final normalizedTail = _spokenWords(
                [...retained, ...skipped.skip(1)].join(' '),
                expectedAyahs,
                expectedVerseKeys,
                allowWrittenOpenings,
              );
              if (normalizedTail.length <= retained.length ||
                  !expectedSeq[retained.length].contains(
                    normalizedTail[retained.length],
                  )) {
                // Do not anchor on a single word after a wrong/skipped word unless
                // the word immediately following that anchor is the next expected word.
                continue;
              }
            }
            var matches = true;
          for (var i = 0; i < overlap; i++) {
            final rWord = retained[retained.length - overlap + i];
            final sWord = skipped[i];
            if (rWord != sWord &&
                !(overlap >= 2 &&
                    (_foldNearMiss(rWord) == _foldNearMiss(sWord) ||
                        _foldAlifMaqsuraToAlif(rWord) ==
                            _foldAlifMaqsuraToAlif(sWord) ||
                        (overlap >= 3 && rWord == 'هن' && sWord == 'هم') ||
                        (rWord.length >= 5 &&
                            !quranVocabulary.contains(sWord) &&
                            _isOrthographicNearMiss(rWord, sWord))))) {
              matches = false;
              break;
            }
          }
          if (matches) {
            var matchesEarlierInRetained = false;
            if (overlap == 1 && skipped.length >= 3 && retained.length >= 2) {
              for (var j = 0; j + 1 < retained.length - 1; j++) {
                if (_foldNearMiss(retained[j]) == _foldNearMiss(skipped[0]) &&
                    _foldNearMiss(retained[j + 1]) ==
                        _foldNearMiss(skipped[1])) {
                  final laterMatchLen =
                      retained.length - (j + 1) < skipped.length - 1
                      ? retained.length - (j + 1)
                      : skipped.length - 1;
                  if (laterMatchLen >= 2) {
                    var matchesLater = true;
                    for (var k = 0; k < laterMatchLen; k++) {
                      if (_foldNearMiss(skipped[1 + k]) !=
                          _foldNearMiss(retained[j + 1 + k])) {
                        matchesLater = false;
                        break;
                      }
                    }
                    if (matchesLater) {
                      var alsoMatchesCursor =
                          retained.length + laterMatchLen <= expectedSeq.length;
                      if (alsoMatchesCursor) {
                        for (var k = 0; k < laterMatchLen; k++) {
                          if (!expectedSeq[retained.length + k].contains(
                            skipped[1 + k],
                          )) {
                            alsoMatchesCursor = false;
                            break;
                          }
                        }
                      }
                      if (!alsoMatchesCursor) {
                        matchesEarlierInRetained = true;
                        break;
                      }
                    }
                  }
                }
              }
            }
            final isMidAyahAnchor =
                matchesEarlierInRetained ||
                (overlap <= 2 &&
                _isRepeatedAyahPrefixAnchor(
                  retainedLength: retained.length,
                  overlap: overlap,
                  expectedAyahs: expectedAyahs,
                  expectedVerseKeys: expectedVerseKeys,
                ));
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
      var matchesCursorExpected =
          retained.length + incoming.length <= expectedSeq.length;
      if (matchesCursorExpected) {
        for (var i = 0; i < incoming.length; i++) {
          if (!expectedSeq[retained.length + i].contains(incoming[i])) {
            matchesCursorExpected = false;
            break;
          }
        }
      }
      if (!matchesCursorExpected) {
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
    }
    if (allowWrittenOpenings && remainingExpected >= 2) {
      var endsAtAyahBoundary = false;
      var verseWordsTotal = 0;
      for (var verse = 0; verse < expectedAyahs.length; verse++) {
        verseWordsTotal += _expectedRecitationWords(
          expectedAyahs[verse],
          expectedVerseKeys[verse],
        ).length;
        if (verseWordsTotal >= retained.length) {
          endsAtAyahBoundary = verseWordsTotal == retained.length;
          break;
        }
      }
      int confirmationWordsFor(int start) {
        if (endsAtAyahBoundary &&
            start >= 2 &&
            retained.length >= 2 &&
            _foldAlifMaqsuraToAlif(incoming[start - 2]) ==
                _foldAlifMaqsuraToAlif(retained[retained.length - 2]) &&
            _foldAlifMaqsuraToAlif(incoming[start - 1]) ==
                _foldAlifMaqsuraToAlif(retained.last)) {
          return 1;
        }
        if (remainingInCurrentAyah == 2 &&
            start >= 1 &&
            retained.isNotEmpty &&
            _foldNearMiss(incoming[start - 1]) ==
                _foldNearMiss(retained.last)) {
          return 2;
        }
        return remainingExpected < 3 ? remainingExpected : 3;
      }
      var anchoredAtStart = false;
      final maxStartOverlap = retained.length < incoming.length
          ? retained.length
          : incoming.length;
      for (var overlap = maxStartOverlap; overlap >= 1; overlap--) {
        var exact = true;
        for (var i = 0; i < overlap; i++) {
          if (retained[retained.length - overlap + i] != incoming[i]) {
            exact = false;
            break;
          }
        }
        if (exact) {
          anchoredAtStart = true;
          break;
        }
      }
      if (!anchoredAtStart) {
        for (
          var start = 1;
          start < incoming.length;
          start++
        ) {
          final isClippedMaddBeforeFinalRefrain =
              start == 1 &&
              remainingInCurrentAyah == 2 &&
              retained.length >= 2 &&
              (retained.last == 'آلاء' ||
                  (retained.last == 'ذو' &&
                      expectedSeq[retained.length].first == 'الجلال')) &&
              incoming.length >= 3 &&
              expectedSeq[retained.length].contains(incoming[1]) &&
              (expectedSeq[retained.length + 1].contains(incoming[2]) ||
                  _foldNearMiss(
                    expectedSeq[retained.length + 1].first,
                  ).startsWith(_foldNearMiss(incoming[2])) ||
                  (!quranVocabulary.contains(incoming[2]) &&
                      _isOrthographicNearMiss(
                        expectedSeq[retained.length + 1].first,
                        incoming[2],
                      )));
          if (!_repeatsRetainedSuffix(retained, incoming, start) &&
              !isClippedMaddBeforeFinalRefrain) {
            continue;
          }
          if (start == 1 && retained.length >= 2 && incoming.length >= 3) {
            var matchesEarlierInRetained = false;
            for (var j = 0; j + 1 < retained.length - 1; j++) {
              if (_foldNearMiss(retained[j]) == _foldNearMiss(incoming[0]) &&
                  _foldNearMiss(retained[j + 1]) ==
                      _foldNearMiss(incoming[1])) {
                final laterMatchLen =
                    retained.length - (j + 1) < incoming.length - 1
                    ? retained.length - (j + 1)
                    : incoming.length - 1;
                if (laterMatchLen >= 2) {
                  var matchesLater = true;
                  for (var k = 0; k < laterMatchLen; k++) {
                    if (_foldNearMiss(incoming[1 + k]) !=
                        _foldNearMiss(retained[j + 1 + k])) {
                      matchesLater = false;
                      break;
                    }
                  }
                  if (matchesLater) {
                    var alsoMatchesCursor =
                        retained.length + laterMatchLen <= expectedSeq.length;
                    if (alsoMatchesCursor) {
                      for (var k = 0; k < laterMatchLen; k++) {
                        if (!expectedSeq[retained.length + k].contains(
                          incoming[1 + k],
                        )) {
                          alsoMatchesCursor = false;
                          break;
                        }
                      }
                    }
                    if (!alsoMatchesCursor) {
                      matchesEarlierInRetained = true;
                      break;
                    }
                  }
                }
              }
            }
            if (matchesEarlierInRetained) continue;
          }
          final confirmationWords = isClippedMaddBeforeFinalRefrain
              ? 2
              : confirmationWordsFor(start);
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
          if (isClippedMaddBeforeFinalRefrain) {
            return [...retained, expectedSeq[retained.length].first].join(' ');
          }
        }
      }
    }
    if (allowWrittenOpenings &&
        (remainingExpected == 1 || remainingInCurrentAyah == 1) &&
        retained.isNotEmpty) {
      bool repeatsEarlierInRetained(int cursor) {
        final target = expectedSeq[retained.length].first;
        final prev = retained.last;
        for (var j = 0; j + 1 < retained.length - 1; j++) {
          if (_foldNearMiss(retained[j]) == _foldNearMiss(prev) &&
              _foldNearMiss(retained[j + 1]) == _foldNearMiss(target)) {
            return true;
          }
        }
        return false;
      }

      for (var cursor = 1; cursor < incoming.length; cursor++) {
        final singleWordAnchor =
            cursor == 1 &&
            _isRepeatedAyahPrefixAnchor(
              retainedLength: retained.length,
              overlap: 1,
              expectedAyahs: expectedAyahs,
              expectedVerseKeys: expectedVerseKeys,
            );
        final requiresLongerAnchor =
            repeatsEarlierInRetained(cursor) && cursor < incoming.length - 1;
        final isClippedPenultimateBeforeFinalWord =
            cursor == 1 &&
            retained.length >= 2 &&
            ((retained.last.length >= 4 &&
                    incoming[0].length >= 2 &&
                    incoming[0].length < retained.last.length &&
                    retained.last.endsWith(incoming[0]) &&
                    (!quranVocabulary.contains(incoming[0]) ||
                        (retained.last == 'ربكما' &&
                            expectedSeq[retained.length].first == 'تكذبان'))) ||
                (retained.last == 'ربكما' &&
                    expectedSeq[retained.length].first == 'تكذبان' &&
                    const {
                      'كما',
                      'ما',
                      'بما',
                      'كم',
                      'ربكم',
                      'ربهم',
                      'وربكما',
                      'بربكما',
                      'إربكما',
                      'أربكما',
                    }.contains(incoming[0])));
        final normalizedWithPrefix = cursor <= retained.length
            ? _spokenWords(
                [
                  ...retained.take(retained.length - cursor),
                  ...incoming.take(cursor),
                ].join(' '),
                expectedAyahs,
                expectedVerseKeys,
                allowWrittenOpenings,
              )
            : const <String>[];
        final repeatsNormalizedSuffix =
            normalizedWithPrefix.length == retained.length &&
            [
              for (var i = 0; i < retained.length; i++)
                normalizedWithPrefix[i] == retained[i],
            ].every((ok) => ok);
        if (!singleWordAnchor &&
            (!requiresLongerAnchor ||
                isClippedPenultimateBeforeFinalWord ||
                repeatsNormalizedSuffix ||
                (cursor >= 2 &&
                    retained.length >= 2 &&
                    _foldNearMiss(incoming[cursor - 2]) ==
                        _foldNearMiss(retained[retained.length - 2]))) &&
            (isClippedPenultimateBeforeFinalWord ||
                repeatsNormalizedSuffix ||
                _foldNearMiss(incoming[cursor - 1]) ==
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
            (isClippedPenultimateBeforeFinalWord ||
                repeatsNormalizedSuffix ||
                _repeatsRetainedSuffix(retained, incoming, cursor))) {
          if (expectedSeq[retained.length].contains(incoming[cursor])) {
            return [
              ...retained,
              ...incoming.skip(cursor),
            ].join(' ');
          }
          if (cursor == incoming.length - 1) {
            final normalized = _spokenWords(
              [...retained, incoming[cursor]].join(' '),
              expectedAyahs,
              expectedVerseKeys,
              allowWrittenOpenings,
            );
            if (normalized.length > retained.length &&
                expectedSeq[retained.length].contains(
                  normalized[retained.length],
                )) {
              return normalized.join(' ');
            }
          }
        }
      }
      if (incoming.length == 1 &&
          retained.length >= 3 &&
          retained.last == 'ربكما' &&
          expectedSeq[retained.length].first == 'تكذبان') {
        final normalizedSingle = _spokenWords(
          [...retained, incoming.first].join(' '),
          expectedAyahs,
          expectedVerseKeys,
          allowWrittenOpenings,
        );
        if (normalizedSingle.length > retained.length &&
            expectedSeq[retained.length].contains(
              normalizedSingle[retained.length],
            )) {
          return normalizedSingle.join(' ');
        }
      }
    }
    // When the incoming window begins with the final expected word of the
    // current ayah followed by an extra/wrong word and has no overlap with the
    // retained prefix, do not auto-complete the ayah on that unanchored token.
    if (allowWrittenOpenings &&
        retained.length > currentAyahStart &&
        incoming.length == 2 &&
        remainingInCurrentAyah >= 2 &&
        expectedSeq[retained.length].contains(incoming.first) &&
        !expectedSeq[retained.length + 1].contains(incoming[1])) {
      final contextual = _spokenWords(
        [...retained, ...incoming].join(' '),
        expectedAyahs,
        expectedVerseKeys,
        allowWrittenOpenings,
      );
      if (contextual.length >= retained.length + 2 &&
          expectedSeq[retained.length].contains(contextual[retained.length]) &&
          expectedSeq[retained.length + 1].contains(
            contextual[retained.length + 1],
          )) {
        return contextual.join(' ');
      }
      if (remainingInCurrentAyah == 2 &&
          expectedSeq[retained.length].first.length >= 4 &&
          !quranVocabulary.contains(incoming[1]) &&
          (expectedSeq[retained.length + 1].first.startsWith(incoming[1]) ||
              _isOrthographicNearMiss(
                expectedSeq[retained.length + 1].first,
                incoming[1],
              ) ||
              (expectedSeq[retained.length].first == 'ربكما' &&
                  expectedSeq[retained.length + 1].first == 'تكذبان'))) {
        return [...retained, incoming.first, 'زئد', incoming[1]].join(' ');
      }
      return [...retained, 'زئد', ...incoming].join(' ');
    }
    if (allowWrittenOpenings &&
        retained.isNotEmpty &&
        incoming.length >= 2 &&
        remainingInCurrentAyah == 1 &&
        expectedSeq[retained.length].contains(incoming.first) &&
        (retained.length + 1 >= expectedSeq.length ||
            !expectedSeq[retained.length + 1].contains(incoming[1]))) {
      return [...retained, 'زئد', ...incoming].join(' ');
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
    final spoken = _applyHarakahConflicts(
      _recitationWords(spokenText),
      _vocalizedWords(spokenText),
      expectedAyahs,
      expectedVerseKeys,
    );
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
    final rawSpoken = trustedPrefix
        ? _recitationWords(text)
        : _applyHarakahConflicts(
            _recitationWords(text),
            _vocalizedWords(text),
            expectedAyahs,
            keys,
          );
    if (!allowWrittenOpenings || keys == null) return rawSpoken;
    final spoken = <String>[];
    for (var i = 0; i < rawSpoken.length; i++) {
      if (allowAsrCorrections &&
          rawSpoken[i] == 'رضاءوا' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'على' &&
          rawSpoken[i + 2] == 'سفر') {
        spoken.addAll(['مرضى', 'أو']);
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'أولا' || rawSpoken[i] == 'أولى') &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'مستم' &&
          (rawSpoken[i + 2] == 'النساء' || rawSpoken[i + 2] == 'النسى')) {
        spoken.addAll(['أو', 'لامستم']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ما' &&
          i + 2 < rawSpoken.length &&
          _foldNearMiss(rawSpoken[i + 1]) == 'انفت' &&
          (rawSpoken[i + 2] == 'يمموا' ||
              rawSpoken[i + 2] == 'يمنوا' ||
              rawSpoken[i + 2] == 'يمن')) {
        spoken.addAll(['ماء', 'فتيمموا']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'نخلم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'انطليها') {
        spoken.addAll(['النخل', 'من', 'طلعها']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فبعثوا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أحدكم') {
        spoken.add('فابعثوا');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'أودما' || rawSpoken[i] == 'أودمن') &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'مسفوحا' || rawSpoken[i + 1] == 'مسكوحا')) {
        spoken.addAll(['أو', 'دما']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'كلوا' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بالذين' &&
          rawSpoken[i + 2] == 'اتبعوه') {
        spoken.addAll(['قلوب', 'الذين']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'لا' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'منوب' &&
          rawSpoken[i + 2] == 'ما') {
        spoken.addAll(['أنهم', 'آمنوا', 'بما']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أو' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'نادلوا' &&
          rawSpoken[i + 2] == 'لها') {
        spoken.addAll(['يشهدون', 'أن']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'حولينك' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أم' &&
          rawSpoken[i + 2] == 'ليل') {
        spoken.addAll(['حولين', 'كاملين']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'لأينك' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أمنين') {
        spoken.addAll(['حولين', 'كاملين']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وللسان' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'ذواعة' &&
          rawSpoken[i + 2] == 'منكم') {
        spoken.addAll(['اثنان', 'ذوا', 'عدل']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'إلا' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'لذواعدل' &&
          rawSpoken[i + 2] == 'منكم') {
        spoken.addAll(['اثنان', 'ذوا', 'عدل']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أمن' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'موسلوا') {
        spoken.addAll(['المن', 'والسلوى']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'تعدينكم' || rawSpoken[i] == 'وعدينكم') &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'العداوة') {
        spoken.addAll(['يوقع', 'بينكم']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'الوفاقاق' &&
          i > 0 &&
          rawSpoken[i - 1] == 'فشدوا') {
        spoken.add('الوثاق');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أمر' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'قومك' &&
          spoken.isNotEmpty &&
          (spoken.last == 'ذوة' ||
              spoken.last == 'وذكوة' ||
              spoken.last == 'بقوة')) {
        spoken[spoken.length - 1] = 'بقوة';
        spoken.add('وأمر');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'يمن' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'له' &&
          ((i > 0 && rawSpoken[i - 1] == 'أن') ||
              (i + 2 < rawSpoken.length &&
                  (rawSpoken[i + 2] == 'فليملل' ||
                      rawSpoken[i + 2] == 'فليمن' ||
                      rawSpoken[i + 2] == 'وفليمن' ||
                      rawSpoken[i + 2] == 'وفليم')))) {
        spoken.addAll(['يمل', 'هو']);
        if (i + 3 < rawSpoken.length &&
            rawSpoken[i + 2] == 'وفليم' &&
            rawSpoken[i + 3] == 'للوليه') {
          spoken.addAll(['فليملل', 'وليه']);
          i += 3;
          continue;
        }
        if (i + 3 < rawSpoken.length &&
            (rawSpoken[i + 2] == 'فليمن' || rawSpoken[i + 2] == 'وفليمن') &&
            (rawSpoken[i + 3] == 'الولي' || rawSpoken[i + 3] == 'الوليه')) {
          spoken.addAll(['فليملل', 'وليه']);
          i += 3;
          continue;
        }
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'فليم' || rawSpoken[i] == 'وفليم') &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'للوليه') {
        spoken.addAll(['فليملل', 'وليه']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'فليمن' || rawSpoken[i] == 'وفليمن') &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'الولي' || rawSpoken[i + 1] == 'الوليه')) {
        spoken.addAll(['فليملل', 'وليه']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ليرسل' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'في' &&
          rawSpoken[i + 2] == 'المدائن') {
        spoken.addAll(['يردوك', 'فأرسل']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فيأمرون' &&
          i > 0 &&
          rawSpoken[i - 1] == 'إبراهيم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بالقسط') {
        spoken.addAll(['ويقتلون', 'الذين', 'يأمرون']);
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'أنه' || rawSpoken[i] == 'أنهم') &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'من' &&
          rawSpoken[i + 2] == 'يعمل' &&
          (i == 0 || (i == 1 && rawSpoken[0] == 'فإن'))) {
        spoken.addAll(['كتب', 'ربكم', 'على', 'نفسه', 'الرحمة', 'أنه']);
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'فمن' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'نكث' &&
          rawSpoken[i + 2] == 'فإنما') {
        spoken.addAll(['يد', 'الله', 'فوق', 'أيديهم', 'فمن']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'الأير' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'واحم' &&
          rawSpoken[i + 2] == 'كل') {
        spoken.addAll(['الألواح', 'من']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'الأيواح' &&
          i > 0 &&
          rawSpoken[i - 1] == 'في') {
        spoken.add('الألواح');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'فله' || rawSpoken[i] == 'وجه') &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'النثل' &&
          (rawSpoken[i + 2] == 'ثامى' || rawSpoken[i + 2] == 'ثا')) {
        if (rawSpoken[i + 2] == 'ثامى') {
          spoken.addAll(['فلهن', 'ثلثا', 'ما']);
        } else {
          spoken.addAll(['فلهن', 'ثلثا']);
        }
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فدنفلها' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'النسو') {
        spoken.addAll(['فلها', 'النصف']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'آبائب' || rawSpoken[i] == 'أبائب') &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'علتهم' ||
              rawSpoken[i + 1] == 'عولتهن' ||
              rawSpoken[i + 1] == 'عولتهم' ||
              rawSpoken[i + 1] == 'عوتهن')) {
        spoken.addAll(['آباء', 'بعولتهن']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أبنائب' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'عون' || rawSpoken[i + 1] == 'عولتهن')) {
        spoken.addAll(['أبناء', 'بعولتهن']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أو' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'اتى' &&
          rawSpoken[i + 2] == 'بعين') {
        spoken.addAll(['أو', 'التابعين']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أو' &&
          i + 2 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'اطف' || rawSpoken[i + 1] == 'اضطف') &&
          rawSpoken[i + 2] == 'للذين') {
        spoken.addAll(['أو', 'الطفل', 'الذين']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أو' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'اضطفني' &&
          rawSpoken[i + 2] == 'الذين') {
        spoken.addAll(['أو', 'الطفل', 'الذين']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'منا' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'نحوهن' &&
          rawSpoken[i + 2] == 'فرضة') {
        spoken.addAll(['متاعا', 'بلوغهن', 'أجلهن']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'أن' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'كتر' &&
          rawSpoken[i + 2] == 'الأرض') {
        spoken.addAll(['ومن', 'آياته', 'أنك', 'ترى']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'من' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'آياته' &&
          (rawSpoken[i + 2] == 'أنك' || rawSpoken[i + 2] == 'أنكثر')) {
        if (rawSpoken[i + 2] == 'أنكثر') {
          spoken.addAll(['ومن', 'آياته', 'أنك', 'ترى']);
          i += 2;
        } else {
          spoken.add('ومن');
        }
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'العداوات' || rawSpoken[i] == 'العداوى') &&
          ((spoken.isNotEmpty &&
                  (spoken.last == 'بينكم' ||
                      spoken.last == 'تعدينكم' ||
                      spoken.last == 'وعدينكم')) ||
              (i + 1 < rawSpoken.length &&
                  (rawSpoken[i + 1] == 'والبغضاء' ||
                      rawSpoken[i + 1] == 'البغضار')))) {
        spoken.add('العداوة');
        if (i + 1 < rawSpoken.length && rawSpoken[i + 1] == 'البغضار') {
          spoken.add('والبغضاء');
          i++;
        }
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'تعدينكم' || rawSpoken[i] == 'وعدينكم') &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'العداوة' ||
              rawSpoken[i + 1] == 'العداوات' ||
              rawSpoken[i + 1] == 'العداوى')) {
        if (spoken.isNotEmpty && spoken.last == 'أن') {
          spoken.addAll(['يوقع', 'بينكم']);
        } else {
          spoken.add('بينكم');
        }
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'تنتنت' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'انتمون') {
        spoken.addAll(['أنتم', 'منتهون']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وأتوبهم' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'تشادمت' ||
              rawSpoken[i + 1] == 'تشابها' ||
              rawSpoken[i + 1] == 'تشابهاء')) {
        spoken.addAll(['وأتوا', 'به', 'متشابها']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'هادى' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'الذا' &&
          rawSpoken[i + 2] == 'الذي') {
        spoken.addAll(['هذا', 'الذي']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'رزقاقا') {
        spoken.add('رزقا');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'إنا' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'هو' &&
          rawSpoken[i + 2] == 'بالوالدين') {
        spoken.addAll(['إياه', 'وبالوالدين']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'إنا' || rawSpoken[i] == 'لا') &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'يبلغن') {
        spoken.addAll(['إما', 'يبلغن']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أثب' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'ولا') {
        spoken.add('أف');
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'الإفلى') {
        spoken.addAll(['ألف', 'لام']);
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'لا' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'تأتيكم' || rawSpoken[i + 1] == 'تأتيه')) {
        spoken.addAll(['والأرض', 'لا']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'السماوات' &&
          i == rawSpoken.length - 1 &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'ثقلت' &&
          spoken.last == 'في') {
        spoken.addAll(['السماوات', 'والأرض']);
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'الناس' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'والحج') {
        spoken.add('للناس');
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'أهحجمي') {
        spoken.addAll(['أأعجمي', 'وعربي']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'خالدين' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'والخالدات' &&
          rawSpoken[i + 2] == 'والصادقين') {
        spoken.addAll(['والقانتين', 'والقانتات']);
        i++;
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'واستصدقات') {
        spoken.add('والمتصدقات');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'رجبا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بالغيب') {
        spoken.add('رجما');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'يقولون' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'سبعة') {
        spoken.add('ويقولون');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وفى' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'منهم' &&
          rawSpoken[i + 2] == 'كلبهم') {
        spoken.addAll(['وثامنهم', 'كلبهم']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ويلهم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'كلبهم') {
        spoken.add('وثامنهم');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'على' || rawSpoken[i] == 'وما') &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'أبنائهن' ||
              rawSpoken[i + 1] == 'أبنى' ||
              rawSpoken[i + 1] == 'إخوانهن' ||
              rawSpoken[i + 1] == 'إخوى' ||
              rawSpoken[i + 1] == 'أبناء' ||
              rawSpoken[i + 1] == 'نسائهن' ||
              (rawSpoken[i + 1] == 'ما' &&
                  i + 2 < rawSpoken.length &&
                  rawSpoken[i + 2] == 'ملكت'))) {
        spoken.add('ولا');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'آخذوا' || rawSpoken[i] == 'وآخذوا') &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'الله') {
        if (i == 0 && rawSpoken[i] == 'وآخذوا') {
          spoken.addAll(['ولو', 'يؤاخذ']);
        } else {
          spoken.add('يؤاخذ');
        }
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'سبماك' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'سبوا') {
        spoken.addAll(['بما', 'كسبوا']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ناروهن' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'لتضيقوا') {
        spoken.add('تضاروهن');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ويلقوا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'عليهن') {
        spoken.add('لتضيقوا');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وتمر' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بينكم') {
        spoken.add('وأتمروا');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'ليقترفتموها' || rawSpoken[i] == 'لاقترفتموها')) {
        spoken.add('اقترفتموها');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ولا' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'تعبلوهن' || rawSpoken[i + 1] == 'تعبلوه')) {
        if (spoken.isEmpty || spoken.last != 'كرها') {
          spoken.add('كرها');
        }
        spoken.addAll(['ولا', 'تعضلوهن']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'النساء' &&
          i == rawSpoken.length - 1 &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'أن' &&
          spoken.last == 'ترثوا') {
        spoken.addAll(['النساء', 'كرها']);
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'بئو' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'شيئا' &&
          rawSpoken[i + 2] == 'ويجعل') {
        spoken.add('تكرهوا');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'نفع' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'ساء' &&
          rawSpoken[i + 2] == 'تكرهوا') {
        spoken.addAll(['فعسى', 'أن', 'تكرهوا']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فانتكره' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'شيئا') {
        spoken.add('تكرهوا');
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'جاءتر') {
        spoken.add('جاءت');
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'رسل' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'ربنا' &&
          rawSpoken[i + 2] == 'بالحق') {
        spoken.addAll(['جاءت', 'رسل']);
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'ابتغان') {
        spoken.add('ابتغاء');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أو' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أحلية') {
        spoken.addAll(['ابتغاء', 'حلية']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'جدد' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'مثله') {
        spoken.add('زبد');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'من' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'من' &&
          rawSpoken[i + 2] == 'بعد') {
        spoken.addAll(['منا', 'بعد']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'تضعع') {
        spoken.add('تضع');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أو' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'سطمات' &&
          rawSpoken[i + 2] == 'تعمون') {
        spoken.addAll(['أوسط', 'ما', 'تطعمون']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ويما' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'تطعمون') {
        spoken.add('ما');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'عقتهم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'الأيمان') {
        spoken.add('عقدتم');
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'إطعام' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'عشرة') {
        spoken.addAll(['فكفارته', 'إطعام']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فصال' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'العنثراظ') {
        spoken.addAll(['فصالا', 'عن', 'تراض']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'انعم' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'عن' &&
          rawSpoken[i + 2] == 'تراض') {
        spoken.addAll(['فصالا', 'عن', 'تراض']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'زمر' &&
          spoken.isNotEmpty &&
          spoken.last == 'جهنم') {
        spoken.add('زمرا');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'بعضكم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'منه') {
        spoken.addAll(['بعضكم', 'من', 'بعض']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          (rawSpoken[i] == 'الذين' || rawSpoken[i] == 'لين') &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'هاجروا') {
        spoken.add('فالذين');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'بآتهم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'ولأدخلنهم') {
        spoken.add('سيئاتهم');
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'الثوابرين') {
        spoken.add('الثواب');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وروح' &&
          i == rawSpoken.length - 1 &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'إلى' &&
          spoken.last == 'مريم') {
        spoken.addAll(['وروح', 'منه']);
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'فآمنوا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بالله' &&
          keys.contains('4:171')) {
        spoken.addAll(['منه', 'فآمنوا']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وآثة' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إنته' &&
          rawSpoken[i + 2] == 'خيرا') {
        spoken.add('ثلاثة');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'إنته' || rawSpoken[i] == 'وته') &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'خيرا') {
        spoken.add('انتهوا');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'وللرسول' || rawSpoken[i] == 'والرسول') &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'ولللقربى' ||
              rawSpoken[i + 1] == 'وللللقربى')) {
        if (i == 0) {
          spoken.add('فلله');
        }
        spoken.addAll(['وللرسول', 'ولذي', 'القربى']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'دون' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'دونة') {
        spoken.add('دولة');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'لما' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أنزل' &&
          rawSpoken[i + 2] == 'الله') {
        spoken.add('ما');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أنزله' &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'مثل' &&
          spoken.last == 'ما') {
        spoken.addAll(['أنزل', 'الله']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'اليمم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'تجزون') {
        spoken.add('اليوم');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'والحر' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بالحر') {
        spoken.add('الحر');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'نشيئا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إلا') {
        spoken.add('شيئا');
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'من' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'يخافا') {
        spoken.add('أن');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فأول' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إكرام' &&
          rawSpoken[i + 2] == 'ظالمون') {
        spoken.addAll(['فأولئك', 'هم', 'الظالمون']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'كبير' &&
          spoken.isNotEmpty &&
          spoken.last == 'قال') {
        spoken.add('كبيرهم');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'حتىي' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'ائذن') {
        spoken.addAll(['حتى', 'يأذن']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أبي' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أبي') {
        spoken.add('أبي');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'كسب' &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'نفس' &&
          spoken.last == 'بما') {
        spoken.add('كسبت');
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'قول' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'الله' &&
          rawSpoken[i + 2] == 'شركاء') {
        spoken.addAll(['وجعلوا', 'لله']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'منن' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'عمي' &&
          rawSpoken[i + 2] == 'حكم') {
        spoken.addAll(['من', 'النعم', 'يحكم']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'مننع' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'ميحكم') {
        spoken.addAll(['من', 'النعم', 'يحكم']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فعميحكم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'به') {
        spoken.addAll(['النعم', 'يحكم']);
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'ذواعدنم' || rawSpoken[i] == 'ذواعدين')) {
        spoken.addAll(['ذوا', 'عدل']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ذواعد' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'لم') {
        spoken.addAll(['ذوا', 'عدل']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أمبيز' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'وعدل') {
        spoken.addAll(['به', 'ذوا', 'عدل']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'كنهدي' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'انبالغ') {
        spoken.addAll(['منكم', 'هديا', 'بالغ']);
        i++;
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'لينبالغ') {
        spoken.addAll(['هديا', 'بالغ']);
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'ليحفتي' || rawSpoken[i] == 'لكنتي') &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'تجري') {
        spoken.add('التي');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'نقيم' &&
          spoken.isNotEmpty &&
          spoken.last == 'عشر') {
        spoken.add('نقيبا');
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'تفربعد') {
        spoken.addAll(['كفر', 'بعد']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'تفر' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بعد') {
        spoken.add('كفر');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وأم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'ساء') {
        spoken.add('النساء');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'تدريل' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'عل') {
        spoken.addAll(['تدري', 'لعل']);
        i++;
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'بعثلنا') {
        spoken.addAll(['ابعث', 'لنا']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ملك' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'النقاتل' || rawSpoken[i + 1] == 'النقى')) {
        if (rawSpoken[i + 1] == 'النقاتل') {
          spoken.addAll(['ملكا', 'نقاتل']);
          i++;
        } else {
          spoken.add('ملكا');
        }
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وعد' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'سها' || rawSpoken[i + 1] == 'سهاوة')) {
        spoken.add('وعدسها');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وظلها' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'قال') {
        spoken.add('وبصلها');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أوأدنا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بالذي') {
        spoken.addAll(['هو', 'أدنى']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'إذ' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بقوا' &&
          rawSpoken[i + 2] == 'مصرا') {
        spoken.addAll(['اهبطوا', 'مصرا']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'سألتموا') {
        spoken.add('سألتم');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وقدا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إها') {
        spoken.add('وقثائها');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فإذا' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إها' &&
          rawSpoken[i + 2] == 'وقومها') {
        spoken.add('وقثائها');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'علمهم' &&
          spoken.isNotEmpty &&
          spoken.last == 'وضربت') {
        spoken.add('عليهم');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'الظلة' &&
          spoken.isNotEmpty &&
          spoken.last == 'عليهم') {
        spoken.add('الذلة');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وعصو' &&
          spoken.isNotEmpty &&
          spoken.last == 'بما') {
        spoken.addAll(['عصوا', 'وكانوا', 'يعتدون']);
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'تقول' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'فيها') {
        spoken.add('المتقون');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'تنهار' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'من') {
        spoken.add('أنهار');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'يتغيرطعنه' || rawSpoken[i] == 'يرطعنه')) {
        spoken.addAll(['يتغير', 'طعمه']);
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'وسقوماء') {
        spoken.addAll(['وسقوا', 'ماء']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'نسر' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'فإذا') {
        spoken.add('نسك');
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'فتعبالعمرة') {
        spoken.addAll(['تمتع', 'بالعمرة']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'الربال' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'يقومون' &&
          rawSpoken.last == 'يقوم') {
        spoken.addAll(['الربا', 'لا', 'يقومون']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'الربال' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أيقومون' &&
          rawSpoken[i + 2] == 'إلا') {
        spoken.addAll(['الربا', 'لا', 'يقومون']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'الربال' &&
          i == rawSpoken.length - 1 &&
          spoken.isNotEmpty &&
          spoken.last == 'يأكلون') {
        spoken.add('الربا');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'المسر' &&
          spoken.isNotEmpty &&
          spoken.last == 'من') {
        spoken.add('المس');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فأول' &&
          i == rawSpoken.length - 1 &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'ومن' &&
          spoken.last == 'عاد') {
        spoken.addAll(['فأولئك', 'أصحاب', 'النار', 'هم', 'فيها', 'خالدون']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أنتنتهون' &&
          spoken.isNotEmpty &&
          (spoken.last == 'فعل' || spoken.last == 'فهل')) {
        spoken[spoken.length - 1] = 'فهل';
        spoken.addAll(['أنتم', 'منتهون']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أن' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'تنتنت' &&
          rawSpoken[i + 2] == 'انتمون') {
        spoken.addAll(['أنتم', 'منتهون']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'منصرين' &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'إنه' &&
          spoken.last == 'كان') {
        spoken.add('منصورا');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'رسلطانا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'فلا') {
        spoken.add('سلطانا');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فأوبني' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إخوانهن') {
        spoken.addAll(['أو', 'بني']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'اتابعين' &&
          spoken.isNotEmpty &&
          spoken.last == 'أو') {
        spoken.add('التابعين');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ووضطف' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'للذين') {
        spoken.addAll(['أو', 'الطفل', 'الذين']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'مرات' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'النساء') {
        spoken.add('عورات');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ولأولي' &&
          i + 3 < rawSpoken.length &&
          rawSpoken[i + 1] == 'الإذبة' &&
          rawSpoken[i + 2] == 'من' &&
          rawSpoken[i + 3] == 'العجال') {
        spoken.addAll(['أولي', 'الإربة', 'من', 'الرجال']);
        i += 3;
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'نذر' &&
              i + 2 < rawSpoken.length &&
              rawSpoken[i + 1] == 'عن' &&
              rawSpoken[i + 2] == 'أيها')) {
        spoken.add('جميعا');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'بلىه' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'جميعا') {
        spoken.add('الله');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'خطئا' || rawSpoken[i] == 'الخطئن')) {
        spoken.add('خطأ');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وأربة' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'مؤمنة') {
        spoken.add('رقبة');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ثم' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'سلمة' &&
          rawSpoken[i + 2] == 'إلى') {
        spoken.add('مسلمة');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'واهله' || rawSpoken[i] == 'وأهله') &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'إلا' || rawSpoken[i + 1] == 'وتحرير')) {
        spoken.add('أهله');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فبعدوا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إلكم') {
        spoken.addAll(['عدو', 'لكم']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'فانقوم' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'بينكم') {
        spoken.addAll(['من', 'قوم']);
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ادفصيام' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'شهرين') {
        spoken.addAll(['يجد', 'فصيام']);
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'لا' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'يقومون' &&
          rawSpoken[i + 2] == 'إلا' &&
          keys.contains('2:275')) {
        spoken.addAll(['الربا', 'لا']);
        continue;
      }
      if (allowAsrCorrections &&
          i == 0 &&
          rawSpoken[i] == 'الملائكة' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'باسطوا' || rawSpoken[i + 1] == 'باسطو')) {
        spoken.addAll(['والملائكة', 'باسطو']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'القتل' &&
          spoken.isNotEmpty &&
          spoken.last == 'في' &&
          keys.contains('2:178')) {
        spoken.add('القتلى');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وحر' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'مربا' || rawSpoken[i + 1] == 'مرجبا')) {
        spoken.addAll(['وحرم', 'الربا']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'الأخر' || rawSpoken[i] == 'الأخي') &&
          spoken.isNotEmpty &&
          (spoken.last == 'وبنات' || spoken.last == 'وآتوا')) {
        if (spoken.last == 'وآتوا') {
          spoken[spoken.length - 1] = 'وبنات';
        }
        spoken.add('الأخ');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وبناتوا' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'الأخت') {
        spoken.add('وبنات');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'مطة' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'مخلقة') {
        spoken.add('مضغة');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'والمؤلقة' || rawSpoken[i] == 'مؤلقة')) {
        spoken.add('مخلقة');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وأنبت' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'من' &&
          rawSpoken[i + 2] == 'كل') {
        spoken.add('وأنبتت');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'ثم' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'عك' &&
          rawSpoken[i + 2] == 'وليأخذوا') {
        spoken.add('معك');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'والتأت' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'طائفة') {
        spoken.add('ولتأت');
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'تقصلون') {
        spoken.add('تغفلون');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'مرضاء' &&
          i + 1 < rawSpoken.length &&
          (rawSpoken[i + 1] == 'تضعوا' || rawSpoken[i + 1] == 'تضعون')) {
        spoken.addAll(['مرضى', 'أن', 'تضعوا']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'يكون' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أرجلين') {
        spoken.addAll(['يكونا', 'رجلين']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'يكون' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أرج' &&
          (rawSpoken[i + 2] == 'لين' || rawSpoken[i + 2] == 'ليل')) {
        spoken.addAll(['يكونا', 'رجلين']);
        i += 2;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'يأبش' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'هداء') {
        spoken.addAll(['يأب', 'الشهداء']);
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'دعون' &&
          spoken.isNotEmpty &&
          spoken.last == 'ما') {
        spoken.add('دعوا');
        continue;
      }
      if (allowAsrCorrections &&
          (rawSpoken[i] == 'واختابوا' || rawSpoken[i] == 'وكذابوا') &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إلا') {
        spoken.add('ترتابوا');
        continue;
      }
      if (allowAsrCorrections && rawSpoken[i] == 'للعولةهن') {
        spoken.add('لبعولتهن');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'زين' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'تمن') {
        spoken.add('زينتهن');
        i++;
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'منه' &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'ما' &&
          spoken.last == 'ظهر') {
        spoken.add('منها');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'أيه' ||
          (allowAsrCorrections &&
              rawSpoken[i] == 'أيها' &&
              i + 1 < rawSpoken.length &&
              rawSpoken[i + 1] == 'المؤمنون')) {
        spoken.add('أيه');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'وتنظر' &&
          i + 2 < rawSpoken.length &&
          rawSpoken[i + 1] == 'إلى' &&
          rawSpoken[i + 2] == 'الله') {
        spoken.add('وتوبوا');
        continue;
      }
      if (allowAsrCorrections &&
          rawSpoken[i] == 'المؤمنين' &&
          spoken.length >= 2 &&
          spoken[spoken.length - 2] == 'وما' &&
          spoken.last == 'كان' &&
          i + 1 < rawSpoken.length &&
          rawSpoken[i + 1] == 'أن') {
        spoken.add('لمؤمن');
        continue;
      }
      if (allowAsrCorrections &&
          keys.any((key) => key.startsWith('18:'))) {
        if ((rawSpoken[i] == 'رحما' || rawSpoken[i] == 'كرحمة') &&
            spoken.isNotEmpty &&
            spoken.last == 'لدنك') {
          spoken.add('رحمة');
          continue;
        }
        if (rawSpoken[i] == 'إثقاموا' ||
            (rawSpoken[i] == 'فإذ' &&
                i + 1 < rawSpoken.length &&
                rawSpoken[i + 1] == 'قاموا')) {
          if (rawSpoken[i] == 'إثقاموا') {
            spoken.addAll(['إذ', 'قاموا']);
          } else {
            spoken.add('إذ');
          }
          continue;
        }
        if ((rawSpoken[i] == 'للذا' || rawSpoken[i] == 'لمب') &&
            i + 2 < rawSpoken.length &&
            rawSpoken[i + 1] == 'ومن' &&
            (rawSpoken[i + 2] == 'دونه' || rawSpoken[i + 2] == 'دوني')) {
          spoken.addAll(['لن', 'ندعو', 'من', 'دونه']);
          i += 2;
          continue;
        }
        if (rawSpoken[i] == 'لنبوم' &&
            i + 2 < rawSpoken.length &&
            rawSpoken[i + 1] == 'ان' &&
            (rawSpoken[i + 2] == 'دوني' || rawSpoken[i + 2] == 'دونه')) {
          spoken.addAll(['لن', 'ندعو', 'من', 'دونه']);
          i += 2;
          continue;
        }
        if (rawSpoken[i] == 'ندع' &&
            spoken.isNotEmpty &&
            spoken.last == 'لن' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'من') {
          spoken.add('ندعو');
          continue;
        }
        if (rawSpoken[i] == 'آلهة' &&
            spoken.length >= 2 &&
            spoken[spoken.length - 2] == 'من' &&
            spoken.last == 'دونه' &&
            keys.contains('18:14') &&
            (i + 1 < rawSpoken.length &&
                (rawSpoken[i + 1] == 'لقد' ||
                    rawSpoken[i + 1] == 'وقد' ||
                    rawSpoken[i + 1] == 'ووقلنا'))) {
          spoken.add('إلها');
          continue;
        }
        if (rawSpoken[i] == 'وقد' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'قلنا') {
          spoken.add('لقد');
          continue;
        }
        if (rawSpoken[i] == 'ووقلنا' &&
            i + 1 < rawSpoken.length &&
            (rawSpoken[i + 1] == 'إذا' || rawSpoken[i + 1] == 'فإذا')) {
          spoken.addAll(['لقد', 'قلنا']);
          continue;
        }
        if ((rawSpoken[i] == 'إذا' || rawSpoken[i] == 'فإذا') &&
            i + 1 < rawSpoken.length &&
            (rawSpoken[i + 1] == 'انشططى' ||
                rawSpoken[i + 1] == 'شططى' ||
                rawSpoken[i + 1] == 'شطر' ||
                rawSpoken[i + 1] == 'شططا')) {
          spoken.addAll(['إذا', 'شططا']);
          i++;
          continue;
        }
        if ((rawSpoken[i] == 'شطر' || rawSpoken[i] == 'شططى') &&
            spoken.isNotEmpty &&
            spoken.last == 'إذا') {
          spoken.add('شططا');
          continue;
        }
        if ((rawSpoken[i] == 'أئقوا' ||
                rawSpoken[i] == 'ئقوا' ||
                rawSpoken[i] == 'أم') &&
            i + 1 < rawSpoken.length &&
            (rawSpoken[i + 1] == 'منتخذوا' || rawSpoken[i + 1] == 'ننتخذوا')) {
          if (spoken.isEmpty || spoken.last != 'هؤلاء') {
            spoken.add('هؤلاء');
          }
          spoken.addAll(['قومنا', 'اتخذوا']);
          i++;
          continue;
        }
        if (rawSpoken[i] == 'قوم' &&
            i + 1 < rawSpoken.length &&
            (rawSpoken[i + 1] == 'نتق' || rawSpoken[i + 1] == 'نتخذوا')) {
          spoken.addAll(['قومنا', 'اتخذوا']);
          i++;
          continue;
        }
        if ((rawSpoken[i] == 'هالهة' || rawSpoken[i] == 'ذلهة') &&
            spoken.isNotEmpty &&
            spoken.last == 'دونه') {
          spoken.add('آلهة');
          continue;
        }
        if (rawSpoken[i] == 'بسطان' &&
            i + 1 < rawSpoken.length &&
            (rawSpoken[i + 1] == 'بين' || rawSpoken[i + 1] == 'بي')) {
          spoken.add('بسلطان');
          continue;
        }
        if (rawSpoken[i] == 'بي' &&
            spoken.isNotEmpty &&
            spoken.last == 'بسلطان') {
          spoken.add('بين');
          continue;
        }
        if (const {'أرضم', 'أرظم', 'أرغم', 'فأرضم'}.contains(rawSpoken[i]) &&
            ((spoken.isNotEmpty && spoken.last == 'فمن') ||
                (i + 1 < rawSpoken.length && rawSpoken[i + 1] == 'ممن'))) {
          if (rawSpoken[i] == 'فأرضم' &&
              (spoken.isEmpty || spoken.last != 'فمن')) {
            spoken.add('فمن');
          }
          spoken.add('أظلم');
          continue;
        }
        if (rawSpoken[i] == 'كذبة' &&
            spoken.length >= 2 &&
            spoken[spoken.length - 2] == 'على' &&
            spoken.last == 'الله') {
          spoken.add('كذبا');
          continue;
        }
        if (rawSpoken[i] == 'وإذا' &&
            i + 1 < rawSpoken.length &&
            (rawSpoken[i + 1] == 'اعتزلتموهم' ||
                rawSpoken[i + 1] == 'تزلتموهم' ||
                rawSpoken[i + 1] == 'عتزلتموهم')) {
          spoken.addAll(['وإذ', 'اعتزلتموهم']);
          i++;
          continue;
        }
        if (rawSpoken[i] == 'وإذ' &&
            i + 1 < rawSpoken.length &&
            (rawSpoken[i + 1] == 'عتزلتموهم' ||
                rawSpoken[i + 1] == 'تزلتموهم')) {
          spoken.addAll(['وإذ', 'اعتزلتموهم']);
          i++;
          continue;
        }
        if (const {
          'وليممرشدة',
          'وليممرسدة',
          'وليممرسدا',
          'وليممرشدا',
        }.contains(rawSpoken[i])) {
          spoken.addAll(['وليا', 'مرشدا']);
          continue;
        }
        if ((rawSpoken[i] == 'وليم' || rawSpoken[i] == 'وليا') &&
            i + 1 < rawSpoken.length &&
            const {
              'مرشدة',
              'مرسدة',
              'مرسدا',
              'مرسلة',
              'مرشدا',
            }.contains(rawSpoken[i + 1])) {
          spoken.addAll(['وليا', 'مرشدا']);
          i++;
          continue;
        }
        if (const {'غيقاضا', 'غيقاظا', 'عقاظا', 'أيقاظ'}.contains(
              rawSpoken[i],
            ) &&
            ((spoken.isNotEmpty && spoken.last == 'وتحسبهم') ||
                (i + 1 < rawSpoken.length && rawSpoken[i + 1] == 'وهم'))) {
          spoken.add('أيقاظا');
          continue;
        }
        if ((rawSpoken[i] == 'لقوم' || rawSpoken[i] == 'رقوم') &&
            spoken.isNotEmpty &&
            spoken.last == 'وهم') {
          spoken.add('رقود');
          continue;
        }
        if ((rawSpoken[i] == 'باصط' || rawSpoken[i] == 'بعصطة') &&
            ((spoken.isNotEmpty && spoken.last == 'وكلبهم') ||
                (i + 1 < rawSpoken.length &&
                    rawSpoken[i + 1].startsWith('ذر')))) {
          spoken.add('باسط');
          continue;
        }
        if (rawSpoken[i] == 'ذر' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'عيه') {
          spoken.add('ذراعيه');
          i++;
          continue;
        }
        if (const {'ذراعه', 'ذرعيه', 'ذراعية'}.contains(rawSpoken[i]) &&
            ((spoken.isNotEmpty && spoken.last == 'باسط') ||
                (i + 1 < rawSpoken.length &&
                    rawSpoken[i + 1].startsWith('بالوصي')))) {
          spoken.add('ذراعيه');
          continue;
        }
        if ((rawSpoken[i] == 'بالوصير' || rawSpoken[i] == 'بالوصية') &&
            ((spoken.isNotEmpty && spoken.last == 'ذراعيه') ||
                (i > 0 && rawSpoken[i - 1].startsWith('ذر')))) {
          spoken.add('بالوصيد');
          continue;
        }
        if (rawSpoken[i] == 'لي' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'تساءلوا') {
          spoken.add('ليتساءلوا');
          i++;
          continue;
        }
        if (const {
              'لتساءلوب',
              'فيتساءلوا',
              'فساءلوا',
              'ليتساءلون',
              'لتساءلوا',
            }.contains(rawSpoken[i]) &&
            ((spoken.isNotEmpty && spoken.last == 'بعثناهم') ||
                (i + 1 < rawSpoken.length && rawSpoken[i + 1] == 'بينهم'))) {
          spoken.add('ليتساءلوا');
          continue;
        }
        if ((rawSpoken[i] == 'ضعب' || rawSpoken[i] == 'ضعض') &&
            spoken.isNotEmpty &&
            spoken.last == 'أو' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'يوم') {
          spoken.add('بعض');
          continue;
        }
        if (rawSpoken[i] == 'ضعبية' &&
            spoken.isNotEmpty &&
            spoken.last == 'أو') {
          spoken.addAll(['بعض', 'يوم']);
          continue;
        }
        if (const {'فبعثوا', 'تبعثوا', 'فاعتوا'}.contains(rawSpoken[i]) &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'أحدكم') {
          spoken.add('فابعثوا');
          continue;
        }
        if (const {
              'بيرقكم',
              'بورقكم',
              'يورقكم',
              'يولقكم',
              'ورقكم',
            }.contains(rawSpoken[i]) &&
            ((spoken.isNotEmpty && spoken.last == 'أحدكم') ||
                (i + 1 < rawSpoken.length && rawSpoken[i + 1] == 'هذه'))) {
          spoken.add('بورقكم');
          continue;
        }
        if (rawSpoken[i] == 'أسقى' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'طعاما') {
          spoken.add('أزكى');
          continue;
        }
        if (rawSpoken[i] == 'أسقاط' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'عاما') {
          spoken.addAll(['أزكى', 'طعاما']);
          i++;
          continue;
        }
        if (rawSpoken[i] == 'أسقاطع' &&
            spoken.isNotEmpty &&
            spoken.last == 'أيها') {
          spoken.addAll(['أزكى', 'طعاما']);
          continue;
        }
        if ((rawSpoken[i] == 'وليأتكم' || rawSpoken[i] == 'ليأتكم') &&
            i + 1 < rawSpoken.length &&
            const {'برصق', 'برسط', 'برسق', 'برزق'}.contains(rawSpoken[i + 1])) {
          spoken.addAll(['فليأتكم', 'برزق']);
          i++;
          continue;
        }
        if (const {'برصق', 'برسط', 'برسق'}.contains(rawSpoken[i]) &&
            ((spoken.isNotEmpty && spoken.last == 'فليأتكم') ||
                (i + 1 < rawSpoken.length && rawSpoken[i + 1] == 'منه'))) {
          spoken.add('برزق');
          continue;
        }
        if ((rawSpoken[i] == 'وليترى' || rawSpoken[i] == 'ولترى') &&
            i + 2 < rawSpoken.length &&
            rawSpoken[i + 1] == 'الطفو' &&
            rawSpoken[i + 2] == 'لا') {
          spoken.addAll(['وليتلطف', 'ولا']);
          i += 2;
          continue;
        }
        if (const {
          'وليتوطف',
          'وليترضف',
          'فليتوطف',
          'وليتلاطف',
          'وليتلقف',
        }.contains(rawSpoken[i])) {
          spoken.add('وليتلطف');
          continue;
        }
        if (rawSpoken[i] == 'يشعر' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'النبكم') {
          spoken.addAll(['يشعرن', 'بكم']);
          i++;
          continue;
        }
        if (rawSpoken[i] == 'يسعرن' &&
            i + 1 < rawSpoken.length &&
            rawSpoken[i + 1] == 'بكم') {
          spoken.add('يشعرن');
          continue;
        }
      }
      spoken.add(rawSpoken[i]);
    }
    if (allowAsrCorrections) {
      if (spoken.length == 4 &&
          spoken[0] == 'إلى' &&
          spoken[1] == 'رب' &&
          spoken[2] == 'موسى' &&
          spoken[3] == 'وهارون') {
        spoken.removeAt(0);
      } else if (spoken.length == 7 &&
          spoken[0] == 'من' &&
          (spoken[1] == 'إفكهم' || spoken[1] == 'إفكههم') &&
          spoken[2] == 'ليقولون' &&
          spoken[3] == 'ولد' &&
          spoken[4] == 'الله' &&
          spoken[5] == 'وإنهم' &&
          spoken[6] == 'لكاذبون') {
        spoken.removeRange(0, 3);
      } else if (spoken.length == 5 &&
          spoken[0] == 'في' &&
          spoken[1] == 'إذ' &&
          spoken[2] == 'هم' &&
          spoken[3] == 'عليها' &&
          spoken[4] == 'قعود') {
        spoken.removeAt(0);
      } else if (spoken.length >= 8 &&
          spoken[0] == 'وما' &&
          spoken[1] == 'كانوا' &&
          spoken[2] == 'يعبدون' &&
          spoken[3] == 'من' &&
          spoken[4] == 'دون' &&
          spoken[5] == 'الله' &&
          spoken[6] == 'فاهدوهم') {
        spoken.removeRange(0, 3);
      } else if (spoken.length >= 6 &&
          spoken[0] == 'واعبدون' &&
          spoken[1] == 'من' &&
          spoken[2] == 'دون' &&
          spoken[3] == 'الله' &&
          spoken[4] == 'فاهدوهم') {
        spoken.removeAt(0);
      }
    }
    final expanded = <String>[];
    var offset = 0;
    for (var ayah = 0; ayah < expectedAyahs.length; ayah++) {
      if (offset >= spoken.length) break;
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
        if (keys[ayah].startsWith('55:')) {
          final hasLeft =
              word > 0 &&
              expanded.isNotEmpty &&
              expected[word - 1].contains(expanded.last);
          final hasRight =
              nextExpectedSet != null &&
              offset + 1 < spoken.length &&
              (nextExpectedSet.contains(spoken[offset + 1]) ||
                  _foldNearMiss(spoken[offset + 1]) ==
                      _foldNearMiss(nextExpectedSet.first));
          if (expected[word].first == 'فبأي' &&
              hasRight &&
              const {
                'بأي',
                'أبي',
                'فبي',
                'فباي',
                'وبأي',
                'فبأيي',
                'فأي',
                'في',
                'أي',
                'فبأ',
              }.contains(spoken[offset])) {
            expanded.add('فبأي');
            offset++;
            word++;
            continue;
          }
          if (expected[word].first == 'آلاء' &&
              (hasLeft || hasRight) &&
              const {
                'ألا',
                'إلا',
                'آلا',
                'علاء',
                'ولاء',
                'الألاء',
                'الآلاء',
                'آلائي',
                'ألاء',
                'إلاء',
                'بلاء',
                'بألاء',
                'بأاء',
                'بماء',
                'بلى',
                'بما',
                'وما',
                'لا',
                'آل',
                'آلى',
                'آلاءر',
                'آلاءرة',
              }.contains(spoken[offset])) {
            expanded.add('آلاء');
            offset++;
            word++;
            continue;
          }
          if (expected[word].first == 'ربكما' &&
              (hasLeft || hasRight) &&
              const {
                'وربكما',
                'بربكما',
                'لربكما',
                'أربكما',
                'إربكما',
                'ربكم',
                'ربهم',
                'ربكنا',
                'ربك',
                'ربه',
                'رمعه',
                'كما',
                'بما',
              }.contains(spoken[offset])) {
            expanded.add('ربكما');
            offset++;
            word++;
            continue;
          }
          if (expected[word].first == 'ربكما' &&
              (hasLeft ||
                  (offset + 2 < spoken.length &&
                      nextExpectedSet != null &&
                      nextExpectedSet.contains(spoken[offset + 2]))) &&
              offset + 1 < spoken.length &&
              (spoken[offset] == 'رب' || spoken[offset] == 'ربي') &&
              (spoken[offset + 1] == 'كما' || spoken[offset + 1] == 'كم')) {
            expanded.add('ربكما');
            offset += 2;
            word++;
            continue;
          }
          if (expected[word].first == 'تكذبان' &&
              hasLeft &&
              (const {
                    'تكذبون',
                    'يكذبان',
                    'تتكذبان',
                    'اتكذبان',
                    'أتكذبان',
                    'وتكذبان',
                    'فبتكذبان',
                    'تكذباني',
                    'تكذبا',
                    'تكذب',
                    'كذبان',
                    'تكذبن',
                    'تكابرون',
                    'تكابون',
                    'تكاب',
                    'تكرون',
                    'تكبرون',
                    'تكرمون',
                    'ترجبون',
                    'تقتب',
                    'تبغي',
                    'ذبان',
                    'الذبان',
                    'تبان',
                  }.contains(spoken[offset]) ||
                  (!quranVocabulary.contains(spoken[offset]) &&
                      _isOrthographicNearMiss('تكذبان', spoken[offset])))) {
            expanded.add('تكذبان');
            offset++;
            word++;
            continue;
          }
          if (expected[word].first == 'ذو' &&
              (hasLeft || hasRight) &&
              const {
                'ذل',
                'ذلب',
                'ذرب',
                'لذو',
                'كذو',
                'لكذو',
                'بوذو',
                'ذا',
                'ذي',
              }.contains(spoken[offset])) {
            expanded.add('ذو');
            offset++;
            word++;
            continue;
          }
          if (expected[word].first == 'ذو' &&
              word + 1 < expected.length &&
              expected[word + 1].first == 'الجلال' &&
              const {
                'ذوالجلال',
                'ذلجلال',
                'ذوالجلالي',
                'لذوالجلال',
                'كذوالجلال',
                'لكذوالجلال',
              }.contains(spoken[offset])) {
            expanded.addAll(['ذو', 'الجلال']);
            offset++;
            word += 2;
            continue;
          }
          if (expected[word].first == 'والإكرام' &&
              hasLeft &&
              const {
                'الإكرام',
                'والإكرا',
                'والإكر',
                'ولإكرام',
                'والأكرام',
              }.contains(spoken[offset])) {
            expanded.add('والإكرام');
            offset++;
            word++;
            continue;
          }
          if (keys[ayah] == '55:33') {
            if (expected[word].first == 'استطعتم' &&
                (hasLeft || hasRight) &&
                const {
                  'أطعتم',
                  'سطعتم',
                  'أعتم',
                  'تطعتم',
                  'استطعت',
                  'استطعم',
                }.contains(spoken[offset])) {
              expanded.add('استطعتم');
              offset++;
              word++;
              continue;
            }
            if (expected[word].first == 'أن' &&
                word + 1 < expected.length &&
                expected[word + 1].first == 'تنفذوا' &&
                (hasLeft ||
                    (offset + 1 < spoken.length &&
                        (spoken[offset + 1] == 'تنفذوا' ||
                            spoken[offset + 1] == 'تنفذون' ||
                            spoken[offset + 1] == 'من'))) &&
                const {'لن', 'إن', 'ألا', 'فأن', 'وأن'}.contains(
                  spoken[offset],
                )) {
              expanded.add('أن');
              offset++;
              word++;
              continue;
            }
            if (expected[word].first == 'أن' &&
                word + 1 < expected.length &&
                expected[word + 1].first == 'تنفذوا' &&
                (hasLeft ||
                    (offset + 1 < spoken.length &&
                        spoken[offset + 1] == 'من')) &&
                const {
                  'فانفذوا',
                  'فأنفذوا',
                  'أنتنفذوا',
                  'لنتنفذوا',
                  'تنفذوا',
                  'تنفذون',
                }.contains(spoken[offset])) {
              expanded.addAll(['أن', 'تنفذوا']);
              offset++;
              word += 2;
              continue;
            }
            if (expected[word].first == 'تنفذوا' &&
                (hasLeft || hasRight) &&
                const {
                  'تنفذون',
                  'فانفذوا',
                  'فأنفذوا',
                  'أنفذوا',
                  'ينفذوا',
                  'ينفذون',
                  'تأخذوا',
                  'تنفذ',
                  'تنفذوا',
                  'فنفذوا',
                  'انفذوا',
                }.contains(spoken[offset])) {
              expanded.add('تنفذوا');
              offset++;
              word++;
              continue;
            }
            if (expected[word].first == 'من' &&
                (hasLeft || hasRight) &&
                const {'ومن', 'فمن', 'بمن', 'عمن', 'إن'}.contains(
                  spoken[offset],
                )) {
              expanded.add('من');
              offset++;
              word++;
              continue;
            }
            if (expected[word].first == 'أقطار' &&
                (hasLeft || hasRight) &&
                const {
                  'أقطر',
                  'الأقطار',
                  'قطار',
                  'أقتار',
                  'وطار',
                  'أقدر',
                  'أقدار',
                  'اقطار',
                }.contains(spoken[offset])) {
              expanded.add('أقطار');
              offset++;
              word++;
              continue;
            }
            if (expected[word].first == 'السماوات' &&
                (hasLeft || hasRight) &&
                const {
                  'والسماوات',
                  'السماء',
                  'السماو',
                  'سماوات',
                  'وآوات',
                  'السموات',
                  'والسموات',
                  'السماواتي',
                  'بالسماوات',
                }.contains(spoken[offset])) {
              expanded.add('السماوات');
              offset++;
              word++;
              continue;
            }
            if (expected[word].first == 'والأرض' &&
                (hasLeft || hasRight) &&
                const {
                  'الأرض',
                  'أرض',
                  'والأرضي',
                  'بلأرض',
                  'فالأرض',
                }.contains(spoken[offset])) {
              expanded.add('والأرض');
              offset++;
              word++;
              continue;
            }
            if (expected[word].first == 'فانفذوا' &&
                (hasLeft || hasRight) &&
                const {
                  'فأنفذوا',
                  'فنفذوا',
                  'انفذوا',
                  'فانفذون',
                  'تنفذوا',
                  'تنفذون',
                  'وانفذوا',
                  'فانفذ',
                }.contains(spoken[offset])) {
              expanded.add('فانفذوا');
              offset++;
              word++;
              continue;
            }
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
        if (offset + 1 < spoken.length &&
            ((offset + 2 < spoken.length &&
                    nextExpectedSet != null &&
                    nextExpectedSet.contains(spoken[offset + 2])) ||
                (offset + 2 == spoken.length &&
                    word >= 2 &&
                    expanded.length >= 2 &&
                    expected[word - 1].contains(expanded.last) &&
                    expected[word - 2].contains(
                      expanded[expanded.length - 2],
                    ))) &&
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
                (expected[word].first == 'ما' &&
                    expected[word + 1].first.length >= 5 &&
                    expected[word + 1].first.startsWith('اقتتل') &&
                    (spoken[offset] ==
                            'م${expected[word + 1].first.substring(1)}' ||
                        spoken[offset] == 'مقتتلة' ||
                        spoken[offset] == 'مقتتل')) ||
                (expected[word].first == 'بالعشي' &&
                    expected[word + 1].first == 'الصافنات' &&
                    spoken[offset] == 'بالعشياد') ||
                (expected[word].first == 'به' &&
                    expected[word + 1].first == 'ولا' &&
                    _foldNearMiss(spoken[offset]) == 'باولا') ||
                (expected[word].first == 'يتغير' &&
                    expected[word + 1].first == 'طعمه' &&
                    spoken[offset] == 'يتغيرطعنه') ||
                (expected[word].first == 'إن' &&
                    expected[word + 1].first == 'لم' &&
                    (_foldNearMiss(spoken[offset]) == 'الام' ||
                        _foldNearMiss(spoken[offset]) == 'الم')) ||
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
                    spoken[offset] == 'جناحانيكم') ||
                (expected[word].first == 'الظن' &&
                    expected[word + 1].first == 'إثم' &&
                    _foldNearMiss(spoken[offset]) == 'الظنيث') ||
                (expected[word].first == 'يغتب' &&
                    expected[word + 1].first == 'بعضكم' &&
                    (spoken[offset] == 'يرتبعضكم' ||
                        spoken[offset] == 'يغتبعضكم')) ||
                (expected[word].first == 'ندع' &&
                    expected[word + 1].first == 'أبناءنا' &&
                    _foldNearMiss(spoken[offset]) == 'ونعوبنانا') ||
                (expected[word].first == 'النكاح' &&
                    expected[word + 1].first == 'حتى' &&
                    spoken[offset] == 'مكاححتا') ||
                (expected[word].first == 'مرضى' &&
                    expected[word + 1].first == 'أو' &&
                    spoken[offset] == 'رضاءوا') ||
                (expected[word].first == 'شرعة' &&
                    expected[word + 1].first == 'ومنهاجا' &&
                    _foldNearMiss(spoken[offset]) == 'شرعهومنهاجا') ||
                (expected[word].first == 'من' &&
                    expected[word + 1].first == 'ذكر' &&
                    spoken[offset] == 'مذكر') ||
                (expected[word].first == 'المسخر' &&
                    expected[word + 1].first == 'بين' &&
                    (spoken[offset] == 'المسخربينا' ||
                        spoken[offset] == 'المسخربين')) ||
                (expected[word].first == 'أو' &&
                    expected[word + 1].first == 'دما' &&
                    (spoken[offset] == 'أودما' || spoken[offset] == 'أودمن')) ||
                (expected[word].first == 'كي' &&
                    expected[word + 1].first == 'لا' &&
                    (spoken[offset] == 'كين' ||
                        spoken[offset] == 'كيلا' ||
                        spoken[offset] == 'لكيلا' ||
                        spoken[offset] == 'وإيلكينا')) ||
                (expected[word].first == 'أو' &&
                    expected[word + 1].first == 'دين' &&
                    (_foldNearMiss(spoken[offset]) == 'اودين' ||
                        _foldNearMiss(spoken[offset]) == 'اوديني')) ||
                (expected[word].first == 'وأن' &&
                    expected[word + 1].first == 'تصبروا' &&
                    _foldNearMiss(spoken[offset]) == 'وانتصبروا') ||
                (expected[word].first == 'ذو' &&
                    expected[word + 1].first == 'انتقام' &&
                    spoken[offset] == 'منتقام') ||
                (expected[word].first == 'ليذوق' &&
                    expected[word + 1].first == 'وبال' &&
                    spoken[offset] == 'ليذوقابا') ||
                (expected[word].first == 'الغار' &&
                    expected[word + 1].first == 'إذ' &&
                    _foldNearMiss(spoken[offset]) == 'الغالاذ') ||
                (expected[word].first == 'ابعث' &&
                    expected[word + 1].first == 'لنا' &&
                    spoken[offset] == 'بعثلنا') ||
                (expected[word].first == 'نصف' &&
                    expected[word + 1].first == 'ما' &&
                    spoken[offset] == 'نصقما') ||
                (expected[word].first == 'كلوا' &&
                    expected[word + 1].first == 'من' &&
                    spoken[offset] == 'وأوم') ||
                (expected[word].first == 'أنتم' &&
                    expected[word + 1].first == 'منتهون' &&
                    spoken[offset] == 'أنتنتهون') ||
                (expected[word].first == 'اعلموا' &&
                    expected[word + 1].first == 'أن' &&
                    keys[ayah] == '5:98' &&
                    spoken[offset] == 'علم') ||
                (expected[word].first == 'وصى' &&
                    expected[word + 1].first == 'به' &&
                    spoken[offset] == 'وصابه') ||
                (expected[word].first == 'منا' &&
                    expected[word + 1].first == 'بعد' &&
                    spoken[offset] == 'مننبعد') ||
                (expected[word].first == 'بمصر' &&
                    expected[word + 1].first == 'بيوتا' &&
                    spoken[offset] == 'بمصرهوت') ||
                (expected[word].first == 'قبلة' &&
                    expected[word + 1].first == 'وأقيموا' &&
                    spoken[offset] == 'وأبلة') ||
                (expected[word].first == 'أليم' &&
                    expected[word + 1].first == 'بما' &&
                    spoken[offset] == 'أليما') ||
                (expected[word].first == 'ترى' &&
                    expected[word + 1].first == 'الأرض' &&
                    spoken[offset] == 'الأرض' &&
                    word > 0 &&
                    expanded.isNotEmpty &&
                    expanded.last == 'أنك') ||
                (expected[word].first == 'نعم' &&
                    expected[word + 1].first == 'ما' &&
                    (spoken[offset] == 'نعما' || spoken[offset] == 'نعمما')))) {
          // Imla'i spelling joins words the mushaf writes apart (فيما).
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset++;
          word += 2;
          continue;
        }
        if (word + 2 < expected.length &&
            offset + 2 < spoken.length &&
            ((expected[word].first == 'اثنان' &&
                    expected[word + 1].first == 'ذوا' &&
                    expected[word + 2].first == 'عدل' &&
                    spoken[offset] == 'اثنى' &&
                    spoken[offset + 1] == 'لذواعدل') ||
                (expected[word].first == 'أنتم' &&
                    expected[word + 1].first == 'منتهون' &&
                    spoken[offset] == 'أن' &&
                    spoken[offset + 1] == 'تنتنت' &&
                    spoken[offset + 2] == 'انتمون'))) {
          if (expected[word].first == 'اثنان') {
            expanded.addAll(['اثنان', 'ذوا', 'عدل']);
            offset += 2;
            word += 3;
            continue;
          }
          expanded.addAll(['أنتم', 'منتهون']);
          offset += 3;
          word += 2;
          continue;
        }
        if (word + 2 < expected.length &&
            offset + 1 < spoken.length &&
            ((expected[word].first == 'علم' &&
                    expected[word + 1].first == 'كل' &&
                    expected[word + 2].first == 'أناس' &&
                    spoken[offset] == 'علمكم' &&
                    _foldNearMiss(spoken[offset + 1]) == 'نوناس') ||
                (expected[word].first == 'وأتوا' &&
                    expected[word + 1].first == 'به' &&
                    expected[word + 2].first == 'متشابها' &&
                    _foldNearMiss(spoken[offset]) == 'واتوبهم' &&
                    (spoken[offset + 1] == 'تشابها' ||
                        _foldNearMiss(spoken[offset + 1]) == 'تشابها')) ||
                (expected[word].first == 'ما' &&
                    expected[word + 1].first == 'الله' &&
                    expected[word + 2].first == 'مبديه' &&
                    spoken[offset] == 'مرضاه' &&
                    spoken[offset + 1] == 'مبديه') ||
                (expected[word].first == 'أوسط' &&
                    expected[word + 1].first == 'ما' &&
                    expected[word + 2].first == 'تطعمون' &&
                    spoken[offset] == 'سطمات' &&
                    spoken[offset + 1] == 'تعمون') ||
                (expected[word].first == 'فإن' &&
                    expected[word + 1].first == 'أحسرتم' &&
                    expected[word + 2].first == 'فما')) ||
            (word + 2 < expected.length &&
                offset + 1 < spoken.length &&
                expected[word].first == 'بلغوا' &&
                expected[word + 1].first == 'النكاح' &&
                expected[word + 2].first == 'فإن' &&
                spoken[offset] == 'بلغنك' &&
                spoken[offset + 1] == 'أحف')) {
          expanded.addAll([
            expected[word].first,
            expected[word + 1].first,
            expected[word + 2].first,
          ]);
          offset += 2;
          word += 3;
          continue;
        }
        if (word + 2 < expected.length &&
            offset + 1 < spoken.length &&
            expected[word].first == 'ما' &&
            expected[word + 1].first == 'اقتتل' &&
            expected[word + 2].first == 'الذين' &&
            spoken[offset] == 'مقتت' &&
            spoken[offset + 1] == 'للذين') {
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
                    _foldNearMiss(spoken[offset + 2]) == 'اولا') ||
                (expected[word].first == 'إناه' &&
                    expected[word + 1].first == 'ولكن' &&
                    spoken[offset] == 'إلى' &&
                    spoken[offset + 1] == 'هو' &&
                    spoken[offset + 2] == 'لكن') ||
                (expected[word].first == 'فلهن' &&
                    expected[word + 1].first == 'ثلثا' &&
                    spoken[offset] == 'فله' &&
                    spoken[offset + 1] == 'النثل' &&
                    spoken[offset + 2] == 'ثا') ||
                (expected[word].first == 'ولهن' &&
                    expected[word + 1].first == 'الربع' &&
                    spoken[offset] == 'ولهم' &&
                    spoken[offset + 1] == 'من' &&
                    spoken[offset + 2] == 'ربع') ||
                (expected[word].first == 'الزجاجة' &&
                    expected[word + 1].first == 'كأنها' &&
                    _foldNearMiss(spoken[offset]) == 'از' &&
                    spoken[offset + 1] == 'زجاجتك' &&
                    _foldNearMiss(spoken[offset + 2]) == 'انها') ||
                (expected[word].first == 'ماء' &&
                    expected[word + 1].first == 'فتيمموا' &&
                    spoken[offset] == 'ما' &&
                    _foldNearMiss(spoken[offset + 1]) == 'انفت' &&
                    (spoken[offset + 2] == 'يمموا' ||
                        spoken[offset + 2] == 'يمنوا' ||
                        spoken[offset + 2] == 'يمن')) ||
                (expected[word].first == 'الزراع' &&
                    expected[word + 1].first == 'ليغيظ' &&
                    spoken[offset] == 'الزرى' &&
                    spoken[offset + 1] == 'عن' &&
                    (spoken[offset + 2] == 'يغيض' ||
                        spoken[offset + 2] == 'يغيظ')) ||
                (expected[word].first == 'فلهما' &&
                    expected[word + 1].first == 'الثلثان' &&
                    spoken[offset] == 'فله' &&
                    (spoken[offset + 1] == 'مسل' ||
                        _foldNearMiss(spoken[offset + 1]) == 'مسيل') &&
                    (spoken[offset + 2] == 'ثالم' ||
                        spoken[offset + 2] == 'ثالمين')) ||
                (expected[word].first == 'فلهن' &&
                    expected[word + 1].first == 'الثمن' &&
                    spoken[offset] == 'فله' &&
                    spoken[offset + 1] == 'النفس' &&
                    spoken[offset + 2] == 'ملم') ||
                (expected[word].first == 'ذوا' &&
                    expected[word + 1].first == 'عدل' &&
                    spoken[offset] == 'ذواعب' &&
                    spoken[offset + 1] == 'للمؤمنكم'))) {
          if (expected[word].first == 'ذوا' &&
              expected[word + 1].first == 'عدل' &&
              spoken[offset] == 'ذواعب' &&
              spoken[offset + 1] == 'للمؤمنكم' &&
              word + 2 < expected.length &&
              expected[word + 2].first == 'منكم') {
            expanded.addAll(['ذوا', 'عدل', 'منكم']);
            offset += 2;
            word += 3;
            continue;
          }
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset += 3;
          word += 2;
          continue;
        }
        if (word + 1 < expected.length &&
            offset + 1 < spoken.length &&
            ((expected[word].first == 'اتبعوك' &&
                    expected[word + 1].first == 'فوق' &&
                    spoken[offset] == 'اتبعوا' &&
                    spoken[offset + 1] == 'كفروا' &&
                    word + 2 < expected.length &&
                    offset + 2 < spoken.length &&
                    expected[word + 2].contains(spoken[offset + 2])) ||
                (expected[word].first == 'لحم' &&
                    expected[word + 1].first == 'خنزير' &&
                    (spoken[offset] == 'لحمق' || spoken[offset] == 'نحمق') &&
                    (spoken[offset + 1] == 'زير' ||
                        spoken[offset + 1] == 'انزير')) ||
                (expected[word].first == 'ورهبانية' &&
                    expected[word + 1].first == 'ابتدعوها' &&
                    ((spoken[offset] == 'ورهبانية' &&
                            spoken[offset + 1] == 'لابتدعوها') ||
                        (spoken[offset] == 'ثانيةن' &&
                            spoken[offset + 1] == 'ابتدعوها'))) ||
                (expected[word].first == 'حق' &&
                    expected[word + 1].first == 'رعايتها' &&
                    ((spoken[offset] == 'فقرع' &&
                            _foldNearMiss(spoken[offset + 1]) == 'ايتها') ||
                        (spoken[offset] == 'حقر' &&
                            spoken[offset + 1] == 'عايتها'))) ||
                (expected[word].first == 'تواعدوهن' &&
                    expected[word + 1].first == 'سرا' &&
                    spoken[offset] == 'تواعدوه' &&
                    (spoken[offset + 1] == 'النسرن' ||
                        spoken[offset + 1] == 'النسر')) ||
                (expected[word].first == 'لا' &&
                    expected[word + 1].first == 'تضار' &&
                    spoken[offset] == 'وعتضار') ||
                (expected[word].first == 'حولين' &&
                    expected[word + 1].first == 'كاملين' &&
                    spoken[offset] == 'حولينكا' &&
                    spoken[offset + 1] == 'مليل') ||
                (expected[word].first == 'عن' &&
                    expected[word + 1].first == 'تراض' &&
                    spoken[offset] == 'العنثراظ') ||
                (expected[word].first == 'ولكن' &&
                    expected[word + 1].first == 'لا' &&
                    spoken[offset] == 'ولكلا') ||
                (expected[word].first == 'يوقع' &&
                    expected[word + 1].first == 'بينكم' &&
                    (spoken[offset] == 'تعدينكم' ||
                        spoken[offset] == 'وعدينكم')) ||
                (expected[word].first == 'لكل' &&
                    expected[word + 1].first == 'شيء' &&
                    spoken[offset] == 'لكلشي') ||
                (expected[word].first == 'ملكا' &&
                    expected[word + 1].first == 'نقاتل' &&
                    spoken[offset] == 'ملك' &&
                    spoken[offset + 1] == 'النقاتل') ||
                ((expected[word].first == 'أموال' ||
                        expected[word].first == 'وأموال') &&
                    expected[word + 1].first == 'اقترفتموها' &&
                    (spoken[offset] == 'أموال' || spoken[offset] == 'وأموال') &&
                    (spoken[offset + 1] == 'ليقترفتموها' ||
                        spoken[offset + 1] == 'لاقترفتموها')) ||
                (expected[word].first == 'أولياء' &&
                    expected[word + 1].first == 'ما' &&
                    spoken[offset] == 'أوليا' &&
                    _foldNearMiss(spoken[offset + 1]) == 'امان') ||
                (expected[word].first == 'ببابل' &&
                    expected[word + 1].first == 'هاروت' &&
                    spoken[offset] == 'بذاب' &&
                    spoken[offset + 1] == 'لها' &&
                    offset + 2 < spoken.length &&
                    spoken[offset + 2] == 'روت') ||
                (expected[word].first == 'تمسكوهن' &&
                    expected[word + 1].first == 'ضرارا' &&
                    spoken[offset] == 'تمسكوهم' &&
                    spoken[offset + 1] == 'نضرارا') ||
                (expected[word].first == 'حمل' &&
                    expected[word + 1].first == 'فأنفقوا' &&
                    spoken[offset] == 'فزحمن' &&
                    _foldNearMiss(spoken[offset + 1]) == 'انفانفقوا') ||
                (expected[word].first == 'اثنان' &&
                    expected[word + 1].first == 'ذوا' &&
                    spoken[offset] == 'وللسان' &&
                    _foldNearMiss(spoken[offset + 1]) == 'ذواعه') ||
                (expected[word].first == 'يأب' &&
                    expected[word + 1].first == 'كاتب' &&
                    (_foldNearMiss(spoken[offset]) == 'يابكاتب' ||
                        _foldNearMiss(spoken[offset]) == 'يابكاتبم' ||
                        _foldNearMiss(spoken[offset]) == 'يابكاتبن' ||
                        _foldNearMiss(spoken[offset]) == 'يابكاتهم' ||
                        _foldNearMiss(spoken[offset]) == 'وبكاتب')) ||
                (expected[word].first == 'فضرب' &&
                    expected[word + 1].first == 'الرقاب' &&
                    spoken[offset] == 'فضربر' &&
                    (spoken[offset + 1] == 'رقابحتا' ||
                        spoken[offset + 1] == 'ذقاب')) ||
                (expected[word].first == 'وصى' &&
                    expected[word + 1].first == 'به' &&
                    spoken[offset] == 'والصابي') ||
                (expected[word].first == 'وليضربن' &&
                    expected[word + 1].first == 'بخمرهن' &&
                    spoken[offset] == 'وليضربنا' &&
                    spoken[offset + 1] == 'الخمرهن') ||
                (expected[word].first == 'منا' &&
                    expected[word + 1].first == 'بعد' &&
                    spoken[offset] == 'من' &&
                    (spoken[offset + 1] == 'ننبعد' ||
                        spoken[offset + 1] == 'ننبعث')) ||
                (expected[word].first == 'تضع' &&
                    expected[word + 1].first == 'الحرب' &&
                    spoken[offset] == 'تطعل' &&
                    spoken[offset + 1] == 'حرب') ||
                (expected[word].first == 'بمصر' &&
                    expected[word + 1].first == 'بيوتا' &&
                    spoken[offset] == 'بمصره' &&
                    spoken[offset + 1] == 'يوتا') ||
                (expected[word].first == 'اجعلوا' &&
                    expected[word + 1].first == 'بيوتكم' &&
                    spoken[offset] == 'أجعلوا' &&
                    spoken[offset + 1] == 'بهتكم') ||
                (expected[word].first == 'ولد' &&
                    expected[word + 1].first == 'له' &&
                    spoken[offset] == 'ولده' &&
                    spoken[offset + 1] == 'ما') ||
                (expected[word].first == 'يضار' &&
                    expected[word + 1].first == 'كاتب' &&
                    ((spoken[offset] == 'يضارك' &&
                            spoken[offset + 1] == 'أتبه') ||
                        spoken[offset] == 'يضاركاتبوا' ||
                        spoken[offset] == 'يضاراركاتبوا' ||
                        spoken[offset] == 'وقاركاته' ||
                        spoken[offset] == 'يضاركاتبه' ||
                        (spoken[offset] == 'يضارى' &&
                            spoken[offset + 1] == 'كاتب') ||
                        (spoken[offset] == 'يضاء' &&
                            spoken[offset + 1] == 'الركاة' &&
                            offset + 2 < spoken.length &&
                            spoken[offset + 2] == 'غو'))) ||
                (expected[word].first == 'يكونا' &&
                    expected[word + 1].first == 'رجلين' &&
                    spoken[offset] == 'يكون' &&
                    (spoken[offset + 1] == 'أرجلين' ||
                        (spoken[offset + 1] == 'أرج' &&
                            offset + 2 < spoken.length &&
                            (spoken[offset + 2] == 'لين' ||
                                spoken[offset + 2] == 'ليل')))))) {
          if (expected[word].first == 'ببابل' &&
              expected[word + 1].first == 'هاروت' &&
              spoken[offset] == 'بذاب' &&
              spoken[offset + 1] == 'لها' &&
              offset + 2 < spoken.length &&
              spoken[offset + 2] == 'روت') {
            expanded.addAll(['ببابل', 'هاروت']);
            offset += 3;
            word += 2;
            continue;
          }
          if (expected[word].first == 'يضار' &&
              expected[word + 1].first == 'كاتب') {
            expanded.addAll(['يضار', 'كاتب']);
            if (spoken[offset] == 'يضاء') {
              offset += 3;
            } else if (spoken[offset] == 'يضارك' ||
                spoken[offset] == 'يضارى') {
              offset += 2;
            } else {
              offset += 1;
            }
            word += 2;
            continue;
          }
          if (expected[word].first == 'يكونا' &&
              expected[word + 1].first == 'رجلين') {
            expanded.addAll(['يكونا', 'رجلين']);
            offset += spoken[offset + 1] == 'أرج' ? 3 : 2;
            word += 2;
            continue;
          }
          if (expected[word].first == 'ولد' &&
              expected[word + 1].first == 'له' &&
              spoken[offset] == 'ولده' &&
              spoken[offset + 1] == 'ما') {
            expanded.addAll(['ولد', 'له']);
            offset += 1;
            word += 2;
            continue;
          }
          if ((expected[word].first == 'لا' &&
                  expected[word + 1].first == 'تضار' &&
                  spoken[offset] == 'وعتضار') ||
              (expected[word].first == 'عن' &&
                  expected[word + 1].first == 'تراض' &&
                  spoken[offset] == 'العنثراظ') ||
              (expected[word].first == 'ولكن' &&
                  expected[word + 1].first == 'لا' &&
                  spoken[offset] == 'ولكلا') ||
              (expected[word].first == 'يوقع' &&
                  expected[word + 1].first == 'بينكم' &&
                  (spoken[offset] == 'تعدينكم' ||
                      spoken[offset] == 'وعدينكم')) ||
              (expected[word].first == 'لكل' &&
                  expected[word + 1].first == 'شيء' &&
                  spoken[offset] == 'لكلشي') ||
              (expected[word].first == 'يأب' &&
                  expected[word + 1].first == 'كاتب' &&
                  (_foldNearMiss(spoken[offset]) == 'يابكاتب' ||
                      _foldNearMiss(spoken[offset]) == 'يابكاتبم' ||
                      _foldNearMiss(spoken[offset]) == 'يابكاتبن' ||
                      _foldNearMiss(spoken[offset]) == 'يابكاتهم' ||
                      _foldNearMiss(spoken[offset]) == 'وبكاتب')) ||
              (expected[word].first == 'وصى' &&
                  expected[word + 1].first == 'به' &&
                  spoken[offset] == 'والصابي')) {
            expanded.addAll([expected[word].first, expected[word + 1].first]);
            offset++;
            word += 2;
            continue;
          }
          if (expected[word].first == 'فضرب' &&
              expected[word + 1].first == 'الرقاب' &&
              spoken[offset] == 'فضربر' &&
              spoken[offset + 1] == 'رقابحتا' &&
              word + 2 < expected.length &&
              expected[word + 2].first == 'حتى') {
            expanded.addAll(['فضرب', 'الرقاب', 'حتى']);
            offset += 2;
            word += 3;
            continue;
          }
          expanded.addAll([expected[word].first, expected[word + 1].first]);
          offset += 2;
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
        final hasLeftAnchor =
            word > 0 &&
            expanded.isNotEmpty &&
            expected[word - 1].contains(expanded.last);
        final hasRightAnchor =
            nextExpectedSet != null &&
            offset + 1 < spoken.length &&
            (nextExpectedSet.contains(spoken[offset + 1]) ||
                (nextExpectedSet.first.length >= 4 &&
                    _foldNearMiss(nextExpectedSet.first) ==
                        _foldNearMiss(spoken[offset + 1])) ||
                (nextExpectedSet.first.length >= 4 &&
                    spoken[offset + 1] == '${nextExpectedSet.first}ا') ||
                (nextExpectedSet.first.length == 3 &&
                    spoken[offset + 1].length == 3 &&
                    _isThreeLetterFlankedNearMiss(
                      nextExpectedSet.first,
                      spoken[offset + 1],
                    )) ||
                (offset + 2 < spoken.length &&
                    _matchesSplitBoundaryWord(
                      nextExpectedSet.first,
                      spoken[offset + 1],
                      spoken[offset + 2],
                    )) ||
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
        if (hasLeftAnchor &&
            ((expected[word].first == 'يؤمن' &&
                    spoken[offset] == 'يؤمنون') ||
                (expected[word].first == 'مثواه' &&
                    spoken[offset] == 'مثوى') ||
                (expected[word].first == 'الغائط' &&
                    (spoken[offset] == 'الغائظ' ||
                        spoken[offset] == 'الغائق')) ||
                (expected[word].first == 'فاتقون' &&
                    spoken[offset] == 'الفتقون') ||
                (expected[word].first == 'دري' &&
                    spoken[offset] == 'ذري') ||
                (expected[word].first == 'فيميلون' &&
                    (spoken[offset] == 'فيمينون' ||
                        spoken[offset] == 'فيميدون')) ||
                (expected[word].first == 'تسريح' &&
                    spoken[offset] == 'تسريحون') ||
                (expected[word].first == 'الثلث' &&
                    (spoken[offset] == 'اثرت' ||
                        spoken[offset] == 'اثرف' ||
                        spoken[offset] == 'اثتلواث' ||
                        spoken[offset] == 'اثلث')) ||
                (expected[word].first == 'السدس' &&
                    (spoken[offset] == 'السدود' ||
                        spoken[offset] == 'اسجدوا' ||
                        spoken[offset] == 'اسجدت' ||
                        spoken[offset] == 'استدس' ||
                        spoken[offset] == 'اشددوا' ||
                        spoken[offset] == 'اسسدواس')) ||
                (expected[word].first == 'لآكلون' &&
                    spoken[offset] == 'لآتلون') ||
                (expected[word].first == 'الآثمين' &&
                    (spoken[offset] == 'الآخرين' ||
                        spoken[offset] == 'الآفرين')) ||
                (expected[word].first == 'ارتبتم' &&
                    spoken[offset] == 'اغتبتم') ||
                (expected[word].first == 'فينتقم' &&
                    spoken[offset] == 'فانتقم') ||
                (expected[word].first == 'عما' &&
                    spoken[offset] == 'على' &&
                    hasRightAnchor) ||
                (expected[word].first == 'يعظكم' &&
                    spoken[offset] == 'أعظكم') ||
                (expected[word].first == 'رزقناكم' &&
                    spoken[offset] == 'رزقناهم') ||
                (expected[word].first == 'والبغضاء' &&
                    spoken[offset] == 'البغضار') ||
                (expected[word].first == 'والميسر' &&
                    spoken[offset] == 'والميتر') ||
                (expected[word].first == 'فهل' &&
                    spoken[offset] == 'فعل' &&
                    hasRightAnchor) ||
                (expected[word].first == 'رزقنا' &&
                    spoken[offset] == 'يلقى' &&
                    offset + 1 == spoken.length) ||
                (expected[word].first == 'متشابها' &&
                    (spoken[offset] == 'تشادمت' ||
                        spoken[offset] == 'متشادمت') &&
                    offset + 1 == spoken.length) ||
                (expected[word].first == 'فسوق' &&
                    (spoken[offset] == 'فسوقوا' ||
                        spoken[offset] == 'فسوقهم')) ||
                (expected[word].first == 'تضاروهن' &&
                    (spoken[offset] == 'تضاروهم' ||
                        spoken[offset] == 'أروهن')) ||
                (expected[word].first == 'وجدكم' &&
                    (spoken[offset] == 'رجيدكم' ||
                        spoken[offset] == 'يجدكم')) ||
                (expected[word].first == 'وإخوانكم' &&
                    spoken[offset] == 'وإسوانكم') ||
                (expected[word].first == 'كفر' &&
                    spoken[offset] == 'تفر' &&
                    hasRightAnchor) ||
                (expected[word].first == 'يغضضن' &&
                    spoken[offset] == 'يرضغن') ||
                (expected[word].first == 'أن' &&
                    spoken[offset] == 'عن' &&
                    hasRightAnchor) ||
                (expected[word].first == 'الله' &&
                    spoken[offset] == 'والله' &&
                    hasRightAnchor) ||
                (expected[word].first == 'واسمعوا' &&
                    spoken[offset] == 'واسمن' &&
                    hasRightAnchor) ||
                (expected[word].first == 'وأشربوا' &&
                    (spoken[offset] == 'وأشرى' ||
                        spoken[offset] == 'فربوا' ||
                        spoken[offset] == 'وأسربوا')) ||
                (expected[word].first == 'إما' &&
                    (spoken[offset] == 'إنا' || spoken[offset] == 'لا') &&
                    hasRightAnchor) ||
                (expected[word].first == 'أف' &&
                    spoken[offset] == 'أثب' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أأعجمي' &&
                    spoken[offset] == 'أهحجمي') ||
                (expected[word].first == 'موقفهم' &&
                    spoken[offset] == 'أوقفه' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أفلم' &&
                    spoken[offset] == 'فلن' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أتحاجوننا' &&
                    spoken[offset] == 'فتى' &&
                    hasRightAnchor) ||
                (expected[word].first == 'تتخذوا' &&
                    spoken[offset] == 'يدخلوا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أهل' &&
                    spoken[offset] == 'إلى' &&
                    hasRightAnchor) ||
                (expected[word].first == 'بيوتا' &&
                    spoken[offset] == 'يوتا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'اهبطوا' &&
                    spoken[offset] == 'بقوا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'تحاضون' &&
                    spoken[offset] == 'تحطون' &&
                    hasRightAnchor) ||
                (expected[word].first == 'تأكلون' &&
                    spoken[offset] == 'يأكلون' &&
                    hasRightAnchor) ||
                (expected[word].first == 'التراث' &&
                    (spoken[offset] == 'التلاث' ||
                        spoken[offset] == 'الثلاث') &&
                    hasRightAnchor) ||
                (expected[word].first == 'وتحبون' &&
                    spoken[offset] == 'يحبون' &&
                    hasRightAnchor) ||
                (expected[word].first == 'المال' &&
                    spoken[offset] == 'منه' &&
                    hasRightAnchor) ||
                (expected[word].first == 'ظلم' &&
                    spoken[offset] == 'غلم' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أوسط' &&
                    spoken[offset] == 'أوسطين') ||
                (expected[word].first == 'ونجواهم' &&
                    spoken[offset] == 'ونجواكم') ||
                (expected[word].first == 'ورسلنا' &&
                    _foldNearMiss(spoken[offset]) == 'واسكلنا') ||
                (expected[word].first == 'يكتبون' &&
                    spoken[offset] == 'يكتبور') ||
                (expected[word].first == 'وموعظة' &&
                    (spoken[offset] == 'ومغلبة' ||
                        spoken[offset] == 'ونغرظة' ||
                        spoken[offset] == 'ونغلظة')) ||
                (expected[word].first == 'الله' &&
                    spoken[offset] == 'الضالا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'لحم' &&
                    spoken[offset] == 'نحمى' &&
                    hasRightAnchor) ||
                (expected[word].first == 'رحيم' &&
                    spoken[offset] == 'الرحيم') ||
                (expected[word].first == 'كفارة' &&
                    (spoken[offset] == 'تفتارة' ||
                        spoken[offset] == 'كالتارة')) ||
                (expected[word].first == 'حلفتم' &&
                    (spoken[offset] == 'حلقتم' ||
                        spoken[offset] == 'حلقم')) ||
                (expected[word].first == 'يشقق' &&
                    (spoken[offset] == 'يشرقق' ||
                        spoken[offset] == 'يشرقه' ||
                        spoken[offset] == 'يشرتقب')) ||
                (expected[word].first == 'فيخرج' &&
                    (spoken[offset] == 'فيقرج' ||
                        spoken[offset] == 'فيقر')) ||
                (expected[word].first == 'يهبط' &&
                    (spoken[offset] == 'يهدط' ||
                        _foldNearMiss(spoken[offset]) == 'ياخط' ||
                        spoken[offset] == 'يعبط')) ||
                (expected[word].first == 'عما' &&
                    spoken[offset] == 'عدنا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'فتيمموا' &&
                    spoken[offset] == 'فتيمن' &&
                    hasRightAnchor) ||
                (expected[word].first == 'آزر' &&
                    spoken[offset] == 'مئزر') ||
                (expected[word].first == 'الزراع' &&
                    (spoken[offset] == 'الصراط' ||
                        spoken[offset] == 'الصراح')) ||
                (expected[word].first == 'جعلنا' &&
                    spoken[offset] == 'جاعلنا') ||
                (expected[word].first == 'وعد' &&
                    (spoken[offset] == 'وعلى' || spoken[offset] == 'وعدى') &&
                    hasRightAnchor) ||
                (expected[word].first == 'حل' &&
                    spoken[offset] == 'محل' &&
                    hasRightAnchor) ||
                (expected[word].first == 'لهن' &&
                    spoken[offset] == 'لهم') ||
                (expected[word].first == 'فواحش' &&
                    spoken[offset] == 'تواحش') ||
                (expected[word].first == 'الإثم' &&
                    _foldNearMiss(spoken[offset]) == 'الاثن') ||
                (expected[word].first == 'آتاكم' &&
                    _foldNearMiss(spoken[offset]) == 'اتاه') ||
                (expected[word].first == 'بها' &&
                    spoken[offset] == 'فيها' &&
                    hasRightAnchor) ||
                (expected[word].first == 'خطبة' &&
                    spoken[offset] == 'فيقبة') ||
                (expected[word].first == 'النساء' &&
                    spoken[offset] == 'نستاء') ||
                (expected[word].first == 'علم' &&
                    spoken[offset] == 'عالم' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أنكم' &&
                    _foldNearMiss(spoken[offset]) == 'انهم' &&
                    hasRightAnchor) ||
                (expected[word].first == 'ستذكرونها' &&
                    spoken[offset] == 'سيذكرونها') ||
                (expected[word].first == 'تواعدوهن' &&
                    spoken[offset] == 'تواحدوهن') ||
                (expected[word].first == 'تبتغوا' &&
                    spoken[offset] == 'تبتغون') ||
                (expected[word].first == 'تحتها' &&
                    spoken[offset] == 'تحفيها') ||
                (expected[word].first == 'فاسقين' &&
                    spoken[offset] == 'فاسدين') ||
                (expected[word].first == 'تأكلون' &&
                    _foldNearMiss(spoken[offset]) == 'تاتلون') ||
                (expected[word].first == 'أولياء' &&
                    _foldNearMiss(spoken[offset]) == 'انبياء') ||
                (expected[word].first == 'بعضهم' &&
                    spoken[offset] == 'بعضكم' &&
                    hasRightAnchor) ||
                (expected[word].first == 'بعض' &&
                    spoken[offset] == 'بعضا') ||
                (expected[word].first == 'حبطت' &&
                    spoken[offset] == 'حافضت') ||
                (expected[word].first == 'مأواهم' &&
                    _foldNearMiss(spoken[offset]) == 'ماواكم') ||
                (expected[word].first == 'فردوا' &&
                    spoken[offset] == 'وردوا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أعدت' &&
                    (spoken[offset] == 'ورزقت' || spoken[offset] == 'قريبتت') &&
                    hasRightAnchor) ||
                (expected[word].first == 'وبث' &&
                    (spoken[offset] == 'وبست' || spoken[offset] == 'وبس')) ||
                (expected[word].first == 'رزقنا' &&
                    (_foldNearMiss(spoken[offset]) == 'القنا' ||
                        spoken[offset] == 'يرجقنا')) ||
                (expected[word].first == 'أزواج' &&
                    (_foldNearMiss(spoken[offset]) == 'ازواكم' ||
                        _foldNearMiss(spoken[offset]) == 'الواكم')) ||
                (expected[word].first == 'وليتلطف' &&
                    (spoken[offset] == 'وليتلاطف' ||
                        spoken[offset] == 'وليتلقف')) ||
                (expected[word].first == 'مشتبها' &&
                    (spoken[offset] == 'مشتبهرون' ||
                        spoken[offset] == 'مستبها')) ||
                (expected[word].first == 'أثمر' &&
                    _foldNearMiss(spoken[offset]) == 'اسمر') ||
                (expected[word].first == 'وينعه' &&
                    spoken[offset] == 'ويمعه') ||
                (expected[word].first == 'فمالئون' &&
                    _foldNearMiss(spoken[offset]) == 'فباليون') ||
                (expected[word].first == 'مسفوحا' &&
                    spoken[offset] == 'مسكوحا') ||
                (expected[word].first == 'دولة' &&
                    _foldNearMiss(spoken[offset]) == 'دونه') ||
                (expected[word].first == 'أخ' &&
                    _foldNearMiss(spoken[offset]) == 'اخن' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أخت' &&
                    _foldNearMiss(spoken[offset]) == 'اختن' &&
                    hasRightAnchor) ||
                (expected[word].first == 'ذوا' &&
                    (spoken[offset] == 'لا' ||
                        spoken[offset] == 'ذا' ||
                        _foldNearMiss(spoken[offset]) == 'ذواعه') &&
                    hasRightAnchor) ||
                (expected[word].first == 'عدل' &&
                    (spoken[offset] == 'عدر' || spoken[offset] == 'عدن') &&
                    hasRightAnchor) ||
                (expected[word].first == 'هديا' &&
                    spoken[offset] == 'عديا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'طعام' &&
                    (spoken[offset] == 'تعام' || spoken[offset] == 'تعم') &&
                    hasRightAnchor) ||
                (expected[word].first == 'وبال' &&
                    spoken[offset] == 'بعد' &&
                    hasRightAnchor) ||
                (expected[word].first == 'رأفة' &&
                    _foldNearMiss(spoken[offset]) == 'رافا') ||
                (expected[word].first == 'والسلوى' &&
                    (spoken[offset] == 'موسلوا' ||
                        _foldNearMiss(spoken[offset]) == 'السلوي')) ||
                (expected[word].first == 'ظلمونا' &&
                    spoken[offset] == 'ظلعونا') ||
                (expected[word].first == 'ولكن' &&
                    spoken[offset] == 'ولاكن') ||
                (expected[word].first == 'أنفسهم' &&
                    spoken[offset] == 'منفسهم') ||
                (expected[word].first == 'بعض' &&
                    spoken[offset] == 'بعد' &&
                    hasRightAnchor) ||
                (expected[word].first == 'العنت' &&
                    (_foldNearMiss(spoken[offset]) == 'العنه' ||
                        spoken[offset] == 'يلعنت')) ||
                (expected[word].first == 'فليصمه' &&
                    (spoken[offset] == 'فليصم' || spoken[offset] == 'اليصم')) ||
                (expected[word].first == 'والدة' &&
                    spoken[offset] == 'وعاددتهم' &&
                    hasRightAnchor) ||
                (expected[word].first == 'القيوم' &&
                    spoken[offset] == 'يلقينه' &&
                    hasRightAnchor) ||
                (expected[word].first == 'سنة' &&
                    _foldNearMiss(spoken[offset]) == 'سمه' &&
                    hasRightAnchor) ||
                (expected[word].first == 'وليضربن' &&
                    spoken[offset] == 'وليضربنا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'بخمرهن' &&
                    spoken[offset] == 'الخمرهن' &&
                    hasRightAnchor) ||
                (expected[word].first == 'الهدي' &&
                    (spoken[offset] == 'الهير' ||
                        spoken[offset] == 'الهدر' ||
                        spoken[offset] == 'الهدل') &&
                    hasRightAnchor) ||
                (expected[word].first == 'نكاحا' &&
                    spoken[offset] == 'لكافا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'أثخنتموهم' &&
                    (_foldNearMiss(spoken[offset]) == 'افخنتموهم' ||
                        _foldNearMiss(spoken[offset]) == 'اثقنتموهم')) ||
                (expected[word].first == 'مسمى' &&
                    spoken[offset] == 'مسم' &&
                    hasRightAnchor) ||
                (expected[word].first == 'نعبدهم' &&
                    (_foldNearMiss(spoken[offset]) == 'اعبدهم' ||
                        spoken[offset] == 'يعبدهم') &&
                    hasRightAnchor) ||
                (expected[word].first == 'أسلحتهم' &&
                    _foldNearMiss(spoken[offset]) == 'اصلحتهم') ||
                (expected[word].first == 'القتلى' &&
                    spoken[offset] == 'القتل' &&
                    hasRightAnchor) ||
                (expected[word].first == 'تعضلوهن' &&
                    (spoken[offset] == 'تعبلوهن' ||
                        spoken[offset] == 'تعبلوه')) ||
                (expected[word].first == 'بقلها' &&
                    (spoken[offset] == 'بطنها' || spoken[offset] == 'فقلها') &&
                    hasRightAnchor) ||
                (expected[word].first == 'وقثائها' &&
                    (_foldNearMiss(spoken[offset]) == 'وقسفايها' ||
                        _foldNearMiss(spoken[offset]) == 'وقفايها')) ||
                (expected[word].first == 'وفومها' &&
                    (spoken[offset] == 'وفهمها' || spoken[offset] == 'وقومها')) ||
                (expected[word].first == 'وبصلها' &&
                    (spoken[offset] == 'وبصرها' || spoken[offset] == 'وصرها') &&
                    hasRightAnchor) ||
                (expected[word].first == 'تأخذه' &&
                    spoken[offset] == 'تأخذوا' &&
                    hasRightAnchor) ||
                (expected[word].first == 'متشابها' &&
                    (spoken[offset] == 'متشابعا' ||
                        spoken[offset] == 'متشابهام')) ||
                (expected[word].first == 'تقشعر' &&
                    (spoken[offset] == 'تقشعروا' ||
                        spoken[offset] == 'اقشعروا') &&
                    hasRightAnchor) ||
                (expected[word].first == 'تلين' &&
                    spoken[offset] == 'تليم' &&
                    hasRightAnchor) ||
                (expected[word].first == 'وأحصوا' &&
                    (_foldNearMiss(spoken[offset]) == 'واحص' ||
                        _foldNearMiss(spoken[offset]) == 'واحسوا') &&
                    hasRightAnchor) ||
                (expected[word].first == 'لتعتدوا' &&
                    spoken[offset] == 'لتعتدوهم') ||
                (expected[word].first == 'حرم' &&
                    spoken[offset] == 'حر' &&
                    offset + 1 == spoken.length) ||
                (expected[word].first.length >= 5 &&
                    spoken[offset] ==
                        '${expected[word].first}${expected[word].first.substring(expected[word].first.length - 2)}') ||
                (expected[word].first.length >= 3 &&
                    expected[word].first.endsWith('هن') &&
                    spoken[offset] ==
                        '${expected[word].first.substring(0, expected[word].first.length - 1)}م'))) {
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
                    (_foldNearMiss(spoken[offset]) ==
                            _foldNearMiss(
                              expected[word].first.substring(
                                0,
                                expected[word].first.length - 2,
                              ),
                            ) ||
                        spoken[offset] ==
                            '${expected[word].first.substring(0, expected[word].first.length - 2)}ى')) ||
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
                (expected[word].first == 'لا' &&
                    keys[ayah] == '6:163' &&
                    (spoken[offset] == 'ما' || spoken[offset] == 'منا')) ||
                (expected[word].first == 'اعلموا' &&
                    keys[ayah] == '5:98' &&
                    (spoken[offset] == 'علموا' || spoken[offset] == 'علم')) ||
                (expected[word].first == 'شرع' &&
                    keys[ayah] == '42:13' &&
                    spoken[offset] == 'شرى') ||
                (expected[word].first == 'ادع' &&
                    keys[ayah] == '2:68' &&
                    spoken[offset] == 'يعلو') ||
                (expected[word].first == 'الاسم' &&
                    spoken[offset] == 'للسم') ||
                (expected[word].first == 'وسعى' &&
                    nextExpectedSet.first == 'لها' &&
                    spoken[offset] == 'وتعالى') ||
                (expected[word].first == 'الطلاق' &&
                    _foldNearMiss(spoken[offset]) == 'اطلاق') ||
                (expected[word].first == 'النار' &&
                    _foldNearMiss(spoken[offset]) == 'انار') ||
                (expected[word].first.length >= 6 &&
                    expected[word].first.startsWith('للل') &&
                    spoken[offset] == expected[word].first.substring(1)) ||
                (expected[word].first.length >= 5 &&
                    expected[word].first.contains('ت') &&
                    !(expected[word].first.endsWith('ى') &&
                        spoken[offset].endsWith('ي')) &&
                    _foldNearMiss(spoken[offset]) ==
                        _foldNearMiss(expected[word].first)) ||
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
                        nextExpectedSet.first.startsWith('ف') ||
                        (expected[word].first.endsWith('ه') &&
                            nextExpectedSet.first.startsWith('م'))) &&
                    spoken[offset] == '${expected[word].first}م') ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.endsWith('ة') &&
                    nextExpectedSet.first.startsWith('م') &&
                    (spoken[offset] ==
                            '${expected[word].first.substring(0, expected[word].first.length - 1)}تهم' ||
                        spoken[offset] ==
                            '${expected[word].first.substring(0, expected[word].first.length - 1)}تم')) ||
                (expected[word].first == 'يؤمن' &&
                    spoken[offset] == 'يؤمنون') ||
                (expected[word].first == 'ولأمة' &&
                    nextExpectedSet.first == 'مؤمنة' &&
                    (_foldNearMiss(spoken[offset]) == 'ولامتوا' ||
                        _foldNearMiss(spoken[offset]) == 'ولامتوام')) ||
                (expected[word].first == 'هن' &&
                    nextExpectedSet.first == 'لباس' &&
                    (spoken[offset] == 'كن' || spoken[offset] == 'ظن')) ||
                (expected[word].first.length >= 4 &&
                    expected[word].first.contains('ث') &&
                    expected[word].first.replaceAll('ث', 'س') ==
                        spoken[offset]) ||
                (hasLeftAnchor &&
                    ((expected[word].first == 'لهب' &&
                            spoken[offset] == 'ذهب') ||
                        (expected[word].first == 'ذو' &&
                            spoken[offset] == 'كو') ||
                        (expected[word].first == 'تخافون' &&
                            spoken[offset] == 'تخافهم') ||
                        (expected[word].first == 'نيلا' &&
                            spoken[offset] == 'بينا') ||
                        (expected[word].first == 'يكفلونه' &&
                            _foldNearMiss(spoken[offset]) == 'ياكلونه') ||
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
                            (_foldNearMiss(spoken[offset]) == 'تافلون' ||
                                _foldNearMiss(spoken[offset]) == 'تقصلون')) ||
                        (expected[word].first == 'إناه' &&
                            _foldNearMiss(spoken[offset]) == 'اله') ||
                        (expected[word].first == 'نوم' &&
                            (spoken[offset] == 'نعون' ||
                                spoken[offset] == 'نعوم')) ||
                        (expected[word].first == 'واخشون' &&
                            (spoken[offset] == 'واخشعون' ||
                                spoken[offset] == 'واخشوهون')) ||
                        (expected[word].first == 'أكملت' &&
                            _foldNearMiss(spoken[offset]) == 'اكتملت') ||
                        (expected[word].first == 'اضطر' &&
                            _foldNearMiss(spoken[offset]) == 'اختر') ||
                        (expected[word].first == 'وظللنا' &&
                            (spoken[offset] == 'وظلينا' ||
                                spoken[offset] == 'وضلينا')) ||
                        (expected[word].first == 'نصف' &&
                            (spoken[offset] == 'نسط' ||
                                spoken[offset] == 'مصف')) ||
                        (expected[word].first == 'مبسوطتان' &&
                            spoken[offset] == 'مبساطتان') ||
                        (expected[word].first == 'الأنثيين' &&
                            _foldNearMiss(spoken[offset]) == 'الانثيان') ||
                        (expected[word].first == 'يوقد' &&
                            spoken[offset] == 'ينقد'))))) {
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
                (expected[word].first.length >= 3 &&
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
            !(expected[word].first.endsWith('ى') &&
                spoken[offset].endsWith('ي')) &&
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
            !(expected[word].first.endsWith('ى') &&
                spoken[offset].endsWith('ي')) &&
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
          // However, if the expected word ends with 'ى' (alif maqsura) and the
          // spoken word ends with 'ي' (ya), it is a vowel/haraka mistake
          // (kasra/ya instead of fatha/alif maqsura, e.g. استوي for استوى) and
          // must not be auto-corrected.
          if (word + 2 < expected.length &&
              offset + 2 < spoken.length &&
              !(expected[word].first.endsWith('ى') &&
                  spoken[offset].endsWith('ي')) &&
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
            expanded.isNotEmpty &&
            expected[word - 1].contains(expanded.last) &&
            !(expected[word].first.endsWith('ى') &&
                spoken[offset].endsWith('ي')) &&
            (_matchesQalqalahPauseEnding(
                  expected[word].first,
                  spoken[offset],
                ) ||
                _matchesAssimilatedMedialSyllable(
                  expected[word].first,
                  spoken[offset],
                ) ||
                (offset == spoken.length - 1 &&
                    (_foldNearMiss(spoken[offset]).length >= 3 &&
                        (_foldNearMiss(spoken[offset]) ==
                                _foldNearMiss(expected[word].first) ||
                            _foldAlifMaqsuraToAlif(spoken[offset]) ==
                                _foldAlifMaqsuraToAlif(
                                  expected[word].first,
                                )))) ||
                (offset == spoken.length - 1 &&
                    _matchesTerminalAlifElision(
                      expected[word].first,
                      spoken[offset],
                      hasRightAnchor: true,
                    )) ||
                (offset == spoken.length - 1 &&
                    _matchesTerminalYaInsertion(
                      expected[word].first,
                      spoken[offset],
                      hasRightAnchor: true,
                    )) ||
                (offset == spoken.length - 1 &&
                    expected[word].first.length >= 3 &&
                    ((expected[word].first.endsWith('ا') &&
                            _foldNearMiss(spoken[offset]) ==
                                _foldNearMiss(
                                  expected[word].first.substring(
                                    0,
                                    expected[word].first.length - 1,
                                  ),
                                )) ||
                        (expected[word].first.endsWith('ة') &&
                            _foldNearMiss(spoken[offset]) ==
                                _foldNearMiss(
                                  '${expected[word].first.substring(0, expected[word].first.length - 1)}ت',
                                )))) ||
                (!quranVocabulary.contains(spoken[offset]) &&
                    expected[word].first.length >= 4 &&
                    _isOrthographicNearMiss(
                      expected[word].first,
                      spoken[offset],
                    )) ||
                (expected[word].first.length == 3 &&
                    word >= 2 &&
                    expanded.length >= 2 &&
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
            ) ||
            (retained.length >= 2 &&
                (_matchesBoundaryConsonantShift(
                      retained[retained.length - 2],
                      retained.last,
                      [incoming[start - 2], incoming[start - 1]],
                    ) ||
                    _matchesAttachedPronounSplit(
                      retained[retained.length - 2],
                      retained.last,
                      [incoming[start - 2], incoming[start - 1]],
                    ))))) {
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
        !(retained.last.endsWith('ى') && incoming[start - 1].endsWith('ي')) &&
        ((!quranVocabulary.contains(incoming[start - 1]) &&
                _isOrthographicNearMiss(retained.last, incoming[start - 1])) ||
            (retained.last.length == 3 &&
                incoming[start - 1].length == 3 &&
                _isThreeLetterFlankedNearMiss(
                  retained.last,
                  incoming[start - 1],
                )) ||
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
        (incoming[0].length - retained.last.length).abs() <= 1 &&
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
              (keptWord.length >= 3 &&
                  !keptWord.startsWith('ال') &&
                  (_foldNearMiss(cleaned) == _foldNearMiss('ال$keptWord') ||
                      (keptWord.length >= 4 &&
                          cleaned.startsWith('ال') &&
                          hasNeighbors &&
                          _isOrthographicNearMiss(
                            _foldNearMiss('ال$keptWord'),
                            _foldNearMiss(cleaned),
                          )))) ||
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
        // Check contiguous phrase repetition of 1..9 already-matched words,
        // or 1 elided repeated word (e.g. 'ويعلمكم الله والله بكل شيء عليم' -> 'ويعلمكم الله بكل شيء عليم').
        if (j > at &&
            i < heard.length &&
            j + 1 < retained.length &&
            _foldNearMiss(retained[j]) == 'و${_foldNearMiss(retained[j - 1])}' &&
            wordMatchesRetained(
              heard[i],
              retained[j + 1],
              isLast: isLast,
              hasNeighbors: true,
              runLength: heard.length,
            )) {
          j++;
          continue;
        }
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
      if (skip >= 2 &&
          run.length < 8 &&
          !(run.length >= 6 &&
              retained.length >= 6 &&
              run.length == retained.length)) {
        continue;
      }
      final minAt = (skip > 0 &&
              !(run.length >= 6 &&
                  retained.length >= 6 &&
                  run.length == retained.length))
          ? 1
          : 0;
      for (var at = minAt; at < retained.length; at++) {
        if (skip == 1 && at > 0) {
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
        final baseEffectiveRun = corrected ?? run;
        final effectiveRun =
            baseEffectiveRun.length >= 12 &&
                baseEffectiveRun.last.length <= 2 &&
                !retained.contains(baseEffectiveRun.last)
            ? baseEffectiveRun.sublist(0, baseEffectiveRun.length - 1)
            : baseEffectiveRun;
        // For long 30s stop windows (>= 12 words) when 100% of the ayah was
        // already revealed in order, verify that both the opening (>= 3 words)
        // and closing (>= 3 words) of the stop window match retained[at..end]
        // in order, or that a >= 15-word 30s window matches >= 6 opening words
        // before hitting Whisper's 224-token ceiling.
        if (effectiveRun.length >= 12 && at + 4 <= retained.length) {
          var prefixMatched = 0;
          while (prefixMatched < effectiveRun.length &&
              at + prefixMatched < retained.length &&
              wordMatchesRetained(
                effectiveRun[prefixMatched],
                retained[at + prefixMatched],
                isLast: false,
                hasNeighbors: true,
                runLength: effectiveRun.length,
              )) {
            prefixMatched++;
          }
          if (prefixMatched >= 3) {
            for (
              var end = at + prefixMatched + 2;
              end <= retained.length;
              end++
            ) {
              if ((end - at - effectiveRun.length).abs() > 5 &&
                  effectiveRun.length < 15) {
                continue;
              }
              var suffixOk = true;
              for (var s = 0; s < 3; s++) {
                final hIdx = effectiveRun.length - 3 + s;
                final rIdx = end - 3 + s;
                if (hIdx < 0 ||
                    rIdx < at ||
                    !wordMatchesRetained(
                      effectiveRun[hIdx],
                      retained[rIdx],
                      isLast: s == 2,
                      hasNeighbors: s < 2,
                      runLength: effectiveRun.length,
                    )) {
                  suffixOk = false;
                  break;
                }
              }
              if (suffixOk) return true;
            }
          }
          if (effectiveRun.length >= 15 && prefixMatched >= 6) {
            return true;
          }
          if (effectiveRun.length >= 12 && retained.length >= 8) {
            for (var end = 8; end <= retained.length; end++) {
              var tailOk = true;
              for (var s = 0; s < 8; s++) {
                final hIdx = effectiveRun.length - 8 + s;
                final rIdx = end - 8 + s;
                if (!wordMatchesRetained(
                  effectiveRun[hIdx],
                  retained[rIdx],
                  isLast: s == 7,
                  hasNeighbors: s < 7,
                  runLength: effectiveRun.length,
                )) {
                  tailOk = false;
                  break;
                }
              }
              if (tailOk) return true;
            }
          }
        }
        if (retained.length >= 10 &&
            effectiveRun.length >= 8 &&
            at + 7 <= retained.length &&
            wordMatchesRetained(
              effectiveRun.last,
              retained.last,
              isLast: true,
              hasNeighbors: true,
              runLength: effectiveRun.length,
            )) {
          var prefixMatched = 0;
          while (prefixMatched < effectiveRun.length &&
              at + prefixMatched < retained.length &&
              wordMatchesRetained(
                effectiveRun[prefixMatched],
                retained[at + prefixMatched],
                isLast: false,
                hasNeighbors: true,
                runLength: effectiveRun.length,
              )) {
            prefixMatched++;
          }
          if (prefixMatched >= 7) return true;
        }
        if (retained.length >= 5 &&
            retained.length <= 8 &&
            run.length >= retained.length &&
            at == 0 &&
            wordMatchesRetained(
              run.first,
              retained.first,
              isLast: false,
              hasNeighbors: true,
              runLength: run.length,
            )) {
          var tailOk = true;
          for (var s = 0; s < 3; s++) {
            final hWord = _foldNearMiss(run[run.length - 3 + s]);
            final rWord = _foldNearMiss(retained[retained.length - 3 + s]);
            if (hWord != rWord &&
                !(hWord.length >= 4 && rWord.endsWith(hWord))) {
              tailOk = false;
              break;
            }
          }
          if (tailOk) return true;
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
    if (_harakat.hasMatch(spokenWord)) return false;
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
    if (_harakat.hasMatch(spokenWord)) return false;
    if (expectedWord.endsWith('ى') &&
        (spokenWord.endsWith('ي') ||
            spokenWord.endsWith('يت') ||
            spokenWord.endsWith('يتم') ||
            spokenWord.endsWith('ينا'))) {
      return false;
    }
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
    if (expectedWord == 'ماء' &&
        firstSpoken == 'ما' &&
        (secondSpoken == 'أن' || secondSpoken == 'ان')) {
      return true;
    }
    if (expectedWord == 'غلت' &&
        firstSpoken == 'قل' &&
        secondSpoken == 'لت') {
      return true;
    }
    if (expectedWord.length < 4) return false;
    if (expectedWord == 'والموقوذة' &&
        firstSpoken == 'والموق' &&
        secondSpoken == 'مذة') {
      return true;
    }
    if (expectedWord == 'فإمساك' &&
        firstSpoken == 'كانف' &&
        _foldNearMiss(secondSpoken) == 'امساكم') {
      return true;
    }
    if (expectedWord == 'جاءتهم' &&
        firstSpoken == 'يا' &&
        _foldNearMiss(secondSpoken) == 'اتهم') {
      return true;
    }
    if (expectedWord == 'ومنهاجا' &&
        firstSpoken == 'ومنها' &&
        _foldNearMiss(secondSpoken) == 'جا') {
      return true;
    }
    if (expectedWord == 'عرضتم' &&
        firstSpoken == 'عن' &&
        secondSpoken == 'ربتم') {
      return true;
    }
    if (expectedWord == 'وتصريف' &&
        (firstSpoken == 'وتصري' || firstSpoken == 'واصري') &&
        secondSpoken == 'في') {
      return true;
    }
    if (expectedWord == 'فمالئون' &&
        (_foldNearMiss(firstSpoken) == 'ااففا' ||
            _foldNearMiss(firstSpoken) == 'اافبا') &&
        (_foldNearMiss(secondSpoken) == 'القود' ||
            _foldNearMiss(secondSpoken) == 'القول')) {
      return true;
    }
    if (expectedWord == 'ظلمونا' &&
        firstSpoken == 'ظلعوا' &&
        secondSpoken == 'نار') {
      return true;
    }
    if (expectedWord == 'بقنطار' &&
        firstSpoken == 'بقر' &&
        (secondSpoken == 'طاغ' || secondSpoken == 'طاري')) {
      return true;
    }
    if (expectedWord == 'فينتقم' &&
        firstSpoken == 'فين' &&
        secondSpoken == 'تقم') {
      return true;
    }
    if (expectedWord == 'ولعلكم' &&
        firstSpoken == 'ولا' &&
        secondSpoken == 'علكم') {
      return true;
    }
    if (expectedWord == 'اقترفتموها' &&
        firstSpoken == 'وترفتموها') {
      return false;
    }
    if (expectedWord == 'سلمتم' &&
        firstSpoken == 'سن' &&
        secondSpoken == 'لمتم') {
      return true;
    }
    if (expectedWord == 'وقثائها' &&
        (firstSpoken == 'وقدا' || _foldNearMiss(firstSpoken) == 'فاذا') &&
        _foldNearMiss(secondSpoken) == 'اها') {
      return true;
    }
    if (expectedWord == 'وعربي' &&
        firstSpoken == 'أهحجمي') {
      return false;
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
    if (expectedWord.endsWith('ن') &&
        nextExpectedWord.length >= 5 &&
        nextExpectedWord.startsWith('ت') &&
        firstSpoken == '$expectedWordت' &&
        _foldNearMiss(secondSpoken) ==
            _foldNearMiss('ا${nextExpectedWord.substring(1)}')) {
      return true;
    }
    if (expectedWord == 'أو' &&
        nextExpectedWord.length >= 5 &&
        nextExpectedWord.startsWith('لا') &&
        _foldAlifMaqsuraToAlif(firstSpoken) == 'اولا' &&
        secondSpoken == nextExpectedWord.substring(2)) {
      return true;
    }
    if (expectedWord == 'فيما' &&
        (nextExpectedWord == 'أن' || nextExpectedWord == 'إن') &&
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
    if (expectedWord == 'كل' &&
        nextExpectedWord == 'أناس' &&
        firstSpoken == 'علمكم' &&
        secondSpoken == 'نؤناس') {
      return true;
    }
    if (expectedWord.length < 3) return false;
    if (expectedWord == 'ثلثي' &&
        nextExpectedWord == 'الليل' &&
        (firstSpoken == 'ثلث' ||
            firstSpoken == 'ثلاث' ||
            firstSpoken == 'سلس') &&
        (_foldNearMiss(secondSpoken) == 'اليل' ||
            _foldNearMiss(secondSpoken) == 'الين' ||
            secondSpoken == 'الليل')) {
      return true;
    }
    if (expectedWord == 'مصر' &&
        nextExpectedWord == 'لامرأته' &&
        firstSpoken == 'مصرن' &&
        _foldNearMiss(secondSpoken) == 'امراته') {
      return true;
    }
    if (expectedWord == 'تؤذوا' &&
        nextExpectedWord == 'رسول' &&
        firstSpoken == 'تؤذر' &&
        secondSpoken == 'سول') {
      return true;
    }
    if (expectedWord == 'غير' &&
        nextExpectedWord == 'ناظرين' &&
        firstSpoken == 'غيرنا' &&
        (secondSpoken == 'ضرين' || secondSpoken == 'ظرين')) {
      return true;
    }
    if (expectedWord == 'وأخر' &&
        nextExpectedWord == 'متشابهات' &&
        firstSpoken == 'وأخروا' &&
        secondSpoken == 'تشابهات') {
      return true;
    }
    if (expectedWord == 'وسع' &&
        nextExpectedWord == 'كرسيه' &&
        (firstSpoken == 'وسعقوا' ||
            firstSpoken == 'وسعقر' ||
            firstSpoken == 'وسعطوا' ||
            firstSpoken == 'وسعطر') &&
        secondSpoken == 'سيه') {
      return true;
    }
    if (expectedWord == 'وابتغاء' &&
        nextExpectedWord == 'تأويله' &&
        firstSpoken == 'وابتغاءة' &&
        _foldNearMiss(secondSpoken) == 'اويله') {
      return true;
    }
    if (expectedWord == 'ولعبد' &&
        nextExpectedWord == 'مؤمن' &&
        firstSpoken == 'ولعبدوا' &&
        _foldNearMiss(secondSpoken) == 'انمومن') {
      return true;
    }
    if (expectedWord == 'آياته' &&
        nextExpectedWord == 'للناس' &&
        _foldNearMiss(firstSpoken) == 'اين' &&
        secondSpoken == 'الناس') {
      return true;
    }
    if (expectedWord == 'النار' &&
        nextExpectedWord == 'وعدها' &&
        _foldNearMiss(firstSpoken) == 'انا' &&
        (secondSpoken == 'روعدها' || secondSpoken == 'رعدها')) {
      return true;
    }
    if (expectedWord == 'قتلنا' &&
        nextExpectedWord == 'هاهنا' &&
        firstSpoken == 'قتلناها' &&
        _foldAlifMaqsuraToAlif(secondSpoken) == 'هنا') {
      return true;
    }
    if (expectedWord == 'الإنجيل' &&
        nextExpectedWord == 'كزرع' &&
        _foldNearMiss(firstSpoken) == 'انجيلك' &&
        secondSpoken == 'زرع') {
      return true;
    }
    if (expectedWord == 'أعوذ' &&
        nextExpectedWord == 'بالله' &&
        ((_foldNearMiss(firstSpoken) == 'ابوض' ||
                    _foldNearMiss(firstSpoken) == 'ابوح') &&
                secondSpoken == 'لله' ||
            (_foldNearMiss(firstSpoken) == 'انهم' &&
                secondSpoken == 'الله'))) {
      return true;
    }
    if (expectedWord == 'أرسلت' &&
        nextExpectedWord == 'به' &&
        _foldNearMiss(firstSpoken) == 'ارسلتم' &&
        secondSpoken == 'في') {
      return true;
    }
    if (expectedWord == 'هن' &&
        nextExpectedWord == 'حل' &&
        firstSpoken == 'هم' &&
        secondSpoken == 'محل') {
      return true;
    }
    if (expectedWord == 'منها' &&
        nextExpectedWord == 'لما' &&
        firstSpoken == 'من' &&
        secondSpoken == 'عالما') {
      return true;
    }
    if (expectedWord == 'بالبينات' &&
        nextExpectedWord == 'فردوا' &&
        (firstSpoken == 'فينادف' || firstSpoken == 'بالبينات') &&
        secondSpoken == 'ردوا') {
      return true;
    }
    if (expectedWord == 'فلهن' &&
        nextExpectedWord == 'ثلثا' &&
        firstSpoken == 'فله' &&
        secondSpoken == 'النفلثا') {
      return true;
    }
    if (expectedWord == 'فلهن' &&
        nextExpectedWord == 'الثمن' &&
        ((firstSpoken == 'فلهم' && secondSpoken == 'نستمن') ||
            (firstSpoken == 'فله' &&
                (secondSpoken == 'النسل' || secondSpoken == 'النفسول')))) {
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
        (firstSpoken == 'زجاجتك' || firstSpoken == 'وجاجتك') &&
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
        !(lastChar == 'ى' && firstSpoken.endsWith('ي')) &&
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
    if (nextExpectedWord.length >= 3 &&
        !(lastChar == 'ى' &&
            (firstSpoken.endsWith('ي') ||
                firstSpoken.endsWith('يت') ||
                firstSpoken.endsWith('يتم') ||
                firstSpoken.endsWith('ينا') ||
                firstSpoken.endsWith('ين')))) {
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
    ('ط', 'ظ'),
    ('ظ', 'ط'),
    ('غ', 'ر'),
    ('ر', 'غ'),
    ('ي', 'م'),
    ('م', 'ي'),
  };

  static const _confusableInitialConsonantPairs = {
    ('ص', 'س'),
    ('س', 'ص'),
    ('ص', 'ف'),
    ('ذ', 'ز'),
    ('ز', 'ذ'),
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
        if (diffIndex == expectedWord.length - 1 &&
            expectedWord.length >= 5 &&
            expectedWord.startsWith('ال')) {
          return _confusableConsonantPairs.contains((
            expectedWord[diffIndex],
            spokenWord[diffIndex],
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

  static final RegExp _harakat = RegExp(r'[\u064B-\u065F\u0670]');
  static final RegExp _shortVowelMarks = RegExp(
    r'[\u064B-\u0650\u0670]',
  );

  List<String> _vocalizedWords(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[\u0610-\u061A\u06D6-\u06ED\u0640]'), '')
        .replaceAll('\u0671', '\u0627')
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u2069]'), '')
        .replaceAll(RegExp(r'[.,!?:;،؛؟]'), ' ')
        .trim();
    if (cleaned.isEmpty) return [];
    return [
      for (final token in cleaned.split(RegExp(r'\s+')))
        if (token.replaceAll(_harakat, '').isNotEmpty) token,
    ];
  }

  List<(String, String?)> _extractLetterVowels(String word) {
    final result = <(String, String?)>[];
    String? curChar;
    String? curVowel;
    for (var i = 0; i < word.length; i++) {
      final ch = word[i];
      if (ch == '\u064E' || ch == '\u064B' || ch == '\u0670') {
        curVowel = 'F';
      } else if (ch == '\u0650' || ch == '\u064D') {
        curVowel = 'K';
      } else if (ch == '\u064F' || ch == '\u064C') {
        curVowel = 'D';
      } else if (ch == '\u0652') {
        curVowel ??= 'S';
      } else {
        final code = ch.codeUnitAt(0);
        if ((code >= 0x0621 && code <= 0x064A) || ch == 'ٱ' || ch == 'ى') {
          if (curChar != null) {
            result.add((curChar, curVowel));
          }
          var norm = ch;
          if (ch == 'أ' || ch == 'إ' || ch == 'آ' || ch == 'ٱ') {
            norm = 'ا';
          } else if (ch == 'ؤ') {
            norm = 'و';
          } else if (ch == 'ئ') {
            norm = 'ي';
          } else if (ch == 'ة') {
            norm = 'ه';
          }
          curChar = norm;
          curVowel = null;
        }
      }
    }
    if (curChar != null) {
      result.add((curChar, curVowel));
    }
    return result;
  }

  List<(String, String?)> _dropMedialAlifs(List<(String, String?)> letters) {
    final out = <(String, String?)>[];
    for (var idx = 0; idx < letters.length; idx++) {
      final isLast = idx == letters.length - 1;
      final (ch, v) = letters[idx];
      if (!isLast &&
          (ch == 'ا' || ch == 'ى') &&
          v == null &&
          out.isNotEmpty &&
          out.last.$2 == 'F') {
        continue;
      }
      if (!isLast &&
          ch == 'ي' &&
          (v == null || v == 'S') &&
          out.isNotEmpty &&
          out.last.$2 == 'K') {
        out[out.length - 1] = (out.last.$1, 'F');
        out.add((ch, 'S'));
        continue;
      }
      out.add((ch, v));
    }
    return out;
  }

  bool _vowelsConflict(String? ev, String? fv) =>
      (ev == 'F' || ev == 'K' || ev == 'D') &&
      (fv == 'F' || fv == 'K' || fv == 'D') &&
      ev != fv;

  bool _hasHarakahConflict(String expectedVocalized, String spokenVocalized) {
    if (!_shortVowelMarks.hasMatch(spokenVocalized) ||
        !_shortVowelMarks.hasMatch(expectedVocalized)) {
      return false;
    }
    final el = _dropMedialAlifs(_extractLetterVowels(expectedVocalized));
    final fl = _dropMedialAlifs(_extractLetterVowels(spokenVocalized));
    if (el.isEmpty || el.length != fl.length) return false;
    for (var i = 0; i < el.length; i++) {
      if (el[i].$1 != fl[i].$1) return false;
    }
    final skelE = [for (final (c, _) in el) c].join();
    if (skelE == 'ضعف' ||
        skelE == 'ضعفا' ||
        skelE == 'بورقكم' ||
        skelE == 'يضلل' ||
        skelE == 'ذراعيه' ||
        skelE == 'رعبا') {
      return false;
    }

      for (var i = 0; i < el.length; i++) {
      if (_vowelsConflict(el[i].$2, fl[i].$2)) {
        // Whisper frequently hallucinates final-letter case vowels or tanween
        // on longer nouns/particles, especially on taa marbuta ('ة' -> 'ه') or
        // tanween alif ('ً' + 'ا', e.g. 'آلِهَةٌ'/'آلِهَةٍ' for 'آلِهَةً',
        // 'رَحْمَةٍ' for 'رَحْمَةً', 'أَحَدٌ' for 'أَحَدًا').
        final isTanweenFathaEnding =
            expectedVocalized.endsWith('ًا') ||
            expectedVocalized.endsWith('اً');
        if (i == el.length - 1 &&
            (el[i].$1 == 'ه' || isTanweenFathaEnding)) {
          continue;
        }
        // Guard against Whisper labial vowel harmony before attached '-هُم'
        // (e.g. 'أَطْعَمَهُم' transcribed as 'أَطْعَمُهُمْ').
        if (i + 2 == el.length - 1 &&
            el[i + 1].$1 == 'ه' &&
            el[i + 2].$1 == 'م' &&
            el[i + 1].$2 == 'D' &&
            fl[i].$2 == 'D') {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  List<String> _applyHarakahConflicts(
    List<String> rawSpoken,
    List<String> rawVocalized,
    List<String> expectedAyahs,
    List<String>? keys,
  ) {
    if (rawSpoken.isEmpty ||
        rawSpoken.length != rawVocalized.length ||
        expectedAyahs.isEmpty ||
        !rawVocalized.any(_shortVowelMarks.hasMatch)) {
      return rawSpoken;
    }
    final entries = <({
      String written,
      String folded,
      String vocalized,
      String? prevFolded,
      String? nextFolded,
    })>[];
    final allWritten = <String>[];
    final allVocalized = <String>[];
    for (final ayahText in expectedAyahs) {
      final wWords = _recitationWords(ayahText);
      final vWords = _vocalizedWords(ayahText);
      if (wWords.length != vWords.length) continue;
      allWritten.addAll(wWords);
      allVocalized.addAll(vWords);
    }
    if (allWritten.isEmpty) return rawSpoken;
    for (var idx = 0; idx < allWritten.length; idx++) {
      entries.add((
        written: allWritten[idx],
        folded: _foldAlifMaqsuraToAlif(allWritten[idx]),
        vocalized: allVocalized[idx],
        prevFolded: idx > 0
            ? _foldAlifMaqsuraToAlif(allWritten[idx - 1])
            : null,
        nextFolded: idx + 1 < allWritten.length
            ? _foldAlifMaqsuraToAlif(allWritten[idx + 1])
            : null,
      ));
    }

    final result = List<String>.of(rawSpoken);
    for (var i = 0; i < rawSpoken.length; i++) {
      final vToken = rawVocalized[i];
      if (!_shortVowelMarks.hasMatch(vToken)) continue;
      final sFolded = _foldAlifMaqsuraToAlif(rawSpoken[i]);
      final prevSpokenFolded = i > 0
          ? _foldAlifMaqsuraToAlif(rawSpoken[i - 1])
          : null;
      final nextSpokenFolded = i + 1 < rawSpoken.length
          ? _foldAlifMaqsuraToAlif(rawSpoken[i + 1])
          : null;

      // Check 2-to-1 split word merges first (e.g. 'رَبِّكِ' + 'مَا' -> 'ربكما')
      if (i + 1 < rawSpoken.length) {
        final mergedSpoken = '${rawSpoken[i]}${rawSpoken[i + 1]}';
        final mergedFolded = _foldAlifMaqsuraToAlif(mergedSpoken);
        final isRabbiKumaSplit =
            (rawSpoken[i] == 'رب' ||
                rawSpoken[i] == 'ربي' ||
                rawSpoken[i] == 'ربك') &&
            (rawSpoken[i + 1] == 'كما' ||
                rawSpoken[i + 1] == 'كم' ||
                rawSpoken[i + 1] == 'ما');
        final splitMatches = [
          for (final e in entries)
            if (e.folded == mergedFolded ||
                (isRabbiKumaSplit && e.folded == 'ربكما'))
              e,
        ];
        if (splitMatches.isNotEmpty) {
          final mergedVocalized = '${rawVocalized[i]}${rawVocalized[i + 1]}';
          if (splitMatches.every(
            (e) => _hasHarakahConflict(e.vocalized, mergedVocalized),
          )) {
            result[i] = vToken;
            continue;
          }
        }
      }

      var candidates = [
        for (final e in entries)
          if (e.folded == sFolded) e,
      ];
      if (candidates.length > 1 &&
          (prevSpokenFolded != null || nextSpokenFolded != null)) {
        final neighborMatched = [
          for (final e in candidates)
            if ((prevSpokenFolded != null &&
                    e.prevFolded == prevSpokenFolded) ||
                (nextSpokenFolded != null && e.nextFolded == nextSpokenFolded))
              e,
        ];
        if (neighborMatched.isNotEmpty) {
          candidates = neighborMatched;
        }
      }
      if (candidates.isEmpty && sFolded.length >= 3) {
        candidates = [
          for (final e in entries)
            if (_isOrthographicNearMiss(e.written, rawSpoken[i]) ||
                _isThreeLetterFlankedNearMiss(e.written, rawSpoken[i]) ||
                (e.folded.length == sFolded.length &&
                    _singleDiffOrLess(e.folded, sFolded)) ||
                (e.folded == 'ربكما' && e.folded.startsWith(sFolded)) ||
                (e.folded == 'تكذبان' &&
                    (sFolded.startsWith('تكذب') || sFolded.endsWith('كذبان'))))
              e,
        ];
      }
      if (candidates.isNotEmpty &&
          candidates.every((e) => _hasHarakahConflict(e.vocalized, vToken))) {
        result[i] = vToken;
      }
    }
    return result;
  }

  bool _singleDiffOrLess(String a, String b) {
    if (a.length != b.length) return false;
    var diffs = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        diffs++;
        if (diffs > 1) return false;
      }
    }
    return true;
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
