/// Provides word-by-word comparison between the user's spoken text
/// (from speech-to-text) and the expected Quranic text for an ayah.
///
/// This works alongside Tarteel's tajweed scoring to help users
/// identify exactly which words they mispronounced or skipped.
class SpeechComparisonService {
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
          matches.add(WordMatch(
            expected: expected,
            spoken: spoken,
            status: similarity >= 0.9
                ? WordStatus.correct
                : WordStatus.partial,
            similarity: similarity,
          ));
          spokenIdx++;
        } else {
          // Check if the next spoken word matches (user may have inserted extra)
          if (spokenIdx + 1 < spokenWords.length &&
              _similarity(expected, spokenWords[spokenIdx + 1]) >= 0.7) {
            spokenIdx++; // skip the extra word
            matches.add(WordMatch(
              expected: expected,
              spoken: spokenWords[spokenIdx],
              status: WordStatus.partial,
              similarity: _similarity(expected, spokenWords[spokenIdx]),
            ));
            spokenIdx++;
          } else {
            matches.add(WordMatch(
              expected: expected,
              spoken: spoken,
              status: WordStatus.missed,
              similarity: similarity,
            ));
          }
        }
      } else {
        // User stopped early — remaining words are missing
        matches.add(WordMatch(
          expected: expected,
          spoken: '',
          status: WordStatus.missed,
          similarity: 0.0,
        ));
      }
    }

    final correctCount =
        matches.where((m) => m.status == WordStatus.correct).length;
    final overallAccuracy =
        matches.isEmpty ? 0.0 : correctCount / matches.length;

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
