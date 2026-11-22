import 'dart:math' as math;
import 'dart:typed_data';

/// One expected ayah: its reference words in TajweedFormer unit ids
/// (`model.reference`) and its ordinary-spelling recitation words.
class TajweedExpectedAyah {
  final List<List<int>> referenceWords;
  final List<String> textWords;

  const TajweedExpectedAyah({
    required this.referenceWords,
    required this.textWords,
  });

  /// Splits `TajweedAyahUnits` into words, dropping the word bar.
  static List<List<int>> splitUnits(
    List<int> units,
    List<int> wordStarts, {
    int wordBar = TajweedRecitationAligner.wordBar,
  }) {
    final words = <List<int>>[];
    for (var i = 0; i < wordStarts.length; i++) {
      final start = wordStarts[i];
      final end = i + 1 < wordStarts.length ? wordStarts[i + 1] : units.length;
      final word = [
        for (var j = start; j < end && j < units.length; j++)
          if (units[j] != wordBar && units[j] != TajweedRecitationAligner.blank)
            units[j],
      ];
      if (word.isNotEmpty) words.add(word);
    }
    return words;
  }
}

/// Turns what TajweedFormer heard (a stream of phonetic units) into the app's
/// Arabic recitation words, so the existing memorization comparison can judge
/// them.
///
/// The heard units are aligned to the expected ayahs' reference units. Each
/// expected word whose aligned units are close enough gives the expected
/// spelling; any other word is spelled from what was heard there, so the
/// comparison sees a different word, and a word not heard at all is left out.
class TajweedRecitationAligner {
  static const blank = 0;
  static const wordBar = 1;
  static const hamza = 2;
  static const nun = 26;
  static const nasal = 30;
  static const foreign = 37;

  /// The TajweedFormer V4 vocabulary (quran-g2p `tokenizer_tj3/tokens.txt`).
  static const tj3Names = [
    '<blk>', '|', 'ء', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', //
    'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', //
    'ه', 'و', 'ي', 'ں', 'a', 'i', 'u', 'aa', 'ii', 'uu', '<foreign>',
  ];

  /// أعوذ بالله من الشيطان الرجيم, as recited before an ayah.
  static const isti3adha = [
    2, 31, 19, 36, 10, 33, 3, 32, 24, 34, 27, 32, 25, 32, 26, 31, 14, 31, //
    29, 17, 34, 26, 32, 11, 31, 6, 35, 25,
  ];

  static const _resumeSkipCost = 0.02;
  static const _restartCost = 0.5;
  static const _openingTolerance = 0.2;
  static const _commitKeepUnits = 80;
  static const _forcedCommitUnits = 400;
  static const _windowSlack = 300;

  final List<int> _ref = [];
  final List<int> _wordStart = [];
  final List<int> _wordEnd = [];
  final List<int> _wordOfUnit = [];
  final List<int> _consonants = [];
  final List<List<String>> _spelling = [];

  /// Recited before the ayahs and not judged (isti'adha by default).
  final List<List<int>> openings;

  final List<String> _committedText = [];
  int _committedHeard = 0;
  int _committedWord = 0;

  /// Each judged word's alignment cost on the last [align], for diagnostics.
  final List<double> lastWordCosts = [];

  TajweedRecitationAligner(
    List<TajweedExpectedAyah> ayahs, {
    this.openings = const [isti3adha],
  }) {
    for (final ayah in ayahs) {
      final refCount = ayah.referenceWords.length;
      final textCount = ayah.textWords.length;
      for (var k = 0; k < refCount; k++) {
        final word = ayah.referenceWords[k];
        final index = _wordStart.length;
        _wordStart.add(_ref.length);
        for (final unit in word) {
          _ref.add(unit);
          _wordOfUnit.add(index);
        }
        _wordEnd.add(_ref.length);
        _consonants.add(word.where((u) => !_isLight(u)).length);
        final from = refCount == textCount ? k : k * textCount ~/ refCount;
        final to = refCount == textCount
            ? k + 1
            : (k + 1) * textCount ~/ refCount;
        _spelling.add(ayah.textWords.sublist(from, to));
      }
    }
  }

  int get expectedWordCount => _wordStart.length;

  bool get _started => _committedHeard > 0;

  /// The recitation text for the take so far. [heard] holds every unit of the
  /// take (blank and word bar left out); [settledUnits] how many leading units
  /// will not change any more.
  String align(List<int> heard, {required bool isFinal, int settledUnits = 0}) {
    lastWordCosts.clear();
    var from = _committedHeard;
    if (!_started) {
      final opening = _skipOpenings(heard, isFinal: isFinal);
      if (opening == null) return '';
      from = opening;
    }
    final tail = heard.sublist(math.min(from, heard.length));
    final result = _alignTail(tail, isFinal: isFinal);
    final text = [..._committedText, ...result.words].join(' ');
    final settledInTail = tail.length > _forcedCommitUnits
        ? math.max(settledUnits - from, tail.length - _forcedCommitUnits ~/ 2)
        : settledUnits - from;
    _commit(result, from, settledInTail - _commitKeepUnits);
    return text;
  }

  /// Where the ayahs begin in [heard] after any isti'adha or basmala; null
  /// while the take may still be inside one.
  int? _skipOpenings(List<int> heard, {required bool isFinal}) {
    var position = 0;
    final used = <int>{};
    var progressed = true;
    while (progressed) {
      progressed = false;
      for (var k = 0; k < openings.length; k++) {
        if (used.contains(k)) continue;
        final opening = openings[k];
        if (_startsWith(_ref, 0, opening)) continue;
        final rest = heard.length - position;
        if (rest <= 0) return isFinal ? position : null;
        final match = _prefixMatch(heard, position, opening);
        if (match.cost <= _openingTolerance * opening.length) {
          position = match.end;
          used.add(k);
          progressed = true;
          break;
        }
        if (!isFinal &&
            rest < opening.length &&
            match.headCost <= _openingTolerance * math.max(4, rest)) {
          return null;
        }
      }
    }
    return position;
  }

  /// Whether [units] from [at] is within tolerance of [opening]'s start.
  bool _startsWith(List<int> units, int at, List<int> opening) {
    if (units.length - at < opening.length) return false;
    return _prefixMatch(units, at, opening).cost <=
        _openingTolerance * opening.length;
  }

  /// The cheapest alignment of all of [pattern] to a prefix of [units] from
  /// [at] (end: where it ends in [units]), and [headCost]: the cheapest of
  /// all the rest of [units] to a prefix of [pattern].
  ({double cost, int end, double headCost}) _prefixMatch(
    List<int> units,
    int at,
    List<int> pattern,
  ) {
    final n = math.min(units.length - at, pattern.length * 2);
    final m = pattern.length;
    var previous = List<double>.generate(m + 1, (j) {
      var total = 0.0;
      for (var k = 0; k < j; k++) {
        total += _gap(pattern[k]);
      }
      return total;
    });
    var best = previous[m];
    var bestEnd = at;
    for (var i = 1; i <= n; i++) {
      final unit = units[at + i - 1];
      final current = List<double>.filled(m + 1, 0);
      current[0] = previous[0] + _gap(unit);
      for (var j = 1; j <= m; j++) {
        current[j] = math.min(
          math.min(
            previous[j] + _gap(unit),
            current[j - 1] + _gap(pattern[j - 1]),
          ),
          previous[j - 1] + _substitute(unit, pattern[j - 1]),
        );
      }
      previous = current;
      if (previous[m] < best) {
        best = previous[m];
        bestEnd = at + i;
      }
    }
    return (cost: best, end: bestEnd, headCost: previous.reduce(math.min));
  }

  void _commit(_TailResult result, int from, int limit) {
    if (limit <= 0) return;
    var last = -1;
    for (var k = 0; k < result.judged.length - 1; k++) {
      if (result.judged[k].heardEnd > limit) break;
      last = k;
    }
    if (last < 0) return;
    final word = result.judged[last];
    _committedText.addAll(result.words.sublist(0, word.outputEnd));
    _committedHeard = from + word.heardEnd;
    _committedWord = word.word + 1;
  }

  _TailResult _alignTail(List<int> heard, {required bool isFinal}) {
    final n = heard.length;
    final base = _committedWord < _wordStart.length
        ? _wordStart[_committedWord]
        : _ref.length;
    final m = math.min(_ref.length - base, (n * 1.5).ceil() + _windowSlack);
    if (n == 0) return const _TailResult([], []);
    if (m <= 0) {
      return _TailResult(isFinal ? [spell(heard)] : const [], const []);
    }
    final width = m + 1;
    final cost = Float64List((n + 1) * width);
    final back = Uint8List((n + 1) * width);
    final restartFrom = Int32List((n + 1) * width);
    for (var j = 1; j <= m; j++) {
      final r = base + j - 1;
      final delete = cost[j - 1] + _gap(_ref[r]);
      cost[j] = delete;
      back[j] = _delete;
      if (!_started) {
        final atWordStart = j < m && _wordStart[_wordOfUnit[r + 1]] == r + 1;
        if (atWordStart) {
          final skip = (_wordOfUnit[r + 1] - _committedWord) * _resumeSkipCost;
          if (skip < delete) {
            cost[j] = skip;
            back[j] = _skip;
          }
        }
      }
    }
    for (var i = 1; i <= n; i++) {
      final h = heard[i - 1];
      final insert = _gap(h);
      final row = i * width;
      final up = row - width;
      cost[row] = cost[up] + insert;
      back[row] = _insert;
      for (var j = 1; j <= m; j++) {
        final r = _ref[base + j - 1];
        var best = cost[up + j - 1] + _substitute(h, r);
        var move = _match;
        final ins = cost[up + j] + insert;
        if (ins < best) {
          best = ins;
          move = _insert;
        }
        final del = cost[row + j - 1] + _gap(r);
        if (del < best) {
          best = del;
          move = _delete;
        }
        cost[row + j] = best;
        back[row + j] = move;
      }
      // A reciter may go back to an earlier word and repeat from there.
      var later = double.infinity;
      var laterJ = 0;
      for (var j = m; j >= 0; j--) {
        final here = cost[row + j];
        final atWordStart =
            j < m && _wordStart[_wordOfUnit[base + j]] == base + j;
        if (atWordStart && later + _restartCost < here) {
          cost[row + j] = later + _restartCost;
          back[row + j] = _restart;
          restartFrom[row + j] = laterJ;
        }
        if (here < later) {
          later = here;
          laterJ = j;
        }
      }
      for (var j = 1; j <= m; j++) {
        final del = cost[row + j - 1] + _gap(_ref[base + j - 1]);
        if (del < cost[row + j]) {
          cost[row + j] = del;
          back[row + j] = _delete;
        }
      }
    }
    final last = n * width;
    var endJ = 0;
    for (var j = 1; j <= m; j++) {
      if (cost[last + j] < cost[last + endJ]) endJ = j;
    }

    final firstWord = _wordStart.length;
    final wordCost = <int, double>{};
    final heardFirst = <int, int>{};
    final heardEnd = <int, int>{};
    var startJ = 0;
    var abandonFrom = firstWord;
    var i = n;
    var j = endJ;
    while (i > 0 || j > 0) {
      final move = back[i * width + j];
      if (move == _skip) {
        startJ = j;
        break;
      }
      if (move == _restart) {
        // Words from here on were recited again later; judge the later pass.
        abandonFrom = math.min(abandonFrom, _wordOfUnit[base + j]);
        j = restartFrom[i * width + j];
        continue;
      }
      final column = move == _insert ? math.max(j, 1) : j;
      final word = column == 0
          ? _committedWord
          : _wordOfUnit[base + column - 1];
      final before =
          cost[(move == _delete ? i : i - 1) * width +
              (move == _insert ? j : j - 1)];
      if (word < abandonFrom) {
        wordCost[word] = (wordCost[word] ?? 0) + cost[i * width + j] - before;
        if (move != _delete) {
          heardFirst[word] = i - 1;
          heardEnd.putIfAbsent(word, () => i);
        }
      }
      switch (move) {
        case _match:
          i--;
          j--;
        case _insert:
          i--;
        default:
          j--;
      }
    }
    if (endJ == startJ) {
      return _TailResult(isFinal ? [spell(heard)] : const [], const []);
    }
    final first = _wordOfUnit[base + startJ];
    final lastWord = _wordOfUnit[base + endJ - 1];
    final words = <String>[];
    final judged = <_JudgedWord>[];
    var heardDone = 0;
    for (var w = math.min(first, firstWord); w <= lastWord; w++) {
      if (w < first) continue;
      final partial = w == lastWord && base + endJ < _wordEnd[w];
      if (partial && !isFinal) break;
      var d = wordCost[w] ?? 0;
      if (partial) {
        for (var r = base + endJ; r < _wordEnd[w]; r++) {
          d += _gap(_ref[r]);
        }
      }
      lastWordCosts.add(d);
      final similar = d <= _allowed(w);
      if (!similar && w == lastWord && !isFinal) break;
      final start = heardFirst[w];
      final end = heardEnd[w];
      if (similar) {
        words.addAll(_spelling[w]);
      } else if (start != null &&
          end != null &&
          heard.sublist(start, end).any(_isConsonant)) {
        words.add(spell(heard.sublist(start, end)));
      }
      if (end != null) heardDone = end;
      judged.add(_JudgedWord(w, heardDone, words.length));
    }
    return _TailResult(words, judged);
  }

  static const _match = 1;
  static const _insert = 2;
  static const _delete = 3;
  static const _skip = 4;
  static const _restart = 5;

  /// How much a word may differ from its reference: vowel length, a stop
  /// form or a nasal, never a different consonant in a short word.
  double _allowed(int word) {
    final consonants = _consonants[word];
    if (consonants <= 2) return 0.5;
    if (consonants <= 4) return 0.75;
    return 1.0;
  }

  static bool _isVowel(int unit) => unit >= 31 && unit <= 36;

  static bool _isConsonant(int unit) => unit >= 3 && unit <= 29;

  static bool _isLight(int unit) =>
      unit == hamza || unit == nasal || unit == foreign || _isVowel(unit);

  static double _gap(int unit) => _isLight(unit) ? 0.5 : 1.0;

  static double _substitute(int a, int b) {
    if (a == b) return 0;
    if (_isVowel(a) && _isVowel(b)) {
      return (a - 31) % 3 == (b - 31) % 3 ? 0.25 : 0.5;
    }
    if ((a == nasal && b == nun) || (a == nun && b == nasal)) return 0.25;
    return math.max(_gap(a), _gap(b));
  }

  /// Heard units written with their own consonants and long vowels.
  static String spell(List<int> units) {
    final buffer = StringBuffer();
    for (final unit in units) {
      buffer.write(switch (unit) {
        nasal => 'ن',
        34 => 'ا',
        35 => 'ي',
        36 => 'و',
        >= 2 && <= 29 => tj3Names[unit],
        _ => '',
      });
    }
    return buffer.isEmpty ? 'ء' : buffer.toString();
  }
}

class _JudgedWord {
  final int word;
  final int heardEnd;
  final int outputEnd;

  const _JudgedWord(this.word, this.heardEnd, this.outputEnd);
}

class _TailResult {
  final List<String> words;
  final List<_JudgedWord> judged;

  const _TailResult(this.words, this.judged);
}
