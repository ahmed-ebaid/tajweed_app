/// Provides word-by-word comparison between the user's spoken text
/// (from speech-to-text) and the expected Quranic text for an ayah.
///
/// Text matching does not assess pronunciation or Tajweed.
class SpeechComparisonService {
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
    List<String> words(String text) => _spokenWords(
      text,
      expectedAyahs,
      expectedVerseKeys,
      allowWrittenOpenings,
    );
    final retained = words(retainedPrefix);
    final incoming = words(spokenText);
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
    if (allowWrittenOpenings && incoming.length >= 2 && retained.isNotEmpty) {
      final skipped = incoming.skip(1).toList();
      final maxSkippedOverlap = retained.length < skipped.length
          ? retained.length
          : skipped.length;
      for (var overlap = maxSkippedOverlap; overlap > 0; overlap--) {
        var matches = true;
        for (var i = 0; i < overlap; i++) {
          if (retained[retained.length - overlap + i] != skipped[i]) {
            matches = false;
            break;
          }
        }
        if (matches) {
          return _spokenWords(
            [...retained, ...skipped.skip(overlap)].join(' '),
            expectedAyahs,
            expectedVerseKeys,
            allowWrittenOpenings,
          ).join(' ');
        }
      }
    }
    if (allowWrittenOpenings &&
        incoming.length >= 2 &&
        retained.length > incoming.length) {
      for (
        var start = 0;
        start <= retained.length - incoming.length;
        start++
      ) {
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

  /// Evaluate a final recognition segment against consecutive ayahs. Partial
  /// native hypotheses must not be committed: the recognizer can revise them.
  RecitationSequenceCheck checkSequence({
    required List<String> expectedAyahs,
    required String spokenText,
    List<String>? expectedVerseKeys,
    bool allowWrittenOpenings = false,
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
  }) {
    final expected = _expectedRecitationWords(expectedImlaei, expectedVerseKey);
    final spoken = _spokenWords(
      spokenText,
      [expectedImlaei],
      expectedVerseKey == null ? null : [expectedVerseKey],
      allowWrittenOpenings,
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
    bool allowWrittenOpenings,
  ) {
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
      if (opening != null &&
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
      while (word < expected.length && offset < spoken.length) {
        if (expected[word].contains(spoken[offset])) {
          expanded.add(spoken[offset++]);
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
        if (_matchesMaqsuraToHamzaEnding(
          expected[word].first,
          spoken[offset],
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
        if (word == expected.length - 1 &&
            word > 0 &&
            _matchesQalqalahPauseEnding(
              expected[word].first,
              spoken[offset],
            )) {
          expanded.add(expected[word].first);
          offset++;
          word++;
          continue;
        }
        return [...expanded, ...spoken.skip(offset)];
      }
      if (word < expected.length) break;
    }
    if (offset < spoken.length && expectedAyahs.isNotEmpty) {
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
    if (expectedWord.length >= 5 &&
        spokenWord == '$expectedWordوا' &&
        nextExpectedWord.isNotEmpty) {
      return true;
    }
    return false;
  }

  bool _matchesQalqalahPauseEnding(String expectedWord, String spokenWord) {
    if (expectedWord.length < 3) return false;
    final last = expectedWord[expectedWord.length - 1];
    if (last != 'ب' && last != 'ق' && last != 'ط' && last != 'ج' && last != 'د') {
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
  };

  static const _confusableInitialConsonantPairs = {
    ('ص', 'س'),
    ('س', 'ص'),
    ('ص', 'ف'),
    ('ا', 'إ'),
    ('إ', 'ا'),
    ('ا', 'أ'),
    ('أ', 'ا'),
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
      for (var i = 2; i < expectedWord.length - 1; i++) {
        if (expectedWord[i] != 'ا') continue;
        final withoutMedialAlif =
            expectedWord.substring(0, i) + expectedWord.substring(i + 1);
        if (withoutMedialAlif == spokenWord) return true;
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
