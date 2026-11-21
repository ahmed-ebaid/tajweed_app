import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/services/memorization_speech_service.dart';
import '../../core/services/quran_asr_speech_input.dart';
import '../../core/services/hifz_content_service.dart';
import '../../core/services/speech_comparison_service.dart';
import 'mushaf_page_view.dart';

class MemorizationScreen extends StatefulWidget {
  final List<Ayah> ayahs;
  final String Function(int) surahNameFor;
  final Future<bool> Function(Ayah) playReference;
  final Future<void> Function() stopReference;
  final ValueListenable<bool>? referencePlayingListenable;
  final MemorizationSpeechInput? speechInput;
  final Future<List<Ayah>> Function(int)? loadPage;
  final bool continuous;
  final bool review;
  final bool localQuranLab;

  const MemorizationScreen({
    super.key,
    required this.ayahs,
    required this.surahNameFor,
    required this.playReference,
    required this.stopReference,
    this.referencePlayingListenable,
    this.speechInput,
    this.loadPage,
    this.continuous = true,
    this.review = false,
    this.localQuranLab = false,
  }) : assert(ayahs.length > 0);

  static bool isCompleteSurah(
    List<Ayah> ayahs, {
    required int surahNumber,
    required int expectedCount,
  }) {
    return HifzContentService.isCompleteSurah(
      ayahs,
      surahNumber: surahNumber,
      expectedCount: expectedCount,
    );
  }

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _HifzMistakeRecord {
  final int ayahIndex;
  final int surahNumber;
  final int ayahNumber;
  final int wordNumber;
  final String expectedWord;

  const _HifzMistakeRecord({
    required this.ayahIndex,
    required this.surahNumber,
    required this.ayahNumber,
    required this.wordNumber,
    required this.expectedWord,
  });
}

class _MemorizationScreenState extends State<MemorizationScreen>
    with WidgetsBindingObserver {
  late final _speech = widget.speechInput ?? MemorizationSpeechService.instance;
  late final _comparison = SpeechComparisonService(
    requireExplicitAlifLamMeem: _speech is! WindowedMemorizationSpeechInput,
  );
  final _revealed = <int>{};
  final _matched = <int>{};
  final _assisted = <int>{};
  final _hintWordCounts = <int, int>{};
  final _mistakes = <_HifzMistakeRecord>[];
  final _preview = <int>{};
  final _liveWordCounts = <String, int>{};
  final _completedLiveWordCounts = <String, int>{};
  final _rollingWordCounts = <String, int>{};
  final _pausedWordCounts = <String, int>{};
  final _navigationWordCounts = <String, int>{};
  final _unverifiedAyahs = <int>{};
  final _acceptedWordCounts = <String, int>{};
  bool _livePreview = false;
  final _pageLoads = <int, Future<List<Ayah>>>{};
  String _pendingText = '';
  String? _lastPreviewText;
  bool _hasStarted = false;
  Future<void> _lastCancellation = Future.value();
  int _index = 0;
  int _generation = 0;
  int? _startingSpeechGeneration;
  bool _consented = false;
  bool _busy = false;
  bool _loadingReference = false;
  bool _playingReference = false;
  bool _acceptResults = false;
  bool _stopInProgress = false;
  bool _finished = false;
  String _transcript = '';
  String _message = 'mem_ready';
  int? _mismatchWord;
  double _pageDragDistance = 0;

  int? _viewedPageOverride;

  Ayah get _ayah => widget.ayahs[_index];
  String get _verseKey => '${_ayah.surahNumber}:${_ayah.ayahNumber}';
  bool get _hasFullUnverifiedPreview =>
      widget.localQuranLab &&
      widget.continuous &&
      !_revealed.contains(_index) &&
      (_pausedWordCounts[_verseKey] ?? 0) >= _currentAyahWordCount;

  int get _nextLabWord {
    final accepted = _acceptedWordCounts[_verseKey] ?? 0;
    final paused = _pausedWordCounts[_verseKey] ?? 0;
    return (accepted > paused ? accepted : paused) + 1;
  }

  int _ayahWordCountAt(int index) {
    final ayah = widget.ayahs[index];
    final recitationCount = _comparison
        .recitationWords(ayah.imlaei ?? ayah.arabic)
        .length;
    return ayah.words.length > recitationCount
        ? ayah.words.length
        : recitationCount;
  }

  int get _currentAyahWordCount => _ayahWordCountAt(_index);

  int _hintBaseWordCountAt(int index) {
    var base = widget.localQuranLab && index == _index ? _nextLabWord - 1 : 0;
    if (widget.localQuranLab) {
      final visible = _effectiveWordCount(index);
      if (visible > base) base = visible;
    }
    final hinted = _hintWordCounts[index] ?? 0;
    if (hinted > base) base = hinted;
    return base;
  }

  int get _hintBaseWordCount => _hintBaseWordCountAt(_index);

  Map<String, int> get _visibleWordCounts {
    final visible = Map<String, int>.of(_pausedWordCounts);
    for (final counts in [
      if (widget.localQuranLab) _acceptedWordCounts,
      if (_livePreview) _liveWordCounts,
    ]) {
      for (final entry in counts.entries) {
        if (!widget.localQuranLab || entry.value > (visible[entry.key] ?? 0)) {
          visible[entry.key] = entry.value;
        }
      }
    }
    return visible;
  }

  bool get _windowed =>
      widget.localQuranLab && _speech is WindowedMemorizationSpeechInput;

  int get _activePageNumber {
    var page = _ayah.pageNumber;
    if (!widget.continuous) return page;
    if (widget.localQuranLab || (_windowed && _acceptResults && _livePreview)) {
      final visible = _visibleWordCounts;
      for (var i = _index; i < widget.ayahs.length; i++) {
        final ayah = widget.ayahs[i];
        final count = visible['${ayah.surahNumber}:${ayah.ayahNumber}'] ?? 0;
        if (count == 0) break;
        page = ayah.pageNumber;
        final length = _comparison.recitationWords(ayah.imlaei ?? '').length;
        if (count < length) break;
        if (i + 1 < widget.ayahs.length) {
          final nextAyah = widget.ayahs[i + 1];
          final nextCount =
              visible['${nextAyah.surahNumber}:${nextAyah.ayahNumber}'] ?? 0;
          if (nextAyah.pageNumber == page || nextCount > 0) {
            page = nextAyah.pageNumber;
          }
        }
      }
    }
    return page;
  }

  int get _visiblePageNumber => _viewedPageOverride ?? _activePageNumber;

  void _clearLiveWords({bool keepRolling = false}) {
    _liveWordCounts.clear();
    _completedLiveWordCounts.clear();
    if (!keepRolling) _rollingWordCounts.clear();
  }

  void _retainRollingWords(int startIndex) {
    for (var i = startIndex; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
      var count = _rollingWordCounts[key] ?? 0;
      for (final counts in [
        _liveWordCounts,
        _acceptedWordCounts,
        _pausedWordCounts,
      ]) {
        if ((counts[key] ?? 0) > count) count = counts[key]!;
      }
      if (count == 0) break;
      _rollingWordCounts[key] = count;
      _unverifiedAyahs.add(i);
      if (!widget.continuous ||
          count < _comparison.recitationWords(ayah.imlaei ?? '').length) {
        break;
      }
    }
  }

  int get _activeAyahIndex {
    if (!widget.localQuranLab || !widget.continuous) return _index;
    final visible = _visibleWordCounts;
    for (var i = _index; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final length = _comparison.recitationWords(ayah.imlaei ?? '').length;
      final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
      final count = visible[key] ?? 0;
      final navigation = _navigationWordCounts[key] ?? 0;
      if (!_revealed.contains(i) && count < length && navigation < length) {
        return i;
      }
    }
    return widget.ayahs.length;
  }

  int _effectiveWordCount(int index) {
    final ayah = widget.ayahs[index];
    final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
    final visible = _visibleWordCounts[key] ?? 0;
    final navigation = _navigationWordCounts[key] ?? 0;
    return visible > navigation ? visible : navigation;
  }

  int get _actionAyahIndex =>
      _activeAyahIndex.clamp(0, widget.ayahs.length - 1);

  String _vocalizedWord(Ayah ayah, int wordNumber) {
    final arabicWords = ayah.arabic
        .replaceAll(RegExp(r'[\u06D6-\u06ED]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (ayah.words.length > 1 &&
        wordNumber >= 1 &&
        wordNumber <= ayah.words.length) {
      return ayah.words[wordNumber - 1].arabic.trim();
    }
    if (arabicWords.isNotEmpty) {
      final idx = (wordNumber - 1).clamp(0, arabicWords.length - 1);
      return arabicWords[idx];
    }
    final words = _comparison.recitationWords(ayah.imlaei ?? ayah.arabic);
    if (words.isEmpty) return '';
    return words[(wordNumber - 1).clamp(0, words.length - 1)];
  }

  void _recordMistake(int ayahIndex, int wordNumber) {
    if (ayahIndex < 0 || ayahIndex >= widget.ayahs.length) return;
    final ayah = widget.ayahs[ayahIndex];
    final words = _comparison.recitationWords(ayah.imlaei ?? ayah.arabic);
    final clampedWordNumber = wordNumber.clamp(
      1,
      words.isEmpty ? 1 : words.length,
    );
    final expectedWord = _vocalizedWord(ayah, clampedWordNumber);
    final existingIndex = _mistakes.indexWhere(
      (item) =>
          item.surahNumber == ayah.surahNumber &&
          item.ayahNumber == ayah.ayahNumber &&
          item.wordNumber == clampedWordNumber,
    );
    final record = _HifzMistakeRecord(
      ayahIndex: ayahIndex,
      surahNumber: ayah.surahNumber,
      ayahNumber: ayah.ayahNumber,
      wordNumber: clampedWordNumber,
      expectedWord: expectedWord,
    );
    if (existingIndex >= 0) {
      _mistakes[existingIndex] = record;
    } else {
      _mistakes.add(record);
    }
    unawaited(HapticFeedback.mediumImpact());
  }

  void _showMistakesSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        if (_mistakes.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Text(
                l10n.get('hifz_mistakes_empty'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '${l10n.get('hifz_mistakes')} (${l10n.digits(_mistakes.length)})',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _mistakes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _mistakes[_mistakes.length - 1 - index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(
                          0xFFD32F2F,
                        ).withValues(alpha: 0.14),
                        child: const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                      title: Text(
                        '${widget.surahNameFor(item.surahNumber)} — '
                        '${l10n.get('ayah')} ${l10n.digits(item.ayahNumber)} · '
                        '${l10n.get('quran_asr_next_word')} ${l10n.digits(item.wordNumber)}',
                      ),
                      subtitle: item.expectedWord.isEmpty
                          ? null
                          : Text(
                              item.expectedWord,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _select(item.ayahIndex);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _checkpointLiveWords() {
    if (widget.localQuranLab && widget.continuous) {
      final retained = Map<String, int>.of(_navigationWordCounts);
      for (final entry in _visibleWordCounts.entries) {
        if (entry.value > (retained[entry.key] ?? 0)) {
          retained[entry.key] = entry.value;
        }
      }
      _retainPausedWords(_index, retained);
    }
  }

  void _recordLabProgress(
    String text, {
    required bool isFinal,
    required bool contradictsPrefix,
    required Map<String, int> alignment,
  }) {
    if (!widget.localQuranLab) return;
    final speech = _speech;
    if (speech is! QuranAsrSpeechInput) return;
    final visibleWords = _displayedLabWords;
    final newVisibleWords =
        visibleWords - (alignment['displayedBefore'] ?? visibleWords);
    if (!isFinal && newVisibleWords > 0) {
      unawaited(
        speech.recordPreviewReveal(
          newVisibleWords: newVisibleWords,
          visibleWords: visibleWords,
          frame: WidgetsBinding.instance.endOfFrame,
        ),
      );
    }
    unawaited(
      speech.recordProgress(
        expectedIndex: _index,
        rawWords: _comparison.recitationWords(text).length,
        visibleWords: visibleWords,
        isFinal: isFinal,
        contradictsPrefix: contradictsPrefix,
        alignment: alignment,
      ),
    );
  }

  int get _displayedLabWords {
    final visible = _visibleWordCounts;
    return widget.ayahs.indexed.fold(0, (total, entry) {
      final (index, ayah) = entry;
      return total +
          (_revealed.contains(index)
              ? _comparison.recitationWords(ayah.imlaei ?? '').length
              : visible['${ayah.surahNumber}:${ayah.ayahNumber}'] ?? 0);
    });
  }

  List<Ayah> _windowedExpectedAyahs(int startIndex, {int lookahead = 6}) {
    if (!widget.continuous) return [widget.ayahs[startIndex]];
    if (!widget.localQuranLab) return widget.ayahs.skip(startIndex).toList();
    final active = _activeAyahIndex;
    final end = (active + lookahead + 1).clamp(
      startIndex + 1,
      widget.ayahs.length,
    );
    return widget.ayahs.sublist(startIndex, end);
  }

  Map<String, int> _labAlignmentMetrics(
    int startIndex,
    String text, {
    String? precomputedContinuousText,
    List<int>? precomputedCombinedCounts,
  }) {
    final visible = _visibleWordCounts;
    var cursor = _index;
    var cursorCount = 0;
    while (cursor < widget.ayahs.length) {
      final ayah = widget.ayahs[cursor];
      final length = _comparison.recitationWords(ayah.imlaei ?? '').length;
      cursorCount = visible['${ayah.surahNumber}:${ayah.ayahNumber}'] ?? 0;
      if (!_revealed.contains(cursor) && cursorCount < length) break;
      cursor++;
      cursorCount = 0;
    }
    final ayahs = _windowedExpectedAyahs(startIndex);
    final raw = _comparison.checkSequence(
      expectedAyahs: [for (final ayah in ayahs) ayah.imlaei ?? ''],
      expectedVerseKeys: [
        for (final ayah in ayahs) '${ayah.surahNumber}:${ayah.ayahNumber}',
      ],
      spokenText: text,
      allowWrittenOpenings: true,
    );
    final combined =
        precomputedCombinedCounts ??
        _comparison.matchingPrefixWordCounts(
          expectedAyahs: [for (final ayah in ayahs) ayah.imlaei ?? ''],
          expectedVerseKeys: [
            for (final ayah in ayahs) '${ayah.surahNumber}:${ayah.ayahNumber}',
          ],
          spokenText:
              precomputedContinuousText ?? _continuousText(startIndex, text),
          allowWrittenOpenings: true,
        );
    final metrics = <String, int>{
      'schemaVersion': 2,
      'recordingIndex': startIndex,
      'cursorIndex': cursor,
      'cursorWords': cursorCount,
      'displayedBefore': _displayedLabWords,
      'rawCompleted': raw.completedAyahs,
      'rawWordIndex': raw.wordIndex,
      'rawMismatch': raw.mismatch ? 1 : 0,
      'combinedPrefix': combined.fold(0, (a, b) => a + b),
    };
    if (cursor < widget.ayahs.length) {
      final ayah = widget.ayahs[cursor];
      final expected = ayah.imlaei ?? '';
      final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
      final tail = _comparison.joinRecitationSegment(
        retainedPrefix: _comparison
            .recitationWords(expected)
            .take(cursorCount)
            .join(' '),
        spokenText: text,
        expectedAyahs: [expected],
        expectedVerseKeys: [key],
        allowWrittenOpenings: true,
      );
      int prefix(String spoken) => _comparison
          .matchingPrefixWordCounts(
            expectedAyahs: [expected],
            expectedVerseKeys: [key],
            spokenText: spoken,
            allowWrittenOpenings: true,
          )
          .first;
      metrics['cursorRawPrefix'] = prefix(text);
      metrics['cursorTailPrefix'] = prefix(tail);
    }
    return metrics;
  }

  void _continueLivePrefix(int startIndex, String text) {
    if (!widget.localQuranLab || !widget.continuous) return;
    final incoming = _comparison.recitationWords(text);
    if (incoming.isEmpty) return;
    final ayahs = _windowedExpectedAyahs(startIndex);
    for (var i = 0; i < ayahs.length; i++) {
      final ayah = ayahs[i];
      final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
      final words = _comparison.recitationWords(ayah.imlaei ?? '');
      var count = _liveWordCounts[key] ?? 0;
      for (final counts in [_acceptedWordCounts, _pausedWordCounts]) {
        if ((counts[key] ?? 0) > count) count = counts[key]!;
      }
      if (count == 0 || words.isEmpty) {
        final hintedAtZero = _hintWordCounts[startIndex + i] ?? 0;
        final effectiveHintAtZero = hintedAtZero <= words.length
            ? hintedAtZero
            : words.length;
        if (effectiveHintAtZero > 0 && words.isNotEmpty) {
          final fromStart = _comparison.matchingPrefixWordCounts(
            expectedAyahs: [ayah.imlaei ?? ''],
            expectedVerseKeys: [key],
            spokenText: text,
            allowWrittenOpenings: true,
          );
          if (fromStart.first > 0) {
            if (i > 0) _retainRollingWords(startIndex);
            return;
          }
          final hintedContinuation = _comparison.joinRecitationSegment(
            retainedPrefix: words.take(effectiveHintAtZero).join(' '),
            spokenText: text,
            expectedAyahs: [ayah.imlaei ?? ''],
            expectedVerseKeys: [key],
            allowWrittenOpenings: true,
          );
          final hintedContinuedCount = _comparison
              .matchingPrefixWordCounts(
                expectedAyahs: [ayah.imlaei ?? ''],
                expectedVerseKeys: [key],
                spokenText: hintedContinuation,
                allowWrittenOpenings: true,
              )
              .first;
          if (hintedContinuedCount > effectiveHintAtZero) {
            _retainRollingWords(startIndex);
            _rollingWordCounts[key] = effectiveHintAtZero;
          }
        }
        return;
      }
      if (count == words.length) continue;
      if (count > words.length ||
          count <= (_acceptedWordCounts[key] ?? 0) ||
          count <= (_pausedWordCounts[key] ?? 0)) {
        return;
      }
      final fromStart = _comparison.matchingPrefixWordCounts(
        expectedAyahs: [ayah.imlaei ?? ''],
        expectedVerseKeys: [key],
        spokenText: text,
        allowWrittenOpenings: true,
      );
      if (fromStart.first > 0) {
        if (i > 0 && fromStart.first > count) {
          _retainRollingWords(startIndex);
        }
        return;
      }
      // A retry may repeat an exact trailing prefix, but cannot skip a wrong word.
      final continuation = _comparison.joinRecitationSegment(
        retainedPrefix: words.take(count).join(' '),
        spokenText: text,
        expectedAyahs: [ayah.imlaei ?? ''],
        expectedVerseKeys: [key],
        allowWrittenOpenings: true,
      );
      final continuedCount = _comparison
          .matchingPrefixWordCounts(
            expectedAyahs: [ayah.imlaei ?? ''],
            expectedVerseKeys: [key],
            spokenText: continuation,
            allowWrittenOpenings: true,
          )
          .first;
      if (continuedCount > count) {
        _retainRollingWords(startIndex);
        return;
      }
      final hintedCount = _hintWordCounts[startIndex + i] ?? 0;
      final effectiveHintCount = hintedCount <= words.length
          ? hintedCount
          : words.length;
      if (effectiveHintCount > count) {
        final hintedContinuation = _comparison.joinRecitationSegment(
          retainedPrefix: words.take(effectiveHintCount).join(' '),
          spokenText: text,
          expectedAyahs: [ayah.imlaei ?? ''],
          expectedVerseKeys: [key],
          allowWrittenOpenings: true,
        );
        final hintedContinuedCount = _comparison
            .matchingPrefixWordCounts(
              expectedAyahs: [ayah.imlaei ?? ''],
              expectedVerseKeys: [key],
              spokenText: hintedContinuation,
              allowWrittenOpenings: true,
            )
            .first;
        if (hintedContinuedCount > effectiveHintCount) {
          _retainRollingWords(startIndex);
          _rollingWordCounts[key] = effectiveHintCount;
        }
      }
      return;
    }
  }

  bool _restrictContradictorySnapshot(int startIndex, String text) {
    if (!widget.localQuranLab || !widget.continuous) return false;
    final ayahs = _windowedExpectedAyahs(startIndex);
    final expected = [for (final ayah in ayahs) ayah.imlaei ?? ''];
    final keys = [
      for (final ayah in ayahs) '${ayah.surahNumber}:${ayah.ayahNumber}',
    ];
    final check = _comparison.checkSequence(
      expectedAyahs: expected,
      expectedVerseKeys: keys,
      spokenText: text,
      allowWrittenOpenings: true,
    );
    if (!check.mismatch ||
        (check.completedAyahs == 0 && check.wordIndex == 0)) {
      return false;
    }
    final counts = _comparison.matchingPrefixWordCounts(
      expectedAyahs: expected,
      expectedVerseKeys: keys,
      spokenText: text,
      allowWrittenOpenings: true,
    );
    final pendingCounts = _pendingText.trim().isEmpty
        ? const <int>[0]
        : _comparison.matchingPrefixWordCounts(
            expectedAyahs: expected,
            expectedVerseKeys: keys,
            spokenText: _pendingText,
            allowWrittenOpenings: true,
          );
    final totalCounts = counts.fold(0, (a, b) => a + b);
    final totalPending = pendingCounts.fold(0, (a, b) => a + b);
    if (totalCounts < totalPending) return false;
    if (_windowed) {
      final retainedWords = <String>[];
      var firstRetainedCount = pendingCounts.isNotEmpty
          ? pendingCounts.first
          : 0;
      for (final map in [
        _liveWordCounts,
        _completedLiveWordCounts,
        _rollingWordCounts,
        _pausedWordCounts,
        _acceptedWordCounts,
      ]) {
        final value = map[keys.first] ?? 0;
        if (value > firstRetainedCount) firstRetainedCount = value;
      }
      for (var i = 0; i < ayahs.length; i++) {
        final key = keys[i];
        var count = i < pendingCounts.length ? pendingCounts[i] : 0;
        for (final map in [
          _liveWordCounts,
          _completedLiveWordCounts,
          _rollingWordCounts,
          _pausedWordCounts,
          _acceptedWordCounts,
        ]) {
          final value = map[key] ?? 0;
          if (value > count) count = value;
        }
        if (count == 0) break;
        final ayahWords = _comparison.recitationWords(expected[i]);
        retainedWords.addAll(ayahWords.take(count));
        if (count < ayahWords.length) break;
      }
      final retainedTotal = retainedWords.length;
      final firstWords = _comparison.recitationWords(expected.first);
      final firstCompleted =
          firstWords.isNotEmpty && firstRetainedCount >= firstWords.length;
      if (retainedTotal > 0 && totalCounts <= retainedTotal) {
        if (!firstCompleted && totalCounts <= firstRetainedCount) {
          return false;
        }
        if (!firstCompleted) {
          final continued = _comparison.joinRecitationSegment(
            retainedPrefix: firstWords.take(firstRetainedCount).join(' '),
            spokenText: text,
            expectedAyahs: [expected.first],
            expectedVerseKeys: [keys.first],
            allowWrittenOpenings: true,
          );
          final continuedCount = _comparison
              .matchingPrefixWordCounts(
                expectedAyahs: [expected.first],
                expectedVerseKeys: [keys.first],
                spokenText: continued,
                allowWrittenOpenings: true,
              )
              .first;
          if (continuedCount > firstRetainedCount ||
              (continuedCount == firstWords.length &&
                  _comparison.recitationWords(continued).length ==
                      firstWords.length)) {
            return false;
          }
          final firstHinted = _hintWordCounts[startIndex] ?? 0;
          final effectiveFirstHint = firstHinted <= firstWords.length
              ? firstHinted
              : firstWords.length;
          if (effectiveFirstHint > firstRetainedCount) {
            final hintedContinued = _comparison.joinRecitationSegment(
              retainedPrefix: firstWords.take(effectiveFirstHint).join(' '),
              spokenText: text,
              expectedAyahs: [expected.first],
              expectedVerseKeys: [keys.first],
              allowWrittenOpenings: true,
            );
            final hintedContinuedCount = _comparison
                .matchingPrefixWordCounts(
                  expectedAyahs: [expected.first],
                  expectedVerseKeys: [keys.first],
                  spokenText: hintedContinued,
                  allowWrittenOpenings: true,
                )
                .first;
            if (hintedContinuedCount > effectiveFirstHint ||
                (hintedContinuedCount == firstWords.length &&
                    _comparison.recitationWords(hintedContinued).length ==
                        firstWords.length)) {
              return false;
            }
          }
        } else {
          final activeOffset = ayahs.indexWhere((ayah) {
            final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
            final length = _comparison
                .recitationWords(ayah.imlaei ?? '')
                .length;
            var count = 0;
            for (final map in [
              _liveWordCounts,
              _completedLiveWordCounts,
              _rollingWordCounts,
              _pausedWordCounts,
              _acceptedWordCounts,
            ]) {
              final value = map[key] ?? 0;
              if (value > count) count = value;
            }
            return count < length;
          });
          if (activeOffset < 0) {
            final continued = _comparison.joinRecitationSegment(
              retainedPrefix: retainedWords.join(' '),
              spokenText: text,
              expectedAyahs: expected,
              expectedVerseKeys: keys,
              allowWrittenOpenings: true,
            );
            final continuedCounts = _comparison.matchingPrefixWordCounts(
              expectedAyahs: expected,
              expectedVerseKeys: keys,
              spokenText: continued,
              allowWrittenOpenings: true,
            );
            final continuedTotal = continuedCounts.fold(0, (a, b) => a + b);
            final allExpectedCount = expected.fold(
              0,
              (sum, ayahText) =>
                  sum + _comparison.recitationWords(ayahText).length,
            );
            if (continuedTotal > retainedTotal ||
                (continuedTotal == allExpectedCount &&
                    _comparison.recitationWords(continued).length ==
                        allExpectedCount)) {
              return false;
            }
          } else if (activeOffset > 0) {
            final activeExpected = expected[activeOffset];
            final activeKey = keys[activeOffset];
            final activeWords = _comparison.recitationWords(activeExpected);
            var activeRetained = 0;
            for (final map in [
              _liveWordCounts,
              _completedLiveWordCounts,
              _rollingWordCounts,
              _pausedWordCounts,
              _acceptedWordCounts,
            ]) {
              final value = map[activeKey] ?? 0;
              if (value > activeRetained) activeRetained = value;
            }
            if (activeRetained > 0 &&
                expected.take(activeOffset).contains(activeExpected)) {
              final directActiveCount = _comparison
                  .matchingPrefixWordCounts(
                    expectedAyahs: [activeExpected],
                    expectedVerseKeys: [activeKey],
                    spokenText: text,
                    allowWrittenOpenings: true,
                  )
                  .first;
              if (directActiveCount > activeRetained ||
                  (directActiveCount > 0 &&
                      directActiveCount == activeRetained &&
                      _comparison.recitationWords(text).length ==
                          directActiveCount)) {
                return false;
              }
            }
            if (activeRetained > 0) {
              final continued = _comparison.joinRecitationSegment(
                retainedPrefix: activeWords.take(activeRetained).join(' '),
                spokenText: text,
                expectedAyahs: [activeExpected],
                expectedVerseKeys: [activeKey],
                allowWrittenOpenings: true,
              );
              final continuedCount = _comparison
                  .matchingPrefixWordCounts(
                    expectedAyahs: [activeExpected],
                    expectedVerseKeys: [activeKey],
                    spokenText: continued,
                    allowWrittenOpenings: true,
                  )
                  .first;
              if (continuedCount > activeRetained ||
                  (continuedCount == activeWords.length &&
                      _comparison.recitationWords(continued).length ==
                          activeWords.length)) {
                return false;
              }
            }
            final activeHinted =
                _hintWordCounts[startIndex + activeOffset] ?? 0;
            final effectiveActiveHint = activeHinted <= activeWords.length
                ? activeHinted
                : activeWords.length;
            if (effectiveActiveHint > activeRetained) {
              final hintedContinued = _comparison.joinRecitationSegment(
                retainedPrefix: activeWords.take(effectiveActiveHint).join(' '),
                spokenText: text,
                expectedAyahs: [activeExpected],
                expectedVerseKeys: [activeKey],
                allowWrittenOpenings: true,
              );
              final hintedContinuedCount = _comparison
                  .matchingPrefixWordCounts(
                    expectedAyahs: [activeExpected],
                    expectedVerseKeys: [activeKey],
                    spokenText: hintedContinued,
                    allowWrittenOpenings: true,
                  )
                  .first;
              if (hintedContinuedCount > effectiveActiveHint ||
                  (hintedContinuedCount == activeWords.length &&
                      _comparison.recitationWords(hintedContinued).length ==
                          activeWords.length)) {
                return false;
              }
            }
          }
        }
      }
    }
    // Invalidate this snapshot's alignment, not words already displayed.
    // Compare its raw prefix so saved words cannot bridge its mismatch.
    _rollingWordCounts.clear();
    return true;
  }

  Future<List<Ayah>> _page(int number) => _pageLoads.putIfAbsent(
    number,
    () async {
      try {
        return await (widget.loadPage?.call(number) ??
            Future.value(
              widget.ayahs.where((ayah) => ayah.pageNumber == number).toList(),
            ));
      } catch (error) {
        debugPrint('Hifz Mushaf page $number failed: $error');
        rethrow;
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _livePreview = widget.localQuranLab && !widget.review;
    _playingReference = widget.referencePlayingListenable?.value ?? false;
    widget.referencePlayingListenable?.addListener(_onReferencePlayingChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(MemorizationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referencePlayingListenable !=
        widget.referencePlayingListenable) {
      oldWidget.referencePlayingListenable?.removeListener(
        _onReferencePlayingChanged,
      );
      _playingReference = widget.referencePlayingListenable?.value ?? false;
      widget.referencePlayingListenable?.addListener(
        _onReferencePlayingChanged,
      );
    }
  }

  void _onReferencePlayingChanged() {
    if (!mounted) return;
    final playing = widget.referencePlayingListenable?.value ?? false;
    if (_playingReference != playing) {
      setState(() => _playingReference = playing);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The system microphone/speech prompt makes the app inactive without
    // backgrounding it. Cancelling here invalidates its pending permission.
    if (state == AppLifecycleState.inactive &&
        _startingSpeechGeneration == _generation) {
      return;
    }
    if (state != AppLifecycleState.resumed) {
      _interrupt();
    }
  }

  void _interrupt() {
    final wasBusy = _busy;
    final interruptedVerseKey = _verseKey;
    ++_generation;
    _acceptResults = false;
    final cancellation = _cancelInputs();
    if (widget.localQuranLab && wasBusy && _speech is QuranAsrSpeechInput) {
      unawaited(
        cancellation.whenComplete(
          () => QuranAsrSpeechInput.uploadDiagnosticsToCloud(
            verseKey: interruptedVerseKey,
          ),
        ),
      );
    }
    if (mounted) {
      setState(() {
        _checkpointLiveWords();
        _busy = false;
        _loadingReference = false;
        _playingReference = false;
        _stopInProgress = false;
        _preview.clear();
        _clearLiveWords();
        _transcript = '';
        _message = widget.continuous && _hasStarted
            ? 'hifz_resume_message'
            : 'mem_ready';
        _mismatchWord = null;
      });
    }
  }

  Future<void> _cancelInputs() {
    final cancellation = _lastCancellation.then((_) => _cancelInputsNow());
    _lastCancellation = cancellation;
    return cancellation;
  }

  Future<void> _cancelInputsNow() async {
    try {
      await _speech.cancel();
    } on PlatformException catch (error) {
      debugPrint('Memorization input cancellation failed: ${error.code}');
      if (mounted) setState(() => _message = 'mem_error');
    }
    try {
      await widget.stopReference();
    } on PlatformException catch (error) {
      debugPrint('Memorization audio cancellation failed: ${error.code}');
      if (mounted) setState(() => _message = 'mem_audio_error');
    }
  }

  @override
  void dispose() {
    widget.referencePlayingListenable?.removeListener(
      _onReferencePlayingChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _acceptResults = false;
    unawaited(_cancelInputs());
    super.dispose();
  }

  Future<void> _listen() async {
    if (widget.localQuranLab && widget.continuous) {
      _checkpointLiveWords();
      _index = _actionAyahIndex;
    }
    if (widget.continuous && _revealed.contains(_index)) {
      final nextUnrevealed = List<int>.generate(
        widget.ayahs.length,
        (i) => i,
      ).firstWhere((i) => !_revealed.contains(i), orElse: () => -1);
      if (nextUnrevealed < 0) return;
      _index = nextUnrevealed;
    }
    final generation = ++_generation;
    final startIndex = _index;
    setState(() => _busy = true);
    try {
      await _lastCancellation;
      final page = await _page(_ayah.pageNumber);
      if (page.isEmpty) throw StateError('Empty Hifz page');
    } catch (error) {
      debugPrint('Hifz page loading failed: $error');
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _message = 'quran_page_unavailable';
        });
      }
      return;
    }
    if (!mounted || generation != _generation) return;
    if (_ayah.imlaei == null || _ayah.imlaei!.trim().isEmpty) {
      setState(() {
        _busy = false;
        _message = 'mem_missing';
      });
      return;
    }
    setState(() => _busy = true);
    if (!_consented) {
      final l10n = AppLocalizations.of(context);
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.get('mem_consent_title')),
          content: SingleChildScrollView(
            child: Text(
              l10n.get(
                widget.localQuranLab
                    ? quranAsrRetainDebugAudio
                          ? 'quran_asr_audio_debug_warning'
                          : quranAsrRetainDebugTranscripts
                          ? 'quran_asr_transcript_debug_warning'
                          : 'quran_asr_live_warning'
                    : 'mem_consent',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.get('mem_cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.get('mem_agree')),
            ),
          ],
        ),
      );
      if (!mounted || generation != _generation) return;
      if (agreed != true) {
        setState(() => _busy = false);
        return;
      }
      _consented = true;
    }
    try {
      await widget.stopReference();
      if (!mounted || generation != _generation) return;
      setState(() {
        _viewedPageOverride = null;
        _hasStarted = true;
        _acceptResults = true;
        _preview.clear();
        _clearLiveWords();
        _transcript = '';
        _message = 'mem_wait';
        _mismatchWord = null;
      });
      _startingSpeechGeneration = generation;
      _lastPreviewText = null;
      final input = _speech;
      await input.start(
        onResult: (text, isFinal) {
          if (!mounted || generation != _generation || !_acceptResults) return;
          if (widget.localQuranLab && !isFinal && !_livePreview && !_windowed) {
            return;
          }
          final contradictsPrefix = _restrictContradictorySnapshot(
            startIndex,
            text,
          );
          if (!contradictsPrefix &&
              _windowed &&
              input is WindowedMemorizationSpeechInput &&
              input.windowStartSeconds > 0) {
            _retainRollingWords(startIndex);
          }
          if (!widget.localQuranLab) setState(() => _transcript = text);
          if (!contradictsPrefix) _continueLivePrefix(startIndex, text);
          if (!isFinal) {
            _lastPreviewText = text;
            final expectedAyahs = widget.continuous
                ? _windowedExpectedAyahs(startIndex)
                : [_ayah];
            List<int> countsFrom(int offset, String spokenText) =>
                _comparison.matchingPrefixWordCounts(
                  expectedAyahs: [
                    for (final ayah in expectedAyahs.skip(offset))
                      ayah.imlaei ?? '',
                  ],
                  expectedVerseKeys: [
                    for (final ayah in expectedAyahs.skip(offset))
                      '${ayah.surahNumber}:${ayah.ayahNumber}',
                  ],
                  spokenText: spokenText,
                  allowWrittenOpenings: widget.localQuranLab,
                  allowDisplayOnlyCorrections: widget.localQuranLab,
                );
            final effectivePreviewText =
                widget.localQuranLab && widget.continuous && contradictsPrefix
                ? text
                : widget.continuous || _windowed
                ? _continuousText(startIndex, text)
                : text;
            var wordCounts = countsFrom(0, effectivePreviewText);
            final alignment =
                widget.localQuranLab && input is QuranAsrSpeechInput
                ? _labAlignmentMetrics(
                    startIndex,
                    text,
                    precomputedContinuousText: effectivePreviewText,
                    precomputedCombinedCounts: wordCounts,
                  )
                : const <String, int>{};
            if (widget.localQuranLab &&
                input is QuranAsrSpeechInput &&
                expectedAyahs.isNotEmpty &&
                wordCounts.isNotEmpty &&
                wordCounts.first == 1 &&
                wordCounts.skip(1).every((count) => count == 0)) {
              final firstAyah = expectedAyahs.first;
              final firstKey =
                  '${firstAyah.surahNumber}:${firstAyah.ayahNumber}';
              final firstWords = _comparison.recitationWords(
                firstAyah.imlaei ?? '',
              );
              final spokenWords = _comparison.recitationWords(text);
              final minOpeningSeconds = firstWords.first.length >= 3
                  ? firstWords.first.length * 1.3
                  : firstWords.first.length * 1.1;
              if (firstWords.length == 1 &&
                  firstWords.first.length >= 2 &&
                  spokenWords.length == 1 &&
                  input.windowStartSeconds + input.lastDurationSeconds <
                      minOpeningSeconds &&
                  _comparison
                          .matchingPrefixWordCounts(
                            expectedAyahs: [firstAyah.imlaei ?? ''],
                            expectedVerseKeys: [firstKey],
                            spokenText: text,
                            allowWrittenOpenings: false,
                          )
                          .first ==
                      0) {
                wordCounts = const [0];
              }
            }
            setState(() {
              final previousWords = Map<String, int>.of(_liveWordCounts);
              _liveWordCounts.clear();
              if (widget.localQuranLab && widget.continuous ||
                  !contradictsPrefix && wordCounts.first == 0) {
                _liveWordCounts.addAll(previousWords);
              }
              for (var i = 0; i < wordCounts.length; i++) {
                if (wordCounts[i] == 0) continue;
                final ayah = expectedAyahs[i];
                final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
                if (!widget.localQuranLab ||
                    !widget.continuous ||
                    wordCounts[i] > (_liveWordCounts[key] ?? 0)) {
                  _liveWordCounts[key] = wordCounts[i];
                }
                if (widget.localQuranLab && widget.continuous) {
                  final fullCount = _comparison
                      .recitationWords(ayah.imlaei ?? '')
                      .length;
                  if (fullCount > 0 && wordCounts[i] == fullCount) {
                    _completedLiveWordCounts[key] = fullCount;
                  }
                }
              }
              _liveWordCounts.addAll(_completedLiveWordCounts);
              if (widget.localQuranLab) {
                final totalPreviewWords = wordCounts.fold(0, (a, b) => a + b);
                final previousPreviewWords = previousWords.values.fold(
                  0,
                  (a, b) => a + b,
                );
                if (widget.continuous &&
                    totalPreviewWords <= previousPreviewWords &&
                    _activeAyahIndex < widget.ayahs.length) {
                  final liveCheck = _comparison.checkSequence(
                    expectedAyahs: [
                      for (final ayah in expectedAyahs) ayah.imlaei ?? '',
                    ],
                    expectedVerseKeys: [
                      for (final ayah in expectedAyahs)
                        '${ayah.surahNumber}:${ayah.ayahNumber}',
                    ],
                    spokenText: effectivePreviewText,
                    allowWrittenOpenings: true,
                  );
                  if (liveCheck.mismatch) {
                    final activeIdx = _activeAyahIndex;
                    final activeKey =
                        '${widget.ayahs[activeIdx].surahNumber}:${widget.ayahs[activeIdx].ayahNumber}';
                    final activeMatched = _visibleWordCounts[activeKey] ?? 0;
                    final liveMismatchWord = activeMatched + 1;
                    if (_mismatchWord != liveMismatchWord) {
                      _recordMistake(activeIdx, liveMismatchWord);
                    }
                  }
                }
              }
              if (_viewedPageOverride != null &&
                  _liveWordCounts.length != previousWords.length) {
                _viewedPageOverride = null;
              }
            });
            if (widget.continuous && _livePreview && !widget.localQuranLab) {
              final check = _sequenceCheck(startIndex, text);
              setState(() {
                _preview
                  ..clear()
                  ..addAll(
                    Iterable.generate(
                      check.completedAyahs,
                      (i) => startIndex + i,
                    ),
                  );
              });
            }
            _recordLabProgress(
              text,
              isFinal: false,
              contradictsPrefix: contradictsPrefix,
              alignment: alignment,
            );
            return;
          }
          if (widget.continuous) {
            final alignment =
                widget.localQuranLab && input is QuranAsrSpeechInput
                ? _labAlignmentMetrics(startIndex, text)
                : const <String, int>{};
            final tail = _lastPreviewText;
            _lastPreviewText = null;
            final previewCounts = Map<String, int>.of(_visibleWordCounts);
            _checkContinuous(
              startIndex,
              text,
              reconcilePreview: !contradictsPrefix,
              contradictsPrefix: contradictsPrefix,
            );
            if (widget.localQuranLab && tail != null) {
              _reconcileStoppedTail(tail, text, previewCounts);
            }
            _recordLabProgress(
              text,
              isFinal: true,
              contradictsPrefix: contradictsPrefix,
              alignment: alignment,
            );
            if (widget.localQuranLab && input is QuranAsrSpeechInput) {
              unawaited(
                QuranAsrSpeechInput.uploadDiagnosticsToCloud(
                  verseKey: _verseKey,
                ),
              );
            }
            return;
          }
          final check = _comparison.checkEntireAyah(
            expectedImlaei: _ayah.imlaei!,
            expectedVerseKey: '${_ayah.surahNumber}:${_ayah.ayahNumber}',
            spokenText: _windowed ? _continuousText(startIndex, text) : text,
            allowWrittenOpenings: widget.localQuranLab,
          );
          setState(() {
            _busy = false;
            _acceptResults = false;
            _clearLiveWords();
            if (check.matched) {
              if (widget.localQuranLab &&
                  !_comparison
                      .checkEntireAyah(
                        expectedImlaei: _ayah.imlaei!,
                        expectedVerseKey: _verseKey,
                        spokenText: text,
                        allowWrittenOpenings: true,
                        allowAsrCorrections: false,
                      )
                      .matched) {
                _unverifiedAyahs.add(_index);
              }
              if (!_assisted.contains(_index) &&
                  !_unverifiedAyahs.contains(_index)) {
                _matched.add(_index);
              }
              _revealed.add(_index);
              _message = 'mem_match';
            } else if (check.wordsSpoken == 0) {
              _message = widget.continuous
                  ? 'hifz_resume_message'
                  : 'mem_error';
            } else {
              _message = 'mem_mismatch';
              _mismatchWord = check.firstMismatch + 1;
              _recordMistake(_index, _mismatchWord!);
            }
          });
          unawaited(_cancelInputs());
          if (widget.localQuranLab && input is QuranAsrSpeechInput) {
            unawaited(
              QuranAsrSpeechInput.uploadDiagnosticsToCloud(verseKey: _verseKey),
            );
          }
        },
        onDone: () {
          if (!mounted || generation != _generation || !_acceptResults) return;
          setState(() {
            _checkpointLiveWords();
            _busy = false;
            _acceptResults = false;
            _preview.clear();
            _clearLiveWords();
            _message = widget.continuous ? 'hifz_resume_message' : 'mem_error';
          });
          unawaited(_cancelInputs());
          if (widget.localQuranLab && input is QuranAsrSpeechInput) {
            unawaited(
              QuranAsrSpeechInput.uploadDiagnosticsToCloud(verseKey: _verseKey),
            );
          }
        },
        onError: (code) {
          if (!mounted || generation != _generation || !_acceptResults) return;
          debugPrint('Memorization speech error: $code');
          setState(() {
            _checkpointLiveWords();
            _busy = false;
            _acceptResults = false;
            _preview.clear();
            _clearLiveWords();
            _message = 'mem_error';
          });
          unawaited(_cancelInputs());
        },
      );
    } on MemorizationSpeechException catch (error) {
      _inputFailed(generation, error.code);
    } on PlatformException catch (error) {
      _inputFailed(generation, error.code);
    } finally {
      if (_startingSpeechGeneration == generation) {
        _startingSpeechGeneration = null;
      }
    }
  }

  String _continuousText(int startIndex, String text) {
    if (!widget.localQuranLab) return '$_pendingText $text';
    final ayahs = widget.continuous
        ? _windowedExpectedAyahs(startIndex)
        : [widget.ayahs[startIndex]];
    final retained = <String>[];
    final startKey =
        '${widget.ayahs[startIndex].surahNumber}:${widget.ayahs[startIndex].ayahNumber}';
    final startAlreadyCompleted =
        _revealed.contains(startIndex) ||
        (_pausedWordCounts[startKey] ?? 0) >=
            _comparison
                .recitationWords(widget.ayahs[startIndex].imlaei ?? '')
                .length;
    var completedInRetained = 0;
    if (!startAlreadyCompleted) {
      for (var i = 0; i < ayahs.length; i++) {
        final ayah = ayahs[i];
        final ayahIndex = startIndex + i;
        final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
        final words = _comparison.recitationWords(ayah.imlaei ?? '');
        var count = _revealed.contains(ayahIndex)
            ? words.length
            : (_rollingWordCounts[key] ?? 0);
        for (final counts in [
          _liveWordCounts,
          _completedLiveWordCounts,
          _acceptedWordCounts,
          _pausedWordCounts,
        ]) {
          if ((counts[key] ?? 0) > count) count = counts[key]!;
        }
        if (count == 0) break;
        retained.addAll(words.take(count));
        if (count < words.length) break;
        completedInRetained++;
      }
    }
    final activeOffset = completedInRetained < ayahs.length
        ? completedInRetained
        : ayahs.length - 1;
    final activeIndex = startIndex + activeOffset;
    var retainedPrefixText = retained.isEmpty
        ? _pendingText
        : retained.join(' ');
    final hintedOnActive = widget.continuous
        ? (_hintWordCounts[activeIndex] ?? 0)
        : 0;
    if (hintedOnActive > 0 && activeOffset < ayahs.length) {
      final activeAyah = ayahs[activeOffset];
      final activeKey = '${activeAyah.surahNumber}:${activeAyah.ayahNumber}';
      final activeWords = _comparison.recitationWords(activeAyah.imlaei ?? '');
      var activeRetainedCount = 0;
      for (final counts in [
        _rollingWordCounts,
        _liveWordCounts,
        _completedLiveWordCounts,
        _acceptedWordCounts,
        _pausedWordCounts,
      ]) {
        if ((counts[activeKey] ?? 0) > activeRetainedCount) {
          activeRetainedCount = counts[activeKey]!;
        }
      }
      if (activeRetainedCount == 0 &&
          activeOffset == 0 &&
          _pendingText.isNotEmpty) {
        activeRetainedCount = _comparison.recitationWords(_pendingText).length;
      }
      final effectiveHintCount = hintedOnActive <= activeWords.length
          ? hintedOnActive
          : activeWords.length;
      if (effectiveHintCount > activeRetainedCount) {
        final expectedSlice = [
          for (final ayah in ayahs.skip(activeOffset)) ayah.imlaei ?? '',
        ];
        final keySlice = [
          for (final ayah in ayahs.skip(activeOffset))
            '${ayah.surahNumber}:${ayah.ayahNumber}',
        ];
        final currentActivePrefix = activeWords
            .take(activeRetainedCount)
            .join(' ');
        final fromCurrent = _comparison.joinRecitationSegment(
          retainedPrefix: currentActivePrefix,
          spokenText: text,
          expectedAyahs: expectedSlice,
          expectedVerseKeys: keySlice,
          allowWrittenOpenings: true,
        );
        final currentMatched = _comparison
            .matchingPrefixWordCounts(
              expectedAyahs: expectedSlice,
              expectedVerseKeys: keySlice,
              spokenText: fromCurrent,
              allowWrittenOpenings: true,
            )
            .fold(0, (a, b) => a + b);
        if (currentMatched <= activeRetainedCount) {
          final hintedActivePrefix = activeWords
              .take(effectiveHintCount)
              .join(' ');
          final fromHinted = _comparison.joinRecitationSegment(
            retainedPrefix: hintedActivePrefix,
            spokenText: text,
            expectedAyahs: expectedSlice,
            expectedVerseKeys: keySlice,
            allowWrittenOpenings: true,
          );
          final hintedMatched = _comparison
              .matchingPrefixWordCounts(
                expectedAyahs: expectedSlice,
                expectedVerseKeys: keySlice,
                spokenText: fromHinted,
                allowWrittenOpenings: true,
              )
              .fold(0, (a, b) => a + b);
          if (hintedMatched > effectiveHintCount) {
            final completedBeforeActive = <String>[
              for (var i = 0; i < activeOffset; i++)
                ..._comparison.recitationWords(ayahs[i].imlaei ?? ''),
              ...activeWords.take(effectiveHintCount),
            ];
            retainedPrefixText = completedBeforeActive.join(' ');
          }
        }
      }
    }
    var effectiveSpokenText = text;
    if (retained.isEmpty && _pendingText.isEmpty && startIndex > 0) {
      final prevWords = _comparison.recitationWords(
        widget.ayahs[startIndex - 1].imlaei ?? '',
      );
      final incomingWords = _comparison.recitationWords(text);
      final incomingVocalized = _comparison.vocalizedWords(text);
      if (prevWords.isNotEmpty &&
          incomingWords.length >= 2 &&
          incomingVocalized.length == incomingWords.length) {
        final maxCarryover = prevWords.length < 2 ? prevWords.length : 2;
        for (
          var carry = maxCarryover;
          carry > 0 && carry < incomingWords.length;
          carry--
        ) {
          var matchesPrevTail = true;
          for (var i = 0; i < carry; i++) {
            final prevWord = prevWords[prevWords.length - carry + i];
            final spokenWord = incomingWords[i];
            if (prevWord != spokenWord &&
                !(prevWord.endsWith('ا') &&
                    spokenWord.endsWith('ى') &&
                    prevWord.substring(0, prevWord.length - 1) ==
                        spokenWord.substring(0, spokenWord.length - 1))) {
              matchesPrevTail = false;
              break;
            }
          }
          if (matchesPrevTail) {
            final stripped = incomingVocalized.skip(carry).join(' ');
            final counts = _comparison.matchingPrefixWordCounts(
              expectedAyahs: [ayahs.first.imlaei ?? ''],
              expectedVerseKeys: [startKey],
              spokenText: stripped,
              allowWrittenOpenings: true,
            );
            if (counts.isNotEmpty && counts.first > 0) {
              effectiveSpokenText = stripped;
              break;
            }
          }
        }
      }
    }
    if (effectiveSpokenText == text && activeIndex > 0) {
      final prevWords = _comparison.recitationWords(
        widget.ayahs[activeIndex - 1].imlaei ?? '',
      );
      final incomingWords = _comparison.recitationWords(text);
      final incomingVocalized = _comparison.vocalizedWords(text);
      if (prevWords.length >= 2 &&
          incomingWords.length > 2 &&
          incomingVocalized.length == incomingWords.length) {
        final activeAyah = widget.ayahs[activeIndex];
        final activeKey = '${activeAyah.surahNumber}:${activeAyah.ayahNumber}';
        final directCounts = _comparison.matchingPrefixWordCounts(
          expectedAyahs: [ayahs.first.imlaei ?? ''],
          expectedVerseKeys: [startKey],
          spokenText: text,
          allowWrittenOpenings: true,
        );
        if (directCounts.isEmpty || directCounts.first == 0) {
          final earlierWords = <String>{
            for (final earlier in widget.ayahs.take(activeIndex))
              ..._comparison.recitationWords(earlier.imlaei ?? ''),
          };
          final prevTail0 = prevWords[prevWords.length - 2];
          final prevTail1 = prevWords.last;
          for (var pos = 1; pos + 2 < incomingWords.length; pos++) {
            if (incomingWords[pos] == prevTail0 &&
                incomingWords[pos + 1] == prevTail1 &&
                incomingWords.take(pos).any(earlierWords.contains)) {
              final afterPrev = incomingVocalized.skip(pos + 2).join(' ');
              final counts = _comparison.matchingPrefixWordCounts(
                expectedAyahs: [activeAyah.imlaei ?? ''],
                expectedVerseKeys: [activeKey],
                spokenText: afterPrev,
                allowWrittenOpenings: true,
              );
              if (counts.isNotEmpty && counts.first > 0) {
                effectiveSpokenText = retained.isEmpty
                    ? afterPrev
                    : incomingVocalized.skip(pos).join(' ');
                break;
              }
            }
          }
        }
      }
    }
    final expectedAll = [for (final ayah in ayahs) ayah.imlaei ?? ''];
    final keysAll = [
      for (final ayah in ayahs) '${ayah.surahNumber}:${ayah.ayahNumber}',
    ];
    if (activeOffset > 0 && activeOffset < ayahs.length) {
      final completedBeforeActive = <String>[
        for (var i = 0; i < activeOffset; i++)
          ..._comparison.recitationWords(ayahs[i].imlaei ?? ''),
      ];
      final activeRetainedWords = retained
          .skip(completedBeforeActive.length)
          .toList();
      final activeRetainedPrefix = activeRetainedWords.join(' ');
      final activeExpectedSlice = expectedAll.skip(activeOffset).toList();
      final activeKeysSlice = keysAll.skip(activeOffset).toList();
      var activeSpokenText = effectiveSpokenText;
      if (activeRetainedWords.isEmpty && activeIndex > 0) {
        final prevWords = _comparison.recitationWords(
          widget.ayahs[activeIndex - 1].imlaei ?? '',
        );
        final incomingWords = _comparison.recitationWords(effectiveSpokenText);
        final incomingVocalized = _comparison.vocalizedWords(
          effectiveSpokenText,
        );
        if (prevWords.isNotEmpty &&
            incomingWords.length >= 2 &&
            incomingVocalized.length == incomingWords.length) {
          final maxCarry = prevWords.length < 2 ? prevWords.length : 2;
          for (
            var carry = maxCarry;
            carry > 0 && carry < incomingWords.length;
            carry--
          ) {
            var matchesPrevTail = true;
            for (var i = 0; i < carry; i++) {
              final prevWord = prevWords[prevWords.length - carry + i];
              final spokenWord = incomingWords[i];
              if (prevWord != spokenWord &&
                  !(prevWord.endsWith('ا') &&
                      spokenWord.endsWith('ى') &&
                      prevWord.substring(0, prevWord.length - 1) ==
                          spokenWord.substring(0, spokenWord.length - 1))) {
                matchesPrevTail = false;
                break;
              }
            }
            if (matchesPrevTail) {
              final stripped = incomingVocalized.skip(carry).join(' ');
              final counts = _comparison.matchingPrefixWordCounts(
                expectedAyahs: [activeExpectedSlice.first],
                expectedVerseKeys: [activeKeysSlice.first],
                spokenText: stripped,
                allowWrittenOpenings: true,
              );
              if (counts.isNotEmpty && counts.first > 0) {
                activeSpokenText = stripped;
                break;
              }
            }
          }
        }
      }
      if (activeOffset >= 3 &&
          retained.length > 60 &&
          !expectedAll.take(activeOffset).contains(expectedAll[activeOffset]) &&
          activeSpokenText == effectiveSpokenText) {
        final tailStart = activeOffset - 1;
        final completedBeforeTail = <String>[
          for (var i = 0; i < tailStart; i++)
            ..._comparison.recitationWords(ayahs[i].imlaei ?? ''),
        ];
        final tailRetainedPrefix = retained
            .skip(completedBeforeTail.length)
            .join(' ');
        final tailJoined = _comparison.joinRecitationSegment(
          retainedPrefix: tailRetainedPrefix,
          spokenText: effectiveSpokenText,
          expectedAyahs: expectedAll.skip(tailStart).toList(),
          expectedVerseKeys: keysAll.skip(tailStart).toList(),
          allowWrittenOpenings: true,
        );
        return [
          ...completedBeforeTail,
          tailJoined,
        ].where((part) => part.isNotEmpty).join(' ');
      }
      final fullJoined = _comparison.joinRecitationSegment(
        retainedPrefix: retainedPrefixText,
        spokenText: effectiveSpokenText,
        expectedAyahs: expectedAll,
        expectedVerseKeys: keysAll,
        allowWrittenOpenings: true,
      );
      if (expectedAll.take(activeOffset).contains(expectedAll[activeOffset]) ||
          activeSpokenText != effectiveSpokenText) {
        final activeJoined = _comparison.joinRecitationSegment(
          retainedPrefix: activeRetainedPrefix,
          spokenText: activeSpokenText,
          expectedAyahs: activeExpectedSlice,
          expectedVerseKeys: activeKeysSlice,
          allowWrittenOpenings: true,
        );
        final fullCounts = _comparison.matchingPrefixWordCounts(
          expectedAyahs: expectedAll,
          expectedVerseKeys: keysAll,
          spokenText: fullJoined,
          allowWrittenOpenings: true,
        );
        final activeSliceCounts = _comparison.matchingPrefixWordCounts(
          expectedAyahs: activeExpectedSlice,
          expectedVerseKeys: activeKeysSlice,
          spokenText: activeJoined,
          allowWrittenOpenings: true,
        );
        final fullAfterActive = fullCounts
            .skip(activeOffset)
            .fold(0, (a, b) => a + b);
        final activeSliceTotal = activeSliceCounts.fold(0, (a, b) => a + b);
        if (activeSliceTotal > fullAfterActive) {
          return [
            ...completedBeforeActive,
            activeJoined,
          ].where((part) => part.isNotEmpty).join(' ');
        }
      }
      return fullJoined;
    }
    return _comparison.joinRecitationSegment(
      retainedPrefix: retainedPrefixText,
      spokenText: effectiveSpokenText,
      expectedAyahs: expectedAll,
      expectedVerseKeys: keysAll,
      allowWrittenOpenings: true,
    );
  }

  RecitationSequenceCheck _sequenceCheck(int startIndex, String text) =>
      _comparison.checkSequence(
        expectedAyahs: [
          for (final ayah in widget.ayahs.skip(startIndex)) ayah.imlaei ?? '',
        ],
        expectedVerseKeys: [
          for (final ayah in widget.ayahs.skip(startIndex))
            '${ayah.surahNumber}:${ayah.ayahNumber}',
        ],
        spokenText: _continuousText(startIndex, text),
        allowWrittenOpenings: widget.localQuranLab,
      );

  List<int> _rawPrefixCounts(int startIndex, String text) {
    final ayahs = widget.ayahs.skip(startIndex).toList();
    List<int> pad(int offset, List<int> counts) => [
      ...counts,
      ...List<int>.filled(ayahs.length - offset - counts.length, 0),
    ];
    List<int> countsFrom(int offset, [String? customText]) =>
        _comparison.matchingPrefixWordCounts(
          expectedAyahs: [
            for (final ayah in ayahs.skip(offset)) ayah.imlaei ?? '',
          ],
          expectedVerseKeys: [
            for (final ayah in ayahs.skip(offset))
              '${ayah.surahNumber}:${ayah.ayahNumber}',
          ],
          spokenText: customText ?? text,
          allowWrittenOpenings: true,
        );

    final fromStart = countsFrom(0);
    if (fromStart.isNotEmpty && fromStart.first > 0) {
      return pad(0, fromStart);
    }
    for (var offset = 1; offset < ayahs.length; offset++) {
      final fromBoundary = countsFrom(offset);
      if (fromBoundary.isNotEmpty && fromBoundary.first > 0) {
        return [...List<int>.filled(offset, 0), ...pad(offset, fromBoundary)];
      }
    }
    final spokenWords = _comparison.recitationWords(text);
    final spokenVocalized = _comparison.vocalizedWords(text);
    for (var offset = 1; offset < ayahs.length; offset++) {
      final prevWords = _comparison.recitationWords(
        ayahs[offset - 1].imlaei ?? '',
      );
      if (prevWords.isEmpty ||
          spokenWords.length <= 1 ||
          spokenVocalized.length != spokenWords.length) {
        continue;
      }
      final maxTail = prevWords.length < spokenWords.length - 1
          ? prevWords.length
          : spokenWords.length - 1;
      for (var tail = maxTail; tail >= 1; tail--) {
        var matchesPrevSuffix = true;
        for (var i = 0; i < tail; i++) {
          final expectedWord = prevWords[prevWords.length - tail + i];
          final spokenWord = spokenWords[i];
          if (spokenWord != expectedWord &&
              !(i == 0 && spokenWord == 'و$expectedWord')) {
            matchesPrevSuffix = false;
            break;
          }
        }
        if (!matchesPrevSuffix) continue;
        final afterTail = spokenVocalized.skip(tail).join(' ');
        final fromAfterTail = countsFrom(offset, afterTail);
        if (fromAfterTail.isNotEmpty && fromAfterTail.first > 0) {
          return [
            ...List<int>.filled(offset, 0),
            ...pad(offset, fromAfterTail),
          ];
        }
      }
    }
    return List<int>.filled(ayahs.length, 0);
  }

  void _checkContinuous(
    int startIndex,
    String text, {
    bool reconcilePreview = true,
    bool contradictsPrefix = false,
  }) {
    final visibleWords = widget.localQuranLab
        ? _visibleWordCounts
        : <String, int>{};
    final check = contradictsPrefix
        ? _comparison.checkSequence(
            expectedAyahs: [
              for (final ayah in widget.ayahs.skip(startIndex))
                ayah.imlaei ?? '',
            ],
            expectedVerseKeys: [
              for (final ayah in widget.ayahs.skip(startIndex))
                '${ayah.surahNumber}:${ayah.ayahNumber}',
            ],
            spokenText: text,
            allowWrittenOpenings: widget.localQuranLab,
          )
        : _sequenceCheck(startIndex, text);
    final rawCounts = widget.localQuranLab
        ? _rawPrefixCounts(startIndex, text)
        : const <int>[];
    final strictText = widget.localQuranLab
        ? _comparison.joinRecitationSegment(
            retainedPrefix: _pendingText,
            spokenText: text,
            expectedAyahs: [
              for (final ayah in widget.ayahs.skip(startIndex))
                ayah.imlaei ?? '',
            ],
            expectedVerseKeys: [
              for (final ayah in widget.ayahs.skip(startIndex))
                '${ayah.surahNumber}:${ayah.ayahNumber}',
            ],
          )
        : text;
    final retainedPrefix = check.mismatch
        ? check.matchedPrefixText
        : check.remainingText;
    final evidenceAyahs = [
      for (final ayah
          in widget.ayahs.skip(startIndex).take(check.completedAyahs))
        ayah.imlaei ?? '',
      if (retainedPrefix.isNotEmpty) retainedPrefix,
    ];
    final literalEvidence = widget.localQuranLab
        ? _comparison.literalAyahEvidence(
            expectedAyahs: evidenceAyahs,
            expectedVerseKeys: [
              for (final ayah
                  in widget.ayahs.skip(startIndex).take(evidenceAyahs.length))
                '${ayah.surahNumber}:${ayah.ayahNumber}',
            ],
            spokenText: strictText,
          )
        : const <bool>[];
    final previewWords = <String, int>{};
    for (final counts in [
      _liveWordCounts,
      _completedLiveWordCounts,
      _rollingWordCounts,
      _pausedWordCounts,
    ]) {
      for (final entry in counts.entries) {
        if (entry.value > (previewWords[entry.key] ?? 0)) {
          previewWords[entry.key] = entry.value;
        }
      }
    }
    var retainedFurther = false;
    setState(() {
      _preview.clear();
      _pausedWordCounts.clear();
      if (widget.localQuranLab) {
        for (var index = 0; index < startIndex; index++) {
          final ayah = widget.ayahs[index];
          final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
          final previewCount = previewWords[key] ?? 0;
          if (previewCount > 0 && _unverifiedAyahs.contains(index)) {
            _pausedWordCounts[key] = previewCount;
          }
        }
        for (var offset = 0; offset < rawCounts.length; offset++) {
          final ayah = widget.ayahs[startIndex + offset];
          final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
          final previewCount = previewWords[key] ?? 0;
          if (previewCount > rawCounts[offset]) {
            _pausedWordCounts[key] = previewCount;
            _unverifiedAyahs.add(startIndex + offset);
          }
        }
      }
      _clearLiveWords();
      _busy = false;
      _acceptResults = false;
      for (var i = startIndex; i < startIndex + check.completedAyahs; i++) {
        _revealed.add(i);
        if (widget.localQuranLab && !literalEvidence[i - startIndex]) {
          _unverifiedAyahs.add(i);
        }
        if (!_assisted.contains(i) && !_unverifiedAyahs.contains(i)) {
          _matched.add(i);
        }
      }
      final next = startIndex + check.completedAyahs;
      _finished = next == widget.ayahs.length;
      _index = _finished ? widget.ayahs.length - 1 : next;
      if (widget.localQuranLab) {
        final offset = _index - startIndex;
        if (!_finished &&
            retainedPrefix.isNotEmpty &&
            !literalEvidence[offset]) {
          // A recovered partial prefix must not become credit on Resume.
          _unverifiedAyahs.add(_index);
        }
        // Keep only the exact prefix before the first mismatch. A new
        // recording starts at the blocked word, not after the wrong words.
        if (_finished) {
          _pendingText = '';
        } else if (!check.mismatch) {
          _pendingText = check.remainingText;
        } else if (check.matchedPrefixText.isNotEmpty) {
          _pendingText = check.matchedPrefixText;
        } else if (check.completedAyahs > 0) {
          _pendingText = '';
        }
        _acceptedWordCounts.clear();
        if (!_finished && _pendingText.isNotEmpty) {
          final count = _comparison
              .matchingPrefixWordCounts(
                expectedAyahs: [_ayah.imlaei ?? ''],
                expectedVerseKeys: [_verseKey],
                spokenText: _pendingText,
              )
              .single;
          if (count > 0) {
            _acceptedWordCounts[_verseKey] = count;
          } else if (retainedPrefix.isEmpty || !literalEvidence[offset]) {
            // Keep explicit letter names across Resume, but never render a
            // partially matched opening as its whole printed word.
            _pendingText = '';
          }
        }
      } else {
        _pendingText = check.mismatch ? '' : check.remainingText;
      }
      _mismatchWord = check.mismatch
          ? widget.localQuranLab
                ? _nextLabWord
                : check.wordIndex + 1
          : null;
      _message = check.mismatch ? 'mem_mismatch' : 'hifz_resume_message';
      if (check.mismatch) {
        final mistakeWord =
            _mismatchWord ??
            (widget.localQuranLab ? _nextLabWord : check.wordIndex + 1);
        _recordMistake(_index, mistakeWord);
      }
      final finalIndex = _index;
      final finalPrefix = _pendingText;
      final mismatchFromLaterAyah =
          check.mismatch &&
          check.completedAyahs > 0 &&
          visibleWords.keys.any((key) {
            final idx = widget.ayahs.indexWhere(
              (a) => '${a.surahNumber}:${a.ayahNumber}' == key,
            );
            return idx > _index && (visibleWords[key] ?? 0) > 0;
          });
      _retainPausedWords(
        startIndex,
        visibleWords,
        maxAyahIndex: mismatchFromLaterAyah ? _index : null,
        maxWordCountAtBoundary: mismatchFromLaterAyah ? check.wordIndex : null,
      );
      retainedFurther =
          !_finished && (_index != finalIndex || _pendingText != finalPrefix);
    });
    if (reconcilePreview && retainedFurther) {
      // A final snapshot may contain only the latest ayah or suffix.
      // Check it once at the retained cursor, without scoring the saved guesses.
      _checkContinuous(_index, text, reconcilePreview: false);
      return;
    }
    unawaited(_cancelInputs());
  }

  /// A long final transcript can truncate its last words while the stopped
  /// tail preview (decoded just before it) holds them. Join that tail only at
  /// the cursor the final itself verified, through the same anchored checks.
  void _reconcileStoppedTail(
    String tail,
    String finalText,
    Map<String, int> previewCounts,
  ) {
    // The final must verify beyond the previews so they never finish alone,
    // and must end at its verified cursor: a truncated final, not a wrong word.
    final finalWords = _acceptedWordCounts[_verseKey] ?? 0;
    final heard = _comparison.recitationWords(finalText);
    final kept = _comparison.recitationWords(_pendingText);
    if (_finished ||
        kept.isEmpty ||
        heard.isEmpty ||
        finalWords == 0 ||
        finalWords <= (previewCounts[_verseKey] ?? 0)) {
      return;
    }
    if (heard.last != kept.last) {
      final ayahWords = _comparison.recitationWords(
        widget.ayahs[_index].imlaei ?? '',
      );
      final cutMidWord =
          heard.length >= 2 &&
          heard[heard.length - 2] == kept.last &&
          finalWords < ayahWords.length &&
          heard.last.length < ayahWords[finalWords].length &&
          ayahWords[finalWords].startsWith(heard.last);
      if (!cutMidWord) return;
    }
    final ayahs = widget.ayahs.skip(_index).toList();
    final expected = [for (final ayah in ayahs) ayah.imlaei ?? ''];
    final keys = [
      for (final ayah in ayahs) '${ayah.surahNumber}:${ayah.ayahNumber}',
    ];
    int verified(String text) => _comparison
        .matchingPrefixWordCounts(
          expectedAyahs: expected,
          expectedVerseKeys: keys,
          spokenText: text,
          allowWrittenOpenings: true,
        )
        .fold(0, (sum, count) => sum + count);
    final joined = _comparison.joinRecitationSegment(
      retainedPrefix: _pendingText,
      spokenText: tail,
      expectedAyahs: expected,
      expectedVerseKeys: keys,
      allowWrittenOpenings: true,
    );
    if (verified(joined) <= verified(_pendingText)) return;
    _checkContinuous(_index, tail, reconcilePreview: false);
  }

  void _inputFailed(int generation, String code) {
    debugPrint('Memorization input failed: $code');
    if (!mounted || generation != _generation) return;
    unawaited(_cancelInputs());
    setState(() {
      _checkpointLiveWords();
      _busy = false;
      _acceptResults = false;
      _preview.clear();
      _clearLiveWords();
      _message = 'mem_error';
    });
  }

  Future<void> _stop() async {
    if (_stopInProgress) return;
    var generation = _generation;
    setState(() => _stopInProgress = true);
    try {
      await _speech.stop();
      if (!mounted || generation != _generation) return;
      if (widget.continuous && _acceptResults) {
        _acceptResults = false;
        generation = ++_generation;
        await _speech.cancel();
        if (mounted && generation == _generation) {
          setState(() {
            _checkpointLiveWords();
            _busy = false;
            _stopInProgress = false;
            _preview.clear();
            _clearLiveWords();
            _message = _hasFullUnverifiedPreview
                ? 'quran_asr_repeat_unverified'
                : 'hifz_resume_message';
          });
        }
      }
    } on PlatformException catch (error) {
      if (generation == _generation) _inputFailed(generation, error.code);
    } finally {
      if (mounted && generation == _generation && _stopInProgress) {
        setState(() => _stopInProgress = false);
      }
    }
  }

  void _retainPausedWords(
    int startIndex,
    Map<String, int> counts, {
    int? maxAyahIndex,
    int? maxWordCountAtBoundary,
  }) {
    for (var i = startIndex; i < widget.ayahs.length; i++) {
      if (maxAyahIndex != null && i > maxAyahIndex) break;
      if (_revealed.contains(i)) continue;
      final ayah = widget.ayahs[i];
      final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
      var count = counts[key] ?? 0;
      if (maxAyahIndex != null &&
          i == maxAyahIndex &&
          maxWordCountAtBoundary != null &&
          count > maxWordCountAtBoundary) {
        count = maxWordCountAtBoundary;
      }
      if (count == 0) break;
      final words = _comparison.recitationWords(ayah.imlaei ?? '');
      if (i >= _index && !_finished && !_revealed.contains(i)) {
        final accepted = _acceptedWordCounts[key] ?? 0;
        if (count > accepted) {
          // This is a resume cursor, not a final transcript or scoring credit.
          _unverifiedAyahs.add(i);
          _pausedWordCounts[key] = count;
          _index = i;
          _acceptedWordCounts.remove(key);
          _pendingText = words.take(count).join(' ');
          _mismatchWord = null;
          _message = 'hifz_resume_message';
          if (count == words.length) {
            _pendingText = '';
            if (i + 1 < widget.ayahs.length) {
              _index++;
            } else {
              _message = 'quran_asr_repeat_unverified';
            }
          }
        }
      }
      if (count < words.length) break;
    }
  }

  Future<void> _reference() async {
    if (_playingReference) {
      ++_generation;
      setState(() {
        _loadingReference = false;
        _playingReference = false;
      });
      await widget.stopReference();
      return;
    }
    final targetIndex = _actionAyahIndex;
    final generation = ++_generation;
    _acceptResults = false;
    _stopInProgress = false;
    _viewedPageOverride = null;
    if (!widget.localQuranLab) _pendingText = '';
    _checkpointLiveWords();
    if (widget.localQuranLab &&
        widget.continuous &&
        targetIndex != _index &&
        targetIndex < widget.ayahs.length) {
      _index = targetIndex;
      final targetAyah = widget.ayahs[targetIndex];
      final targetKey = '${targetAyah.surahNumber}:${targetAyah.ayahNumber}';
      final paused = _pausedWordCounts[targetKey] ?? 0;
      _pendingText = paused > 0
          ? _comparison
                .recitationWords(targetAyah.imlaei ?? '')
                .take(paused)
                .join(' ')
          : '';
    }
    _preview.clear();
    _clearLiveWords();
    setState(() {
      _busy = false;
      _loadingReference = true;
    });
    try {
      await _lastCancellation;
      if (!mounted || generation != _generation) return;
      await _speech.cancel();
      await widget.stopReference();
      if (!mounted || generation != _generation) return;
      if (widget.localQuranLab && !widget.review) {
        setState(() => _assisted.add(_index));
      }
      final played = await widget.playReference(_ayah);
      if (!mounted || generation != _generation) {
        await widget.stopReference();
        return;
      }
      setState(() {
        _loadingReference = false;
        if (!played) {
          _playingReference = false;
          _message = 'mem_audio_error';
        }
      });
    } on PlatformException catch (error) {
      debugPrint('Memorization reference error: ${error.code}');
      if (mounted && generation == _generation) {
        setState(() {
          _loadingReference = false;
          _playingReference = false;
          _message = 'mem_audio_error';
        });
      }
    }
  }

  void _hint() {
    final activeIndex = _actionAyahIndex;
    final keepRecording =
        widget.localQuranLab &&
        widget.continuous &&
        _busy &&
        _acceptResults &&
        !_stopInProgress;
    if (!keepRecording) {
      _interrupt();
    }
    var stopAfterFinishing = false;
    setState(() {
      _viewedPageOverride = null;
      if (keepRecording) {
        final targetIndex = activeIndex < widget.ayahs.length
            ? activeIndex
            : _index;
        final targetAyah = widget.ayahs[targetIndex];
        final targetKey = '${targetAyah.surahNumber}:${targetAyah.ayahNumber}';
        final targetWordCount = _ayahWordCountAt(targetIndex);
        final baseBeforeHint = _hintBaseWordCountAt(targetIndex);
        _assisted.add(targetIndex);
        if (baseBeforeHint >= targetWordCount && targetWordCount > 0) {
          _revealed.add(targetIndex);
          _completedLiveWordCounts[targetKey] = targetWordCount;
          _liveWordCounts[targetKey] = targetWordCount;
          _rollingWordCounts[targetKey] = targetWordCount;
          if (targetIndex + 1 < widget.ayahs.length) {
            final nextIndex = targetIndex + 1;
            _assisted.add(nextIndex);
            _recordMistake(nextIndex, 1);
            final maxWords = _ayahWordCountAt(nextIndex);
            _hintWordCounts[nextIndex] = maxWords > 0 && 2 > maxWords
                ? maxWords
                : 2;
          } else {
            _finished = true;
            stopAfterFinishing = true;
          }
        } else {
          _recordMistake(targetIndex, baseBeforeHint + 1);
          final nextCount = baseBeforeHint + 2;
          _hintWordCounts[targetIndex] =
              targetWordCount > 0 && nextCount > targetWordCount
              ? targetWordCount
              : nextCount;
        }
        _mismatchWord = null;
        _message = _finished ? 'hifz_completed' : 'hifz_hint_used';
        return;
      }
      if (widget.localQuranLab &&
          widget.continuous &&
          activeIndex != _index &&
          activeIndex < widget.ayahs.length) {
        _index = activeIndex;
        final paused = _pausedWordCounts[_verseKey] ?? 0;
        _pendingText = paused > 0
            ? _comparison
                  .recitationWords(_ayah.imlaei ?? '')
                  .take(paused)
                  .join(' ')
            : '';
      }
      _assisted.add(_index);
      if (widget.localQuranLab) {
        if (widget.continuous &&
            _hintBaseWordCount >= _currentAyahWordCount &&
            _currentAyahWordCount > 0) {
          _revealed.add(_index);
          _pausedWordCounts.remove(_verseKey);
          _acceptedWordCounts.remove(_verseKey);
          _pendingText = '';
          if (_index + 1 < widget.ayahs.length) {
            _index++;
            _assisted.add(_index);
            _recordMistake(_index, 1);
            final maxWords = _currentAyahWordCount;
            _hintWordCounts[_index] = maxWords > 0 && 2 > maxWords
                ? maxWords
                : 2;
          } else {
            _finished = true;
          }
        } else {
          final baseBeforeHint = _hintBaseWordCount;
          _recordMistake(_index, baseBeforeHint + 1);
          final nextCount = baseBeforeHint + 2;
          final maxWords = _currentAyahWordCount;
          _hintWordCounts[_index] = maxWords > 0 && nextCount > maxWords
              ? maxWords
              : nextCount;
        }
      } else {
        _recordMistake(_index, 1);
        _hintWordCounts[_index] = 2;
        _pendingText = '';
      }
      if (!widget.continuous) _revealed.add(_index);
      _message = _finished
          ? 'hifz_completed'
          : widget.continuous
          ? 'hifz_hint_used'
          : 'mem_hint_used';
    });
    if (stopAfterFinishing) {
      _interrupt();
      setState(() => _message = 'hifz_completed');
    }
  }

  void _reveal() {
    final activeIndex = _actionAyahIndex;
    _interrupt();
    setState(() {
      _viewedPageOverride = null;
      if (widget.localQuranLab &&
          widget.continuous &&
          activeIndex > _index &&
          activeIndex < widget.ayahs.length) {
        for (var i = _index; i < activeIndex; i++) {
          _revealed.add(i);
        }
        _index = activeIndex;
      } else if (widget.localQuranLab && widget.continuous) {
        for (var i = 0; i < _index; i++) {
          final ayah = widget.ayahs[i];
          final words = _comparison.recitationWords(ayah.imlaei ?? '');
          final paused = _effectiveWordCount(i);
          if (words.isNotEmpty && paused >= words.length) {
            _revealed.add(i);
          }
        }
        while (_index < widget.ayahs.length) {
          final ayah = widget.ayahs[_index];
          final words = _comparison.recitationWords(ayah.imlaei ?? '');
          final paused = _effectiveWordCount(_index);
          final hinted = _hintWordCounts[_index] ?? 0;
          if (!_revealed.contains(_index) &&
              paused < words.length &&
              hinted < words.length) {
            break;
          }
          _revealed.add(_index);
          _navigationWordCounts.remove(_verseKey);
          _hintWordCounts.remove(_index);
          _index++;
        }
      }
      if (_index >= widget.ayahs.length) {
        _index = widget.ayahs.length - 1;
        _finished = true;
        return;
      }
      _assisted.add(_index);
      _revealed.add(_index);
      _navigationWordCounts.remove(_verseKey);
      _hintWordCounts.remove(_index);
      _pausedWordCounts.remove(_verseKey);
      _acceptedWordCounts.clear();
      _pendingText = '';
      var nextIndex = _index + 1;
      if (widget.localQuranLab && widget.continuous) {
        while (nextIndex < widget.ayahs.length) {
          final ayah = widget.ayahs[nextIndex];
          final words = _comparison.recitationWords(ayah.imlaei ?? '');
          final paused = _effectiveWordCount(nextIndex);
          if (!_revealed.contains(nextIndex) && paused < words.length) break;
          _revealed.add(nextIndex);
          nextIndex++;
        }
      }
      if (nextIndex < widget.ayahs.length) {
        _index = nextIndex;
        final nextAyah = widget.ayahs[_index];
        final nextKey = '${nextAyah.surahNumber}:${nextAyah.ayahNumber}';
        final paused = _pausedWordCounts[nextKey] ?? 0;
        _pendingText = paused > 0
            ? _comparison
                  .recitationWords(nextAyah.imlaei ?? '')
                  .take(paused)
                  .join(' ')
            : '';
        _message = 'hifz_resume_message';
      } else {
        _index = widget.ayahs.length - 1;
        _finished = true;
      }
    });
  }

  void _select(int index) {
    final visibleBeforeInterrupt = _visibleWordCounts;
    _interrupt();
    setState(() {
      _viewedPageOverride = null;
      if (widget.localQuranLab && widget.continuous) {
        for (final counts in [visibleBeforeInterrupt, _visibleWordCounts]) {
          for (final entry in counts.entries) {
            if (entry.value > (_navigationWordCounts[entry.key] ?? 0)) {
              _navigationWordCounts[entry.key] = entry.value;
            }
          }
        }
      }
      _index = index;
      _pendingText = '';
      _acceptedWordCounts.clear();
      _pausedWordCounts.clear();
      _unverifiedAyahs.clear();
      _finished = false;
      _message = _matched.contains(index)
          ? 'mem_match'
          : _revealed.contains(index)
          ? 'mem_hint_used'
          : 'mem_ready';
    });
  }

  void _movePage(int direction) {
    if (_stopInProgress) return;
    final pages = widget.ayahs.map((ayah) => ayah.pageNumber).toSet().toList()
      ..sort();
    final currentPageIndex = pages.indexOf(_visiblePageNumber);
    final targetPageIndex = currentPageIndex + direction;
    if (currentPageIndex < 0 ||
        targetPageIndex < 0 ||
        targetPageIndex >= pages.length) {
      return;
    }
    final targetPage = pages[targetPageIndex];
    if (widget.localQuranLab &&
        widget.continuous &&
        (targetPage == _activePageNumber ||
            _busy ||
            _revealed.isNotEmpty ||
            _visibleWordCounts.isNotEmpty ||
            _navigationWordCounts.isNotEmpty)) {
      setState(() {
        _viewedPageOverride = targetPage == _activePageNumber
            ? null
            : targetPage;
      });
      return;
    }
    var targetIndex = widget.ayahs.indexWhere(
      (ayah) => ayah.pageNumber == targetPage,
    );
    var hasUnrevealedOnTargetPage = false;
    for (var i = 0; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final complete =
          widget.localQuranLab &&
          widget.continuous &&
          _effectiveWordCount(i) >=
              _comparison.recitationWords(ayah.imlaei ?? '').length;
      if (ayah.pageNumber == targetPage &&
          !_revealed.contains(i) &&
          !complete) {
        targetIndex = i;
        hasUnrevealedOnTargetPage = true;
        break;
      }
    }
    if (targetIndex < 0) return;
    if (targetIndex == _index || !hasUnrevealedOnTargetPage) {
      setState(() {
        _viewedPageOverride = targetPage == _activePageNumber
            ? null
            : targetPage;
      });
      return;
    }
    _select(targetIndex);
  }

  void _finishPageSwipe(DragEndDetails details) {
    final distance = _pageDragDistance;
    _pageDragDistance = 0;
    final velocity = details.primaryVelocity ?? 0;
    if (distance.abs() < 48 && velocity.abs() < 250) return;
    final movement = distance.abs() >= 48 ? distance : velocity;
    _movePage(movement > 0 ? 1 : -1);
  }

  Future<void> _shareDiagnostics(BuildContext dialogContext) async {
    final l10n = AppLocalizations.of(context);
    final box = dialogContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize && box.size.longestSide > 0
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(1, 1, 1, 1);
    unawaited(
      QuranAsrSpeechInput.uploadDiagnosticsToCloud(verseKey: _verseKey),
    );
    final paths = await QuranAsrSpeechInput.exportDiagnostics();
    if (!mounted) return;
    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.get('quran_asr_share_empty'))),
      );
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: paths.map(XFile.new).toList(),
          subject:
              'Quran ASR Diagnostics (${widget.surahNameFor(_ayah.surahNumber)} ${_ayah.surahNumber}:${_ayah.ayahNumber})',
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      debugPrint('Quran ASR diagnostics share failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pageNumber = _visiblePageNumber;
    final statusTextStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.15);
    final metaTextStyle = statusTextStyle?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final buttonLabelStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        );
    final compactTextButtonStyle = TextButton.styleFrom(
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      minimumSize: const Size(0, 28),
      textStyle: buttonLabelStyle,
    );
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 42,
        title: Text(
          '${l10n.get(widget.review ? 'hifz_review' : 'tab_hifz')} — '
          '${widget.surahNameFor(_ayah.surahNumber)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!widget.review)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: l10n.get('mem_consent_title'),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.get('mem_consent_title')),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.continuous || widget.localQuranLab)
                            StatefulBuilder(
                              builder: (context, setModalState) =>
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      l10n.get(
                                        widget.localQuranLab
                                            ? 'quran_asr_word_preview'
                                            : 'hifz_live_preview',
                                      ),
                                    ),
                                    value: _livePreview,
                                    onChanged: (enabled) {
                                      setState(() {
                                        if (_windowed && _acceptResults) {
                                          _retainRollingWords(_index);
                                        }
                                        _livePreview = enabled;
                                        _preview.clear();
                                        _clearLiveWords(
                                          keepRolling:
                                              _windowed && _acceptResults,
                                        );
                                      });
                                      setModalState(() {});
                                    },
                                  ),
                            ),
                          Text(
                            l10n.get(
                              widget.localQuranLab
                                  ? 'quran_asr_live_warning'
                                  : widget.continuous
                                  ? 'hifz_intro'
                                  : 'mem_intro',
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      if (widget.localQuranLab)
                        Builder(
                          builder: (buttonContext) => TextButton.icon(
                            onPressed: () => _shareDiagnostics(buttonContext),
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: Text(
                              l10n.get('quran_asr_share_diagnostics'),
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          MaterialLocalizations.of(context).okButtonLabel,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<Ayah>>(
                future: _page(pageNumber),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.get('quran_page_unavailable')),
                          TextButton(
                            onPressed: () => setState(() {
                              _pageLoads.remove(pageNumber);
                            }),
                            child: Text(l10n.get('retry')),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData ||
                      snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final pageAyahs = snapshot.data!;
                  if (pageAyahs.isEmpty) {
                    return Center(
                      child: Text(l10n.get('quran_page_unavailable')),
                    );
                  }
                  final recognizedAyahs = {
                    if (widget.localQuranLab && !widget.review)
                      for (final i in _revealed)
                        if (!_assisted.contains(i))
                          '${widget.ayahs[i].surahNumber}:${widget.ayahs[i].ayahNumber}',
                  };
                  final displayWordCounts = Map<String, int>.of(
                    _navigationWordCounts,
                  );
                  for (final entry in _visibleWordCounts.entries) {
                    if (entry.value > (displayWordCounts[entry.key] ?? 0)) {
                      displayWordCounts[entry.key] = entry.value;
                    }
                  }
                  final cursorIdx = _activeAyahIndex < widget.ayahs.length
                      ? _activeAyahIndex
                      : _index;
                  final cursorAyah = widget.ayahs[cursorIdx];
                  final cursorKey =
                      '${cursorAyah.surahNumber}:${cursorAyah.ayahNumber}';
                  final displayed = displayWordCounts[cursorKey] ?? 0;
                  final cursorWordIndex = displayed;
                  final cursorWordTotal = cursorAyah.imlaei != null
                      ? _comparison.recitationWords(cursorAyah.imlaei!).length
                      : cursorAyah.words.length;
                  final showActiveWordCursor =
                      !widget.review &&
                      !_finished &&
                      !_revealed.contains(cursorIdx) &&
                      !_preview.contains(cursorIdx) &&
                      cursorWordIndex < cursorWordTotal;
                  return GestureDetector(
                    onHorizontalDragStart: (_) => _pageDragDistance = 0,
                    onHorizontalDragUpdate: (details) {
                      _pageDragDistance += details.delta.dx;
                    },
                    onHorizontalDragEnd: _finishPageSwipe,
                    child: MushafPageContent(
                      key: ValueKey(pageNumber),
                      pageNumber: pageNumber,
                      ayahs: pageAyahs,
                      isLandscape: landscape,
                      textScale: 1,
                      highlightEnabled: true,
                      surahNameFor: widget.surahNameFor,
                      fitToViewport: true,
                      verticalGlyphScale: 1.18,
                      revealedWordCounts: displayWordCounts,
                      activeCursorWord: showActiveWordCursor
                          ? (cursorKey, cursorWordIndex)
                          : null,
                      activeCursorHasError:
                          showActiveWordCursor && _message == 'mem_mismatch',
                      highlightedWordIndices: {
                        for (final entry in displayWordCounts.entries)
                          entry.key: {
                            for (var index = 0; index < entry.value; index++)
                              index,
                          },
                        for (final ayah in pageAyahs)
                          if (recognizedAyahs.contains(
                            '${ayah.surahNumber}:${ayah.ayahNumber}',
                          ))
                            '${ayah.surahNumber}:${ayah.ayahNumber}': {
                              for (
                                var index = 0;
                                index < ayah.words.length;
                                index++
                              )
                                index,
                            },
                      },
                      hintedWords: {
                        for (final entry in _hintWordCounts.entries)
                          if (!_revealed.contains(entry.key) &&
                              !_preview.contains(entry.key))
                            '${widget.ayahs[entry.key].surahNumber}:${widget.ayahs[entry.key].ayahNumber}':
                                entry.value,
                      },
                      hiddenAyahs: {
                        if (!widget.review)
                          for (var i = 0; i < widget.ayahs.length; i++)
                            if (!_revealed.contains(i) && !_preview.contains(i))
                              '${widget.ayahs[i].surahNumber}:${widget.ayahs[i].ayahNumber}',
                      },
                    ),
                  );
                },
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.continuous && !widget.review
                    ? (landscape ? 52 : 56)
                    : 0,
                maxHeight: widget.continuous && !widget.review
                    ? (landscape
                          ? (MediaQuery.sizeOf(context).width >= 700 ? 60 : 64)
                          : 68)
                    : MediaQuery.sizeOf(context).height * 0.16,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.review &&
                        (widget.continuous || widget.localQuranLab))
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 1,
                          height: 1,
                          child: FittedBox(
                            child: Opacity(
                              opacity: 0,
                              child: SizedBox(
                                width: 320,
                                height: 32,
                                child: SwitchListTile(
                                  dense: true,
                                  visualDensity: const VisualDensity(
                                    horizontal: 0,
                                    vertical: -4,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  title: Text(
                                    l10n.get(
                                      widget.localQuranLab
                                          ? 'quran_asr_word_preview'
                                          : 'hifz_live_preview',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: statusTextStyle?.copyWith(
                                      fontSize: 11,
                                    ),
                                  ),
                                  value: _livePreview,
                                  onChanged: (enabled) => setState(() {
                                    if (_windowed && _acceptResults) {
                                      _retainRollingWords(_index);
                                    }
                                    _livePreview = enabled;
                                    _preview.clear();
                                    _clearLiveWords(
                                      keepRolling: _windowed && _acceptResults,
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_hasStarted && !widget.continuous && !widget.review)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          l10n.get(
                            widget.localQuranLab
                                ? 'quran_asr_live_warning'
                                : 'mem_intro',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 10.5, height: 1.15),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 1,
                        height: 1,
                        child: FittedBox(
                          child: Opacity(
                            opacity: 0,
                            child: SizedBox(
                              width: 320,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 2,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '${l10n.get('ayah')} ${l10n.digits(_index + 1)}'
                                        ' / ${l10n.digits(widget.ayahs.length)}',
                                        style: metaTextStyle,
                                      ),
                                      if (widget.localQuranLab &&
                                          widget.continuous &&
                                          !widget.review &&
                                          !_finished &&
                                          !_hasFullUnverifiedPreview)
                                        Text(
                                          '${l10n.get('quran_asr_next_word')}: '
                                          '${l10n.digits(_nextLabWord)}',
                                          style: metaTextStyle,
                                        ),
                                      if (widget.continuous && !widget.review)
                                        Text(
                                          '${l10n.get('hifz_unaided')}: ${l10n.digits(_matched.length)}'
                                          ' · ${l10n.get(widget.localQuranLab ? 'quran_asr_assisted' : 'hifz_assisted')}: ${l10n.digits(_assisted.length)}',
                                          style: metaTextStyle,
                                        ),
                                    ],
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 2,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          _finished
                                              ? l10n.get('mem_done')
                                              : widget.review
                                              ? l10n.get('hifz_review_intro')
                                              : '${l10n.get(widget.continuous && _message == 'mem_ready' ? 'hifz_ready' : _message)}'
                                                    '${_mismatchWord == null ? '' : ' ${l10n.digits(_mismatchWord!)}'}',
                                          style: statusTextStyle,
                                        ),
                                      ),
                                      if (widget.localQuranLab &&
                                          (_unverifiedAyahs.isNotEmpty ||
                                              _pausedWordCounts.isNotEmpty ||
                                              _navigationWordCounts
                                                  .isNotEmpty ||
                                              (_livePreview &&
                                                  _liveWordCounts.isNotEmpty)))
                                        Text(
                                          l10n.get(
                                            _pausedWordCounts.isNotEmpty ||
                                                    _navigationWordCounts
                                                        .isNotEmpty ||
                                                    _unverifiedAyahs.isNotEmpty
                                                ? 'quran_asr_retained_preview'
                                                : 'hifz_provisional',
                                          ),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontSize: statusTextStyle?.fontSize,
                                            height: 1.15,
                                          ),
                                        ),
                                      if (_preview.isNotEmpty)
                                        Text(
                                          '${l10n.get('hifz_provisional')}: '
                                          '${_preview.map((i) => l10n.digits(widget.ayahs[i].ayahNumber)).join(', ')}',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontSize: statusTextStyle?.fontSize,
                                            height: 1.15,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!widget.continuous || widget.review)
                      DropdownButton<int>(
                        isExpanded: true,
                        isDense: true,
                        value: _index,
                        onChanged: _busy ? null : (index) => _select(index!),
                        items: [
                          for (var i = 0; i < widget.ayahs.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                '${widget.surahNameFor(widget.ayahs[i].surahNumber)} — '
                                '${l10n.get('ayah')} ${l10n.digits(widget.ayahs[i].ayahNumber)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    if (_transcript.isNotEmpty && !widget.localQuranLab)
                      Text(
                        '${l10n.get('mem_heard')}: $_transcript',
                        textDirection: TextDirection.rtl,
                        style: statusTextStyle,
                      ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!widget.review)
                          SizedBox(
                            width: 1,
                            height: 1,
                            child: FittedBox(
                              child: Opacity(
                                opacity: 0,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('hifz-mistakes-pill'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: const VisualDensity(
                                      horizontal: -2,
                                      vertical: -3,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3,
                                    ),
                                    minimumSize: const Size(0, 28),
                                    shape: const StadiumBorder(),
                                    side: BorderSide(
                                      color: _mistakes.isNotEmpty
                                          ? const Color(
                                              0xFFD32F2F,
                                            ).withValues(alpha: 0.50)
                                          : Theme.of(context).dividerColor,
                                    ),
                                    foregroundColor: _mistakes.isNotEmpty
                                        ? const Color(0xFFD32F2F)
                                        : null,
                                    textStyle: buttonLabelStyle,
                                  ),
                                  onPressed: _showMistakesSheet,
                                  icon: Icon(
                                    _mistakes.isNotEmpty
                                        ? Icons.error_outline
                                        : Icons.history,
                                    size: 14,
                                  ),
                                  label: Text(
                                    _mistakes.isEmpty
                                        ? l10n.get('hifz_mistakes')
                                        : '${l10n.get('hifz_mistakes')} (${l10n.digits(_mistakes.length)})',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Container(
                          key: const ValueKey('hifz-floating-control-pill'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(
                                0xFF1D9E75,
                              ).withValues(alpha: 0.28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF1D9E75,
                                ).withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!widget.review)
                                TextButton.icon(
                                  style: compactTextButtonStyle,
                                  onPressed:
                                      (_busy &&
                                              !_acceptResults &&
                                              !_stopInProgress) ||
                                          _finished ||
                                          _revealed.contains(
                                            _activeAyahIndex <
                                                    widget.ayahs.length
                                                ? _activeAyahIndex
                                                : _index,
                                          ) ||
                                          (widget.continuous &&
                                              !widget.localQuranLab &&
                                              _hintWordCounts.containsKey(
                                                _index,
                                              ))
                                      ? null
                                      : _hint,
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    size: 16,
                                  ),
                                  label: Text(
                                    l10n.get(
                                      widget.continuous
                                          ? 'hifz_hint'
                                          : 'mem_hint',
                                    ),
                                  ),
                                ),
                              if (widget.continuous && !widget.review)
                                TextButton.icon(
                                  style: compactTextButtonStyle,
                                  onPressed:
                                      (_busy &&
                                              !_acceptResults &&
                                              !_stopInProgress) ||
                                          _finished
                                      ? null
                                      : _reveal,
                                  icon: const Icon(
                                    Icons.keyboard_double_arrow_left,
                                    size: 16,
                                  ),
                                  label: Text(l10n.get('hifz_reveal')),
                                ),
                              TextButton.icon(
                                key: const ValueKey('hifz-listen-button'),
                                style: _playingReference
                                    ? compactTextButtonStyle.copyWith(
                                        foregroundColor: WidgetStatePropertyAll(
                                          Theme.of(context).colorScheme.error,
                                        ),
                                      )
                                    : compactTextButtonStyle,
                                onPressed:
                                    _loadingReference ||
                                        (_busy &&
                                            !_acceptResults &&
                                            !_stopInProgress)
                                    ? null
                                    : _reference,
                                icon: _loadingReference
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _playingReference
                                            ? Icons.stop_rounded
                                            : Icons.menu_book_outlined,
                                        size: 15,
                                      ),
                                label: Text(
                                  l10n.get(
                                    _playingReference ? 'stop' : 'mem_replay',
                                  ),
                                ),
                              ),
                              if (!widget.continuous || widget.review)
                                TextButton(
                                  style: compactTextButtonStyle,
                                  onPressed:
                                      _stopInProgress ||
                                          _busy ||
                                          (!widget.review &&
                                              !_revealed.contains(_index)) ||
                                          _finished
                                      ? null
                                      : () {
                                          if (_index + 1 <
                                              widget.ayahs.length) {
                                            _select(_index + 1);
                                          } else {
                                            if (widget.review) {
                                              _interrupt();
                                              setState(() => _finished = true);
                                              return;
                                            }
                                            final remaining = [
                                              for (
                                                var i = 0;
                                                i < widget.ayahs.length;
                                                i++
                                              )
                                                if (!_revealed.contains(i)) i,
                                            ];
                                            if (remaining.isNotEmpty) {
                                              _select(remaining.first);
                                            } else {
                                              _interrupt();
                                              setState(() => _finished = true);
                                            }
                                          }
                                        },
                                  child: Text(l10n.get('mem_next')),
                                ),
                            ],
                          ),
                        ),
                        if (!widget.review)
                          Builder(
                            builder: (context) {
                              final micLabel = l10n.get(
                                _stopInProgress
                                    ? 'hifz_finalizing'
                                    : _acceptResults
                                    ? (widget.continuous
                                          ? 'hifz_pause'
                                          : 'mem_stop')
                                    : _message == 'mem_error'
                                    ? 'retry'
                                    : widget.continuous
                                    ? (_hasStarted
                                          ? 'hifz_resume'
                                          : 'hifz_start')
                                    : 'mem_listen',
                              );
                              final onMicPressed = _acceptResults
                                  ? (_stopInProgress ? null : _stop)
                                  : _stopInProgress ||
                                        _busy ||
                                        _finished ||
                                        (!widget.continuous &&
                                            _revealed.contains(_index))
                                  ? null
                                  : _listen;
                              const baseColor = Color(0xFF1D9E75);
                              return DecoratedBox(
                                key: const ValueKey('hifz-glowing-mic-fab'),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: onMicPressed == null
                                      ? const []
                                      : [
                                          BoxShadow(
                                            color: baseColor.withValues(
                                              alpha: _acceptResults
                                                  ? 0.48
                                                  : 0.30,
                                            ),
                                            blurRadius: _acceptResults
                                                ? 16
                                                : 10,
                                            spreadRadius: _acceptResults
                                                ? 2
                                                : 0.5,
                                          ),
                                        ],
                                ),
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: baseColor,
                                    foregroundColor: Colors.white,
                                    visualDensity: const VisualDensity(
                                      horizontal: -1,
                                      vertical: -2,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    minimumSize: const Size(44, 34),
                                    shape: const StadiumBorder(),
                                    textStyle: buttonLabelStyle,
                                  ),
                                  onPressed: onMicPressed,
                                  icon: _stopInProgress
                                      ? const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _acceptResults
                                              ? Icons.stop_rounded
                                              : Icons.mic_rounded,
                                          size: 18,
                                        ),
                                  label: Text(micLabel),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
