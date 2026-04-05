import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/models/tajweed_models.dart';
import '../../core/providers/bookmark_provider.dart';
import '../../core/providers/daily_lesson_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/reader_navigation_provider.dart';
import '../../core/providers/recitation_provider.dart';
import '../../core/providers/streak_provider.dart';
import '../../core/providers/tafseer_provider.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/audio_cache_service.dart';
import '../../core/services/ayah_mapper.dart';
import '../../core/services/quran_offline_sync_service.dart';
import '../../core/services/quran_api_service.dart';
import '../../core/services/mushaf_assets_service.dart';
import '../reader/widgets/audio_player_bar.dart';
import '../reader/widgets/tajweed_text.dart';
import '../reader/widgets/tafseer_sheet.dart';
import '../reader/widgets/word_detail_sheet.dart';
import '../rules/rule_detail_screen.dart';
import '../rules/rules_repository.dart';
import '../settings/settings_screen.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

enum _ReaderViewMode { page, ayah }

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  static const String _readerViewModeKey = 'reader_view_mode';

  final _api = QuranApiService();
  final _audio = AudioService();
  final _audioCache = AudioCacheService();
  final _quranOfflineSync = QuranOfflineSyncService();
  late final ScrollController _scrollController;
  final PageController _mushafPageController = PageController();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;

  // Mushaf pages: downloaded on first launch from GitHub Releases.
  String? _mushafPagesDirPath;
  Object? _mushafPagesError;
  bool _isMushafDownloading = false;
  int _downloadReceived = 0;
  int _downloadTotal = 0;

  int _selectedSurah = 1;
  bool _tajweedEnabled = true;
  final bool _showTranslation = true;
  _ReaderViewMode _viewMode = _ReaderViewMode.ayah;
  List<Ayah> _ayahs = [];
  bool _loading = true;
  List<Map<String, dynamic>> _allSurahs = [];
  Map<String, String> _audioUrls = {};

  // Debounce timer for scroll position saving
  Timer? _scrollSaveTimer;

  // Audio state
  bool _isPlayingAll = false;
  int? _playingAyahNumber;
  int _activeWordIndex = -1;
  int _lastObservedReciterId = -1;
  int _surahLoadVersion = 0;
  int _playRequestToken = 0;
  int _downloadedAyahs = 0;
  int _totalAyahs = 0;
  bool _isDownloadingSurahAudio = false;
  bool _isDownloadingSurahTafseer = false;
  int _currentMushafPageIndex = 0;
  bool _showMushafScrubber = false;
  bool _isMushafScrubberDragging = false;
  int? _mushafScrubberPreviewPage;
  Timer? _mushafScrubberHideTimer;
  int? _ayahModeAnchorAyah;
  int? _mushafAnchorSurah;
  int? _mushafCurrentAnchorAyah;
  int? _mushafCurrentAnchorSurah;
  double? _ayahModeReturnOffset;
  int? _mushafEntryAnchorAyah;
  int? _mushafEntrySurah;
  int? _mushafEntryPageNumber;
  final Map<int, _MushafPageAnchor> _mushafPageAnchorCache = {};

  // Juz boundaries: ayahNumber → juz number (only for first ayah of each juz in this surah)
  Map<int, int> _juzBoundaries = {};

  // Target scroll offset to restore after loading a surah (used only for
  // in-session reciter-change reloads where the pixel offset is still valid).
  double _pendingScrollOffset = 0.0;

  // Target ayah to restore after loading a different surah (e.g. bookmark
  // cross-surah navigation). Pixel offsets from Hive may be stale after
  // font-size / line-height changes, so we always navigate by ayah number.
  int? _pendingScrollAyah;

  // Flag to avoid saving scroll position while automatic jump is in progress
  bool _isProgrammaticScroll = false;
  int _scrollToAyahRequestId = 0;
  bool _didInitialReopenRestore = false;
  int? _lastKnownVisibleAyah;
  int _suppressAutoSaveUntilMs = 0;
  int? _startupRestoreTargetAyah;
  int _restoreGuardToken = 0;
  bool _userInterruptedRestore = false;

  // GlobalKeys for scrolling to specific ayahs
  final Map<int, GlobalKey> _ayahKeys = {};
  ReaderNavigationProvider? _readerNavigationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockPortraitForReader();

    _loadSavedReaderViewMode();

    // Restore last read position
    final bookmarks = context.read<BookmarkProvider>();
    _selectedSurah = bookmarks.lastReadSurah;
    _ayahModeAnchorAyah = bookmarks.lastReadAyah;
    _scrollController = ScrollController(
      initialScrollOffset: 0.0,
    );
    print(
        '📱 initState: restored surah=$_selectedSurah, lastReadAyah=${bookmarks.lastReadAyah}');

    _initializeMushafPages();

    _initData();

    // Listen for audio completion
    _playerStateSub = _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (!_isPlayingAll && mounted) {
          setState(() {
            _playingAyahNumber = null;
            _activeWordIndex = -1;
          });
        }
      }
    });

    // Track playback position and estimate active word index.
    _positionSub = _audio.positionStream.listen((position) {
      if (!mounted || _playingAyahNumber == null) return;
      final total = _audio.duration;
      if (total == null || total.inMilliseconds <= 0) return;

      final ayahIdx =
          _ayahs.indexWhere((a) => a.ayahNumber == _playingAyahNumber);
      if (ayahIdx < 0) return;
      final wordCount = _ayahs[ayahIdx].words.length;
      if (wordCount <= 0) return;

      final ratio =
          (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 0.9999);
      final nextWordIndex = (ratio * wordCount).floor().clamp(0, wordCount - 1);

      if (nextWordIndex != _activeWordIndex) {
        setState(() => _activeWordIndex = nextWordIndex);
      }
    });

    // Debounced scroll tracking - save every 1 second while scrolling
    _scrollController.addListener(() {
      _scrollSaveTimer?.cancel();
      _scrollSaveTimer =
          Timer(const Duration(milliseconds: 500), _saveScrollPosition);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _readerNavigationProvider = context.read<ReaderNavigationProvider>();
      _readerNavigationProvider?.addListener(_handleExternalReaderNavigation);
      _handleExternalReaderNavigation();
    });
  }

  void _handleExternalReaderNavigation() {
    final provider = _readerNavigationProvider;
    if (!mounted || provider == null) return;
    final request = provider.consumePending();
    if (request == null) return;

    // Record lesson progress immediately for direct Today Lesson jumps so
    // completion is not delayed by scroll debounce/visibility heuristics.
    unawaited(context
        .read<DailyLessonProvider>()
        .markReaderProgress(
          surah: request.surah,
          ayah: request.ayah,
        )
        .then((completedNow) async {
      if (!completedNow || !mounted) return;
      await context.read<StreakProvider>().recordActivity();
    }));

    _stopAudio();
    _persistReaderViewMode(_ReaderViewMode.ayah);
    setState(() {
      _viewMode = _ReaderViewMode.ayah;
      _selectedSurah = request.surah;
      _pendingScrollAyah = request.ayah;
      _pendingScrollOffset = 0.0;
      _didInitialReopenRestore = true;
    });

    context.read<BookmarkProvider>().saveLastRead(
          request.surah,
          request.ayah,
          scrollOffset: 0.0,
          caller: '[home/todays-lesson]',
        );

    _loadSurah();
  }

  void _loadSavedReaderViewMode() {
    try {
      final box = Hive.box('settings');
      final saved = box.get(_readerViewModeKey,
          defaultValue: _ReaderViewMode.ayah.name) as String;
      _viewMode = saved == _ReaderViewMode.page.name
          ? _ReaderViewMode.page
          : _ReaderViewMode.ayah;
    } catch (_) {
      _viewMode = _ReaderViewMode.ayah;
    }
  }

  void _initializeMushafPages() {
    _mushafPagesError = null;
    _isMushafDownloading = true;
    _downloadReceived = 0;
    _downloadTotal = 0;

    unawaited(MushafAssetsService.getMushafPagesDir(
      onProgress: (received, total) {
        if (mounted && total > 0) {
          setState(() {
            _downloadReceived = received;
            _downloadTotal = total;
          });
        }
      },
    ).then((dir) {
      if (!mounted) return;
      setState(() {
        _mushafPagesDirPath = dir.path;
      });
    }).catchError((error) {
      if (!mounted) return;
      setState(() {
        _mushafPagesError = error;
      });
    }).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _isMushafDownloading = false;
      });
    }));
  }

  void _persistReaderViewMode(_ReaderViewMode mode) {
    try {
      final box = Hive.box('settings');
      unawaited(box.put(_readerViewModeKey, mode.name));
    } catch (_) {
      // Ignore persistence failures and keep runtime state.
    }
  }

  void _setRestoreGuard(int ayahNumber, {int durationMs = 2200}) {
    final token = ++_restoreGuardToken;
    _startupRestoreTargetAyah = ayahNumber;
    _suppressAutoSaveUntilMs =
        DateTime.now().millisecondsSinceEpoch + durationMs;
    _userInterruptedRestore = false;

    _scheduleRestoreGuardRelease(
      token: token,
      targetAyah: ayahNumber,
      delayMs: durationMs + 250,
      remainingChecks: 6,
    );
  }

  void _scheduleRestoreGuardRelease({
    required int token,
    required int targetAyah,
    required int delayMs,
    required int remainingChecks,
  }) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted || token != _restoreGuardToken) return;

      final shouldReleaseImmediately =
          _viewMode != _ReaderViewMode.ayah || _userInterruptedRestore;
      if (shouldReleaseImmediately) {
        debugPrint('🧭 Restore guard release: immediate '
            '(mode=$_viewMode, userInterrupted=$_userInterruptedRestore)');
        _startupRestoreTargetAyah = null;
        _suppressAutoSaveUntilMs = 0;
        return;
      }

      final visibleAyah = _findTopVisibleAyahNumber();
      final aligned = visibleAyah != null && (visibleAyah - targetAyah).abs() <= 0;
      debugPrint('🧭 Restore guard check: target=$targetAyah, '
          'visible=${visibleAyah ?? '-'}, aligned=$aligned, '
          'remaining=$remainingChecks');
      if (aligned || remainingChecks <= 0) {
        debugPrint('🧭 Restore guard release: '
            '${aligned ? 'aligned' : 'retries-exhausted'}');
        _startupRestoreTargetAyah = null;
        _suppressAutoSaveUntilMs = 0;
        return;
      }

      _scrollToAyah(
        targetAyah,
        maxAttempts: 10,
        alignment: 0.0,
        allowSeedJump: true,
      );
      _suppressAutoSaveUntilMs =
          DateTime.now().millisecondsSinceEpoch + 900;

      _scheduleRestoreGuardRelease(
        token: token,
        targetAyah: targetAyah,
        delayMs: 950,
        remainingChecks: remainingChecks - 1,
      );
    });
  }

  void _cancelProgrammaticAyahScroll() {
    _scrollToAyahRequestId++;
    _isProgrammaticScroll = false;
    _userInterruptedRestore = true;
  }

  void _saveScrollPosition() {
    try {
      if (_ayahs.isEmpty || !mounted) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_viewMode == _ReaderViewMode.ayah &&
          nowMs < _suppressAutoSaveUntilMs) {
        if (_startupRestoreTargetAyah != null) {
          final targetAyah = _startupRestoreTargetAyah!;
          final visibleAyah = _findTopVisibleAyahNumber();
          if (!_userInterruptedRestore &&
              !_isProgrammaticScroll &&
              visibleAyah != null &&
              (visibleAyah - targetAyah).abs() > 0) {
            _scrollToAyah(
              targetAyah,
              maxAttempts: 10,
              alignment: 0.0,
              allowSeedJump: true,
            );
          }

          final scrollOffset =
              _scrollController.hasClients ? _scrollController.offset : 0.0;
          context.read<BookmarkProvider>().saveLastRead(
                _selectedSurah,
                targetAyah,
                scrollOffset: scrollOffset,
                caller: '[ayah-mode/startup-restore]',
              );
        }
        return;
      }

      if (_viewMode == _ReaderViewMode.page) {
        final anchorSurah = _currentMushafAnchorSurah();
        final anchorAyah = _currentMushafAnchorAyah();
        context.read<BookmarkProvider>().saveLastRead(
              anchorSurah,
              anchorAyah,
              scrollOffset: 0.0,
              caller: '[page-mode/scroll]',
            );
        return;
      }

      int? topVisibleAyah = _findTopVisibleAyahNumber();
      if (topVisibleAyah != null) {
        _lastKnownVisibleAyah = topVisibleAyah;
      }

      if (topVisibleAyah == null && _playingAyahNumber != null) {
        topVisibleAyah = _playingAyahNumber;
      }
      if (topVisibleAyah == null &&
          _scrollController.hasClients &&
          _ayahs.isNotEmpty) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          final progress =
              (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
          final idx = (progress * (_ayahs.length - 1))
              .round()
              .clamp(0, _ayahs.length - 1);
          topVisibleAyah = _ayahs[idx].ayahNumber;
        } else {
          topVisibleAyah = _ayahs.first.ayahNumber;
        }
      }
      topVisibleAyah ??= _lastKnownVisibleAyah;

      if (_isProgrammaticScroll) {
        // Ignore automatic jump positions until the final scroll settle.
        return;
      }

      if (topVisibleAyah != null && mounted) {
        try {
          final scrollOffset =
              _scrollController.hasClients ? _scrollController.offset : 0.0;
          context.read<BookmarkProvider>().saveLastRead(
              _selectedSurah, topVisibleAyah,
              scrollOffset: scrollOffset, caller: '[ayah-mode/scroll]');
          unawaited(_recordTodayLessonProgress(topVisibleAyah));
        } catch (e) {
          print('❌ Error saving to BookmarkProvider: $e');
        }
      }
    } catch (e) {
      print('❌ Error in _saveScrollPosition: $e');
    }
  }

  Future<void> _recordTodayLessonProgress(int ayahNumber) async {
    if (!mounted) return;

    final completedNow =
        await context.read<DailyLessonProvider>().markReaderProgress(
              surah: _selectedSurah,
              ayah: ayahNumber,
            );

    if (completedNow && mounted) {
      await context.read<StreakProvider>().recordActivity();
    }
  }

  Future<void> _initData() async {
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    try {
      final surahs = await _api.fetchSurahList(langCode: langCode);
      if (mounted) setState(() => _allSurahs = surahs);
    } catch (_) {}
    _loadSurah();
  }

  @override
  void dispose() {
    // Cancel the scroll save timer
    _scrollSaveTimer?.cancel();
    _mushafScrubberHideTimer?.cancel();
    // Save position one final time before closing
    _saveScrollPosition();
    WidgetsBinding.instance.removeObserver(this);
    _restoreAppOrientations();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _readerNavigationProvider?.removeListener(_handleExternalReaderNavigation);
    _mushafPageController.dispose();
    _audio.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _scrollSaveTimer?.cancel();
      _saveScrollPosition();
    }
  }

  void _lockPortraitForReader() {
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
  }

  void _restoreAppOrientations() {
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  Future<void> _loadSurah() async {
    final loadVersion = ++_surahLoadVersion;
    setState(() {
      _loading = true;
      _ayahs = [];
      _audioUrls = {};
      _juzBoundaries = {};
      _mushafPageAnchorCache.clear();
    });
    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    _lastObservedReciterId = reciterId;

    try {
      final cachedVerses =
          await _quranOfflineSync.getCachedSurah(_selectedSurah);
      final allVerses = <Map<String, dynamic>>[];
      Map<String, String> tajweedMap = <String, String>{};

      if (cachedVerses != null && cachedVerses.isNotEmpty) {
        allVerses.addAll(cachedVerses);
        tajweedMap =
            await _quranOfflineSync.getCachedTajweedMap(_selectedSurah);
      } else {
        int page = 1;
        while (true) {
          final verses = await _api.fetchVerses(
            surahNumber: _selectedSurah,
            langCode: 'ar',
            reciterId: reciterId,
            page: page,
          );
          allVerses.addAll(verses);
          if (verses.length < 50) break;
          page++;
        }

        tajweedMap = await _api.fetchTajweedText(chapterNumber: _selectedSurah);
        // Persist immediately so restart does not lose freshly loaded surah.
        await _quranOfflineSync.saveSurahCache(
          surahNumber: _selectedSurah,
          verses: allVerses,
          tajweedMap: tajweedMap,
        );
      }

      Map<String, String> audioMap = <String, String>{};
      try {
        audioMap = await _api.fetchAudioFiles(
          reciterId: reciterId,
          surahNumber: _selectedSurah,
        );
      } catch (_) {
        // Audio URLs are optional when offline. Cached audio still works.
      }

      await _loadJuzBoundaries();

      print('📻 AUDIO MAP KEYS: ${audioMap.keys.toList()}');
      print('📻 AUDIO MAP SIZE: ${audioMap.length}');
      if (audioMap.isNotEmpty) {
        print('📻 FIRST ENTRY: ${audioMap.entries.first}');
      } else {
        print('❌ AUDIO MAP IS EMPTY!');
      }

      if (mounted && loadVersion == _surahLoadVersion) {
        setState(() {
          _loading = false;
          _ayahs = AyahMapper.fromApiList(allVerses, tajweedMap: tajweedMap);
          _audioUrls = audioMap;
          _activeWordIndex = -1;
          _currentMushafPageIndex = 0;
          _ayahKeys.clear();
          for (final a in _ayahs) {
            _ayahKeys[a.ayahNumber] = GlobalKey();
          }
        });
        print('📻 AFTER SETSTATE: _audioUrls.length=${_audioUrls.length}');
        _refreshOfflineStatus();
        // Defer position restore until widgets are rendered.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restorePositionAfterSurahLoad();
        });
      }
    } catch (e) {
      print('❌ ERROR IN LOAD SURAH: $e');

      final fallbackSurah = await _quranOfflineSync.getFirstCachedSurahNumber();
      if (fallbackSurah != null && fallbackSurah != _selectedSurah) {
        final fallbackVerses =
            await _quranOfflineSync.getCachedSurah(fallbackSurah);
        if (fallbackVerses != null && fallbackVerses.isNotEmpty) {
          final fallbackTajweed =
              await _quranOfflineSync.getCachedTajweedMap(fallbackSurah);
          if (mounted && loadVersion == _surahLoadVersion) {
            setState(() {
              _selectedSurah = fallbackSurah;
              _loading = false;
              _ayahs = AyahMapper.fromApiList(
                fallbackVerses,
                tajweedMap: fallbackTajweed,
              );
              _audioUrls = {};
              _activeWordIndex = -1;
            });
          }
          return;
        }
      }

      if (mounted && loadVersion == _surahLoadVersion) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyReciterChange(int reciterId) {
    if (_lastObservedReciterId == -1) {
      _lastObservedReciterId = reciterId;
      return;
    }
    if (reciterId == _lastObservedReciterId) return;

    _lastObservedReciterId = reciterId;
    final currentOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    _stopAudio();
    setState(() {
      _pendingScrollOffset = currentOffset;
      _activeWordIndex = -1;
    });
    _loadSurah();
  }

  Future<Map<int, int>> _loadJuzBoundaries() async {
    try {
      final juzs = await _api.fetchJuzList();
      final boundaries = <int, int>{};
      final surahStr = _selectedSurah.toString();
      for (final j in juzs) {
        final juzNum = j['juz_number'] as int;
        final mappingRaw = j['verse_mapping'];
        final mapping = mappingRaw is Map
            ? Map<String, dynamic>.from(mappingRaw)
            : <String, dynamic>{};
        if (mapping.containsKey(surahStr)) {
          final range = mapping[surahStr] as String;
          final startAyah = int.tryParse(range.split('-').first) ?? 0;
          // Don't mark ayah 1 as a boundary (it's the surah start)
          if (startAyah > 1) {
            boundaries[startAyah] = juzNum;
          }
          // Also mark ayah 1 if this juz starts at ayah 1 and it's not juz 1
          // (i.e., a surah starts at the beginning of a juz)
          if (startAyah == 1 && juzNum > 1) {
            boundaries[1] = juzNum;
          }
        }
      }
      if (mounted) setState(() => _juzBoundaries = boundaries);
      return boundaries;
    } catch (_) {
      return {};
    }
  }

  void _scrollToLastReadAyah() {
    final bookmarks = context.read<BookmarkProvider>();
    if (bookmarks.lastReadSurah != _selectedSurah || _ayahs.isEmpty) {
      print(
          '⚠️ Not scrolling: mismatch/empty (lastReadSurah=${bookmarks.lastReadSurah}, _selectedSurah=$_selectedSurah, count=${_ayahs.length})');
      return;
    }
    print(
        '🎯 _scrollToLastReadAyah: ayah=${bookmarks.lastReadAyah} in surah $_selectedSurah');
    _scrollToAyah(bookmarks.lastReadAyah, alignment: 0.0);
  }

  /// Scrolls to [ayahNumber] in the current surah, navigating by index rather
  /// than by a saved pixel offset. Pixel offsets stored in Hive become stale
  /// whenever font-size or line-height changes; ayah numbers never do.
  ///
  /// How it works:
  ///   1. If the item is already rendered (key has context) → ensureVisible.
  ///   2. Otherwise seed the viewport with an index-proportional jumpTo so the
  ///      ListView builds items near the target, then recurse until it's found.
  ///
  /// Each iteration `maxScrollExtent` is more accurate (more items measured),
  /// so the seed converges quickly even for surahs with variable-height ayahs.
  void _scrollToAyah(
    int ayahNumber, {
    int maxAttempts = 15,
    bool allowSeedJump = true,
    double alignment = 0.18,
    int? requestId,
  }) {
    if (!mounted || _viewMode != _ReaderViewMode.ayah || _ayahs.isEmpty) return;

    final activeRequestId = requestId ?? ++_scrollToAyahRequestId;
    if (activeRequestId != _scrollToAyahRequestId) return;

    final key = _ayahKeys[ayahNumber];
    if (key?.currentContext != null) {
      _isProgrammaticScroll = true;
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: alignment,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ).then((_) {
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted && activeRequestId == _scrollToAyahRequestId) {
            _isProgrammaticScroll = false;
          }
        });
      });
      return;
    }

    if (maxAttempts <= 0) {
      if (activeRequestId == _scrollToAyahRequestId) {
        _isProgrammaticScroll = false;
      }
      return;
    }

    // Fixed-step directional search (no proportional/height estimation).
    if (allowSeedJump && _scrollController.hasClients) {
      final targetIdx = _ayahs.indexWhere((a) => a.ayahNumber == ayahNumber);
      if (targetIdx >= 0) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          final anchorAyah = _findTopVisibleAyahNumber() ?? _lastKnownVisibleAyah;
          final anchorIdx = anchorAyah == null
              ? -1
              : _ayahs.indexWhere((a) => a.ayahNumber == anchorAyah);
          final goingDown = anchorIdx >= 0
              ? targetIdx > anchorIdx
              : targetIdx >= (_ayahs.length ~/ 2);

            final deltaAyahs =
              anchorIdx >= 0 ? (targetIdx - anchorIdx).abs() : _ayahs.length;
            final stepPx = deltaAyahs <= 3
              ? 220.0
              : deltaAyahs <= 10
                ? 520.0
                : 1200.0;
          final current = _scrollController.offset;
          var seed =
              (current + (goingDown ? stepPx : -stepPx)).clamp(0.0, maxExtent);

          if ((seed - current).abs() < 0.5) {
            seed = (current + (goingDown ? -stepPx : stepPx))
                .clamp(0.0, maxExtent);
          }

          if (activeRequestId == _scrollToAyahRequestId) {
            _isProgrammaticScroll = true;
            _scrollController.jumpTo(seed);
          }
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (!mounted || activeRequestId != _scrollToAyahRequestId) return;
        _scrollToAyah(
          ayahNumber,
          maxAttempts: maxAttempts - 1,
          allowSeedJump: allowSeedJump,
          alignment: alignment,
          requestId: activeRequestId,
        );
      });
    });
  }

  bool _restoreAyahByNumber(int ayahNumber, {int retries = 0}) {
    final key = _ayahKeys[ayahNumber];
    if (key?.currentContext == null) {
      if (retries <= 0) return false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted && _viewMode == _ReaderViewMode.ayah) {
            _restoreAyahByNumber(ayahNumber, retries: retries - 1);
          }
        });
      });
      return false;
    }

    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      alignment: 0.18,
    );
    return true;
  }

  void _restorePositionAfterSurahLoad() {
    if (!mounted || _ayahs.isEmpty) return;

    if (_viewMode == _ReaderViewMode.page) {
      _didInitialReopenRestore = true;
      _restoreMushafPageForLastRead();
      return;
    }

    if (_pendingScrollOffset > 0) {
      // In-session reciter-change reload: pixel offset is still valid.
      _restoreScrollOffset(_pendingScrollOffset);
      _pendingScrollOffset = 0.0;
    } else if (_pendingScrollAyah != null) {
      // Cross-surah bookmark navigation: scroll by ayah number.
      final ayah = _pendingScrollAyah!;
      _pendingScrollAyah = null;
      _setRestoreGuard(ayah, durationMs: 2200);
      _scrollToAyah(ayah, maxAttempts: 20, alignment: 0.0, allowSeedJump: true);
      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted || _viewMode != _ReaderViewMode.ayah) return;
        _scrollToAyah(ayah,
            maxAttempts: 8, alignment: 0.0, allowSeedJump: true);
      });
    } else {
      // First restore after app launch: always anchor by ayah number.
      // Pixel offsets can drift across text metrics or layout changes.
      if (!_didInitialReopenRestore) {
        final bookmarks = context.read<BookmarkProvider>();
        if (bookmarks.lastReadSurah == _selectedSurah) {
          final targetAyah = bookmarks.lastReadAyah;
          _setRestoreGuard(targetAyah, durationMs: 2200);
          _scrollToAyah(targetAyah, maxAttempts: 20, alignment: 0.0);
          Future.delayed(const Duration(milliseconds: 750), () {
            if (!mounted || _viewMode != _ReaderViewMode.ayah) return;
            _scrollToAyah(targetAyah, maxAttempts: 8, alignment: 0.0);
          });
        }

        _didInitialReopenRestore = true;
        return;
      }

      // Otherwise prefer saved scroll offset for the same surah, then fall
      // back to ayah-based restore.
      final bookmarks = context.read<BookmarkProvider>();
      if (bookmarks.lastReadSurah == _selectedSurah) {
        _scrollToAyah(bookmarks.lastReadAyah, maxAttempts: 10, alignment: 0.0);
      } else {
        _scrollToLastReadAyah();
      }
    }
  }

  void _restoreMushafPageForLastRead() {
    final bookmarks = context.read<BookmarkProvider>();
    final targetSurah = bookmarks.lastReadSurah;
    final targetAyah = targetSurah == _selectedSurah
        ? bookmarks.lastReadAyah
        : (_ayahs.isNotEmpty ? _ayahs.first.ayahNumber : 1);
    final targetPage = _pageNumberForAyah(targetAyah);
    final pageIndex = (targetPage - 1).clamp(0, 603);
    setState(() {
      _currentMushafPageIndex = pageIndex;
      _ayahModeAnchorAyah = targetAyah;
      _mushafAnchorSurah = targetSurah;
      _mushafCurrentAnchorAyah = targetAyah;
      _mushafCurrentAnchorSurah = targetSurah;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mushafPageController.hasClients) return;
      _mushafPageController.jumpToPage(pageIndex);
      unawaited(_updateMushafAnchorForPage(targetPage));
    });
  }

  void _restoreScrollOffset(
    double offset, {
    int attempt = 0,
    double? lastMaxExtent,
    int stablePasses = 0,
  }) {
    if (!mounted || _viewMode != _ReaderViewMode.ayah) return;

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollOffset(
          offset,
          attempt: attempt + 1,
          lastMaxExtent: lastMaxExtent,
          stablePasses: stablePasses,
        );
      });
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    final extentStable =
        lastMaxExtent != null && (maxExtent - lastMaxExtent).abs() < 1.0;
    final nextStablePasses = extentStable ? stablePasses + 1 : 0;
    final extentReady = maxExtent >= offset || nextStablePasses >= 2;

    if (!extentReady && attempt < 18) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 60), () {
          _restoreScrollOffset(
            offset,
            attempt: attempt + 1,
            lastMaxExtent: maxExtent,
            stablePasses: nextStablePasses,
          );
        });
      });
      return;
    }

    final validOffset = offset.clamp(0.0, maxExtent);
    _isProgrammaticScroll = true;

    print(
        '🔄 Restoring scroll to offset=$validOffset (target=$offset, max=$maxExtent)');
    _scrollController.jumpTo(validOffset);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _isProgrammaticScroll = false;
      }
    });
  }

  // ─── Audio Controls ───────────────────────────────────────────────────────

  /// Double-tap on a single ayah — play just that one.
  void _playSingleAyah(Ayah ayah) {
    print('🔢 DOUBLE TAP: ayah ${ayah.ayahNumber}');
    context.read<BookmarkProvider>().saveLastRead(
        ayah.surahNumber, ayah.ayahNumber,
        caller: '[ayah-mode/double-tap]');

    if (_playingAyahNumber == ayah.ayahNumber) {
      if (_audio.isPlaying) {
        _audio.pause();
      } else {
        _audio.resume();
      }
      setState(() {
        _isPlayingAll = false;
      });
    } else {
      setState(() {
        _isPlayingAll = false;
        _playingAyahNumber = ayah.ayahNumber;
        _activeWordIndex = 0;
      });
      print('🎵 CALLING _playAyah FOR ${ayah.ayahNumber}');
      _playAyah(ayah);
    }
  }

  /// Play all ayahs sequentially from the first (or resume from current).
  Future<void> _togglePlayAll() async {
    if (_isPlayingAll) {
      _audio.stop();
      setState(() {
        _isPlayingAll = false;
        _playingAyahNumber = null;
        _activeWordIndex = -1;
      });
    } else if (_ayahs.isNotEmpty) {
      // If this surah is not fully cached, offer download as part of play flow.
      if (_downloadedAyahs < _ayahs.length) {
        final choice = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Play All options',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Offline audio: $_downloadedAyahs/${_ayahs.length} ayahs downloaded',
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: const Text('Download surah then play'),
                    onTap: () => Navigator.pop(context, 'download'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('Play now (stream missing ayahs)'),
                    onTap: () => Navigator.pop(context, 'stream'),
                  ),
                ],
              ),
            ),
          ),
        );

        if (choice == 'download') {
          final ok = await _downloadCurrentSurahAudio();
          if (!ok) return;
        } else if (choice == null) {
          return;
        }
      }

      final startIndex = 0;
      setState(() {
        _isPlayingAll = true;
        _playingAyahNumber = _ayahs[startIndex].ayahNumber;
        _activeWordIndex = 0;
      });
      _playAllFromIndex(startIndex);
    }
  }

  Future<void> _playAllFromIndex(int startIndex) async {
    for (int i = startIndex; i < _ayahs.length; i++) {
      if (!mounted || !_isPlayingAll) break;
      final ayah = _ayahs[i];

      setState(() {
        _playingAyahNumber = ayah.ayahNumber;
        _activeWordIndex = 0;
      });
      context.read<BookmarkProvider>().saveLastRead(
          ayah.surahNumber, ayah.ayahNumber,
          caller: '[ayah-mode/play-all]');

      final started = await _playAyah(ayah, updatePlayingState: false);
      if (!started) {
        if (!_isPlayingAll) break;
        continue;
      }

      final completed = await _waitForCurrentAyahCompletion();
      if (!completed) break;

      if (!_isPlayingAll) break;
    }

    if (mounted && _isPlayingAll) {
      setState(() {
        _isPlayingAll = false;
        _playingAyahNumber = null;
        _activeWordIndex = -1;
      });
    }
  }

  Future<bool> _playAyah(Ayah ayah, {bool updatePlayingState = true}) async {
    final token = ++_playRequestToken;
    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    final verseKey = '${ayah.surahNumber}:${ayah.ayahNumber}';
    final url = _resolveAyahAudioUrl(ayah);

    print(
        '🎵 PLAY AYAH: verseKey=$verseKey, mapHas=${_audioUrls.containsKey(verseKey)}, url=$url');

    if (url.isEmpty) {
      print('❌ ERROR: EMPTY URL FOR $verseKey');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio not available for this ayah'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    final preview = url.length <= 50 ? url : '${url.substring(0, 50)}...';
    print('📂 PLAYING URL: $preview');
    var usedCachedAudio = false;
    try {
      final localPath = await _audioCache.getCachedAyahPath(
        reciterId: reciterId,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
      );

      if (localPath != null && File(localPath).existsSync()) {
        usedCachedAudio = true;
        await _audio.playFile(localPath);
        print('✅ playFile succeeded from cache');
      } else {
        await _audio.playUrl(url);
        print('✅ playUrl succeeded');
      }

      // Ignore stale async completions when a newer play request exists.
      if (token != _playRequestToken || !mounted) return false;

      if (updatePlayingState) {
        setState(() {
          _playingAyahNumber = ayah.ayahNumber;
          _activeWordIndex = 0;
        });
      }

      if (!_audio.isPlaying && mounted) {
        setState(() {
          if (!_isPlayingAll) {
            _playingAyahNumber = null;
            _activeWordIndex = -1;
          }
        });
      }
    } catch (e) {
      print('❌ Exception in playUrl: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              usedCachedAudio
                  ? 'Error playing cached audio: $e'
                  : 'Audio for this ayah is not downloaded for offline use.',
            ),
            action: usedCachedAudio
                ? null
                : SnackBarAction(
                    label: 'Download surah',
                    onPressed: () {
                      unawaited(_downloadCurrentSurahAudio());
                    },
                  ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    // Update last read position
    try {
      context.read<BookmarkProvider>().saveLastRead(
          ayah.surahNumber, ayah.ayahNumber,
          caller: '[ayah-mode/play-single]');
    } catch (e) {
      print('❌ Error saving last read: $e');
    }

    // Scroll to currently playing ayah
    final key = _ayahKeys[ayah.ayahNumber];
    if (key?.currentContext != null) {
      try {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      } catch (e) {
        print('❌ Error scrolling: $e');
      }
    }

    return true;
  }

  String _resolveAyahAudioUrl(Ayah ayah) {
    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    final verseKey = '${ayah.surahNumber}:${ayah.ayahNumber}';
    final rawUrl = _audioUrls[verseKey] ??
        ayah.audioUrl ??
        _api.audioUrl(
          reciterId: reciterId,
          surahNumber: ayah.surahNumber,
          ayahNumber: ayah.ayahNumber,
        );

    if (rawUrl.isEmpty) return '';
    return rawUrl.startsWith('http')
        ? rawUrl
        : 'https://verses.quran.com/$rawUrl';
  }

  Future<bool> _waitForCurrentAyahCompletion() async {
    if (!_isPlayingAll) return false;

    final completer = Completer<bool>();
    late StreamSubscription<PlayerState> sub;
    late final Timer stopPoll;

    sub = _audio.playerStateStream.listen((state) {
      if (!completer.isCompleted &&
          _isPlayingAll &&
          state.processingState == ProcessingState.completed) {
        completer.complete(true);
      }

      if (!completer.isCompleted &&
          state.processingState == ProcessingState.idle) {
        completer.complete(false);
      }
    });

    // If play-all gets turned off while paused, complete immediately.
    stopPoll = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!completer.isCompleted && !_isPlayingAll) {
        completer.complete(false);
      }
    });

    final result = await completer.future;
    await sub.cancel();
    stopPoll.cancel();
    return result;
  }

  Future<void> _refreshOfflineStatus() async {
    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    final count = await _audioCache.getDownloadedCountForSurah(
      reciterId: reciterId,
      surahNumber: _selectedSurah,
    );
    if (!mounted) return;
    setState(() {
      _downloadedAyahs = count;
      _totalAyahs = _ayahs.length;
    });
  }

  Future<bool> _downloadCurrentSurahAudio() async {
    if (_ayahs.isEmpty || _isDownloadingSurahAudio) return false;

    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    final progress = ValueNotifier<Map<String, int>>({'done': 0, 'total': 1});

    setState(() {
      _isDownloadingSurahAudio = true;
    });

    if (mounted) {
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Downloading recitation'),
          content: ValueListenableBuilder<Map<String, int>>(
            valueListenable: progress,
            builder: (_, value, __) {
              final done = value['done'] ?? 0;
              final total = (value['total'] ?? 1).clamp(1, 99999);
              final ratio = (done / total).clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Surah $_selectedSurah · Reciter $reciterId',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6E6E6E)),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 8),
                  Text('Downloaded $done of $total ayahs'),
                ],
              );
            },
          ),
        ),
      ));
    }

    try {
      var audioMap = _audioUrls;
      if (audioMap.isEmpty) {
        audioMap = await _api.fetchAudioFiles(
          reciterId: reciterId,
          surahNumber: _selectedSurah,
        );
      }

      if (audioMap.isEmpty) {
        throw Exception('No audio URLs available for this surah/reciter.');
      }

      await _audioCache.downloadSurah(
        reciterId: reciterId,
        surahNumber: _selectedSurah,
        audioUrls: audioMap,
        onProgress: (done, total) {
          progress.value = {'done': done, 'total': total};
        },
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await _refreshOfflineStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Surah $_selectedSurah recitation downloaded.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    } finally {
      progress.dispose();
      if (mounted) {
        setState(() {
          _isDownloadingSurahAudio = false;
        });
      }
    }
  }

  Future<List<String>> _fetchCurrentSurahVerseKeysForTafseer() async {
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final keys = <String>[];
    var page = 1;
    while (true) {
      final verses = await _api.fetchVerses(
        surahNumber: _selectedSurah,
        langCode: langCode,
        page: page,
      );
      if (verses.isEmpty) break;

      for (final v in verses) {
        final key = v['verse_key'] as String?;
        if (key != null && key.isNotEmpty) keys.add(key);
      }

      if (verses.length < 50) break;
      page++;
    }

    final unique = keys.toSet().toList(growable: false)
      ..sort((a, b) {
        final aa = int.tryParse(a.split(':').last) ?? 0;
        final bb = int.tryParse(b.split(':').last) ?? 0;
        return aa.compareTo(bb);
      });
    return unique;
  }

  Future<bool> _downloadCurrentSurahTafseer() async {
    if (_ayahs.isEmpty || _isDownloadingSurahTafseer) return false;

    final tafsirId = context.read<TafseerProvider>().selectedTafsirId;
    final progress = ValueNotifier<Map<String, int>>({'done': 0, 'total': 1});

    setState(() {
      _isDownloadingSurahTafseer = true;
    });

    if (mounted) {
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Downloading tafseer'),
          content: ValueListenableBuilder<Map<String, int>>(
            valueListenable: progress,
            builder: (_, value, __) {
              final done = value['done'] ?? 0;
              final total = (value['total'] ?? 1).clamp(1, 99999);
              final ratio = (done / total).clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Surah $_selectedSurah · Tafseer ID $tafsirId',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6E6E6E)),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 8),
                  Text('Downloaded $done of $total ayahs'),
                ],
              );
            },
          ),
        ),
      ));
    }

    try {
      final keys = await _fetchCurrentSurahVerseKeysForTafseer();
      if (keys.isEmpty) {
        throw Exception('No verses returned for this surah.');
      }

      final cached = await _quranOfflineSync.getCachedTafsirMap(
        tafsirId: tafsirId,
        surahNumber: _selectedSurah,
      );
      final map = Map<String, String>.from(cached);

      final total = keys.length;
      var done = 0;
      progress.value = {'done': done, 'total': total};

      for (final verseKey in keys) {
        final existing = map[verseKey];
        if (existing != null && existing.trim().isNotEmpty) {
          done++;
          progress.value = {'done': done, 'total': total};
          continue;
        }

        final text = await _api.fetchTafsirForAyah(
          tafsirId: tafsirId,
          verseKey: verseKey,
        );
        map[verseKey] = text;
        done++;
        progress.value = {'done': done, 'total': total};
      }

      await _quranOfflineSync.saveTafsirMap(
        tafsirId: tafsirId,
        surahNumber: _selectedSurah,
        tafsirMap: map,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Surah $_selectedSurah tafseer downloaded.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tafseer download failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    } finally {
      progress.dispose();
      if (mounted) {
        setState(() {
          _isDownloadingSurahTafseer = false;
        });
      }
    }
  }

  void _stopAudio() {
    _audio.stop();
    setState(() {
      _isPlayingAll = false;
      _playingAyahNumber = null;
      _activeWordIndex = -1;
    });
  }

  // ─── Tafseer ──────────────────────────────────────────────────────────────

  void _showTafseer(Ayah ayah) {
    final tafsirId = context.read<TafseerProvider>().selectedTafsirId;
    final verseKey = '${ayah.surahNumber}:${ayah.ayahNumber}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TafseerSheet(verseKey: verseKey, tafsirId: tafsirId),
    );
  }

  // ─── Bookmarks ────────────────────────────────────────────────────────────

  void _toggleBookmark(Ayah ayah) {
    final bm = context.read<BookmarkProvider>();
    if (bm.isBookmarked(ayah.surahNumber, ayah.ayahNumber)) {
      bm.removeBookmark(ayah.surahNumber, ayah.ayahNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bookmark removed'),
              duration: Duration(seconds: 1)),
        );
      }
    } else {
      // Find surah name for label
      String label = '${ayah.surahNumber}:${ayah.ayahNumber}';
      for (final s in _allSurahs) {
        if (s['id'] == ayah.surahNumber) {
          label =
              '${s['name_arabic'] ?? s['name_simple']} — Ayah ${ayah.ayahNumber}';
          break;
        }
      }
      final scrollOffset =
          _scrollController.hasClients ? _scrollController.offset : 0.0;
      bm.addBookmark(ayah.surahNumber, ayah.ayahNumber,
          label: label, scrollOffset: scrollOffset);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bookmark added'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _togglePageBookmark() {
    final bm = context.read<BookmarkProvider>();
    final pageNumber = _currentMushafPageIndex + 1;
    if (bm.isPageBookmarked(pageNumber)) {
      bm.removePageBookmark(pageNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Page bookmark removed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final anchorSurah = _currentMushafAnchorSurah();
    final anchorAyah = _currentMushafAnchorAyah();
    final label = '${_surahArabicName(anchorSurah)} — Page $pageNumber';
    bm.addPageBookmark(
      pageNumber,
      surah: anchorSurah,
      ayah: anchorAyah,
      label: label,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Page bookmark added'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _openPageBookmark(Bookmark bookmark) async {
    final targetPage = (bookmark.pageNumber ?? 1).clamp(1, 604);
    final targetIndex = targetPage - 1;

    if (_viewMode != _ReaderViewMode.page) {
      setState(() {
        _viewMode = _ReaderViewMode.page;
      });
      _persistReaderViewMode(_ReaderViewMode.page);
    }

    await _updateMushafAnchorForPage(targetPage);
    if (!mounted) return;

    setState(() {
      _currentMushafPageIndex = targetIndex;
      _selectedSurah = bookmark.surah;
      _mushafCurrentAnchorSurah = bookmark.surah;
      _mushafCurrentAnchorAyah = bookmark.ayah;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mushafPageController.hasClients) return;
      _mushafPageController.jumpToPage(targetIndex);
    });

    _showMushafScrubberOverlay();
    await context.read<BookmarkProvider>().saveLastRead(
          bookmark.surah,
          bookmark.ayah,
          caller: '[page-bookmark/open]',
        );
  }

  void _showBookmarksList() {
    final bm = context.read<BookmarkProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BookmarksSheet(
        bookmarks: bm.groupedByTypeThenNewest(),
        onTap: (bookmark) {
          Navigator.pop(context);
          if (bookmark.isPage) {
            unawaited(_openPageBookmark(bookmark));
            return;
          }

          if (_selectedSurah == bookmark.surah) {
            // Same surah: scroll by ayah number (pixel offsets can be stale
            // if font-size / line-height changed since the bookmark was saved).
            context.read<BookmarkProvider>().saveLastRead(
                bookmark.surah, bookmark.ayah,
                caller: '[ayah-mode/bookmark-tap]');
            _scrollToAyah(bookmark.ayah);
            return;
          }

          // Different surah: load it then scroll to the bookmarked ayah.
          setState(() {
            _selectedSurah = bookmark.surah;
            _pendingScrollAyah = bookmark.ayah;
          });
          _loadSurah();
        },
        onDelete: (bookmark) {
          bm.removeBookmarkEntry(bookmark);
          // Rebuild the sheet content
          Navigator.pop(context);
          _showBookmarksList();
        },
      ),
    );
  }

  void _onWordTapped(TajweedRule rule, String word, Ayah ayah,
      {String? wordAudioUrl}) {
    showModalBottomSheet<TajweedRule>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => WordDetailSheet(
        rule: rule,
        word: word,
        ayah: ayah,
        wordAudioUrl: wordAudioUrl,
        ayahAudioUrl: _resolveAyahAudioUrl(ayah),
      ),
    ).then((selectedRule) {
      if (!mounted || selectedRule == null) return;
      final definition = RulesRepository.findByRule(selectedRule);
      if (definition == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RuleDetailScreen(definition: definition),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final selectedReciterId =
        context.watch<RecitationProvider>().selectedReciterId;

    if (selectedReciterId != _lastObservedReciterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyReciterChange(selectedReciterId);
      });
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        actionsPadding: const EdgeInsetsDirectional.only(start: 2, end: 8),
        title: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _SurahSelector(
              surahs: _allSurahs,
              selected: _selectedSurah,
              onBeforeOpen: () => _hideMushafScrubberOverlay(),
              onChanged: (v) {
                _selectedSurah = v;
                _stopAudio();
                _loadSurah();
              },
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == _ReaderViewMode.page
                  ? Icons.view_agenda_outlined
                  : Icons.menu_book_outlined,
              size: 22,
            ),
            tooltip: _viewMode == _ReaderViewMode.page
                ? 'Switch to Ayah view'
                : 'Switch to Page view',
            onPressed: _toggleReaderViewMode,
          ),
          // Bookmarks
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded, size: 22),
            tooltip: 'Bookmarks',
            onPressed: _showBookmarksList,
          ),
          // Play all toggle
          IconButton(
            icon: Icon(
              _isPlayingAll
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              size: 22,
            ),
            color: _isPlayingAll ? Colors.red : const Color(0xFF1D9E75),
            tooltip: _isPlayingAll ? 'Stop' : 'Play All',
            onPressed: _ayahs.isNotEmpty ? _togglePlayAll : null,
          ),
          IconButton(
            icon:
                Icon(_tajweedEnabled ? Icons.palette : Icons.palette_outlined),
            color: _tajweedEnabled ? const Color(0xFF1D9E75) : null,
            tooltip: 'Tajweed colors',
            onPressed: () => setState(() => _tajweedEnabled = !_tajweedEnabled),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_viewMode == _ReaderViewMode.ayah) ...[
            TajweedLegend(
              rules: TajweedRule.values,
              langCode: langCode,
            ),
            const Divider(height: 0.5),
            // DEBUG: Show audio map status in ayah mode only
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.all(8),
              child: Text(
                '📻 Audio URLs: ${_audioUrls.length} | Offline: $_downloadedAyahs/$_totalAyahs | Last read: $_selectedSurah:${context.watch<BookmarkProvider>().lastReadAyah}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF666)),
              ),
            ),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _ayahs.isEmpty
                    ? _EmptyState(onRetry: _loadSurah)
                    : (_viewMode == _ReaderViewMode.page
                        ? _buildMushafPageView()
                        : _buildAyahList(langCode, pageMode: false)),
          ),
          // Audio player bar when playing
          if (_playingAyahNumber != null)
            AudioPlayerBar(
              audioService: _audio,
              label:
                  '$_selectedSurah:$_playingAyahNumber${_isPlayingAll ? ' (All)' : ''}',
              onClose: _stopAudio,
            ),
        ],
      ),
    );
  }

  Widget _buildAyahList(String langCode, {required bool pageMode}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _cancelProgrammaticAyahScroll(),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(vertical: pageMode ? 12 : 8),
        itemCount: _ayahs.length,
        itemBuilder: (context, i) {
        final ayah = _ayahs[i];
        final juzNumber = _juzBoundaries[ayah.ayahNumber];
        final isPlaying = _playingAyahNumber == ayah.ayahNumber;
        final isBookmarked = context
            .watch<BookmarkProvider>()
            .isBookmarked(ayah.surahNumber, ayah.ayahNumber);

        return Column(
          key: _ayahKeys[ayah.ayahNumber],
          children: [
            if (juzNumber != null) _JuzMarker(juzNumber: juzNumber),
            if (!pageMode && i > 0 && juzNumber == null)
              const Divider(height: 0.5, indent: 16),
            if (pageMode)
              _PageAyahLine(
                ayah: ayah,
                tajweedEnabled: _tajweedEnabled,
                isPlaying: isPlaying,
                activeWordIndex: isPlaying ? _activeWordIndex : -1,
                mushafFontSize: 28,
                onWordTapped: _onWordTapped,
                onDoubleTap: () => _playSingleAyah(ayah),
                onBookmarkTap: () => _toggleBookmark(ayah),
              )
            else
              _AyahTile(
                ayah: ayah,
                tajweedEnabled: _tajweedEnabled,
                showTranslation: _showTranslation,
                langCode: langCode,
                isPlaying: isPlaying,
                activeWordIndex: isPlaying ? _activeWordIndex : -1,
                isBookmarked: isBookmarked,
                onWordTapped: _onWordTapped,
                onDoubleTap: () => _playSingleAyah(ayah),
                onTafseerTap: () => _showTafseer(ayah),
                onBookmarkTap: () => _toggleBookmark(ayah),
              ),
          ],
        );
        },
      ),
    );
  }

  Future<void> _toggleReaderViewMode() async {
    if (_viewMode == _ReaderViewMode.ayah) {
      final ayahOffset = _scrollController.hasClients
          ? _scrollController.offset
          : context.read<BookmarkProvider>().lastScrollOffset;
      final anchorAyah = _findTopVisibleAyahNumber() ??
          context.read<BookmarkProvider>().lastReadAyah;
      debugPrint(
          '🔄 VIEW TOGGLE: ayah → page | surah=$_selectedSurah, anchorAyah=$anchorAyah, offset=$ayahOffset');
      _ayahModeAnchorAyah = anchorAyah;
      _mushafAnchorSurah = _selectedSurah;
      _mushafCurrentAnchorAyah = anchorAyah;
      _mushafCurrentAnchorSurah = _selectedSurah;
      _mushafEntryAnchorAyah = anchorAyah;
      _mushafEntrySurah = _selectedSurah;
      _mushafEntryPageNumber = _currentMushafPageIndex + 1;
      _ayahModeReturnOffset = ayahOffset;
      context.read<BookmarkProvider>().saveLastRead(
            _selectedSurah,
            anchorAyah,
            scrollOffset: ayahOffset,
            caller: '[toggle/ayah→page]',
          );
      final targetPageIndex = _pageNumberForAyah(anchorAyah) - 1;
      await _updateMushafAnchorForPage(targetPageIndex + 1);

      setState(() {
        _viewMode = _ReaderViewMode.page;
        _currentMushafPageIndex = targetPageIndex;
      });
      _mushafEntryPageNumber = targetPageIndex + 1;
      debugPrint('🔄 VIEW MODE: now=page | targetPage=${targetPageIndex + 1}');
      _showMushafScrubberOverlay();
      _persistReaderViewMode(_ReaderViewMode.page);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mushafPageController.hasClients) return;
        _mushafPageController.jumpToPage(targetPageIndex);
        unawaited(_updateMushafAnchorForPage(targetPageIndex + 1));
      });
      return;
    }

    await _goToAnchoredAyah();
  }

  Future<void> _goToAnchoredAyah() async {
    debugPrint(
        '🔄 VIEW TOGGLE: page → ayah | page=${_currentMushafPageIndex + 1}');
    final currentPageNumber = _currentMushafPageIndex + 1;
    if (!_mushafPageAnchorCache.containsKey(currentPageNumber)) {
      await _updateMushafAnchorForPage(currentPageNumber);
    }

    _mushafScrubberHideTimer?.cancel();
    _mushafScrubberPreviewPage = null;
    _showMushafScrubber = false;
    _isMushafScrubberDragging = false;

    // If the user didn't navigate to a different page/surah while in mushaf
    // mode, restore the exact ayah they were reading.
    final entryPageNumber = _mushafEntryPageNumber;
    final didNavigateInPageMode = entryPageNumber == null ||
        entryPageNumber != currentPageNumber ||
        (_mushafEntrySurah != null &&
            _mushafEntrySurah != _currentMushafAnchorSurah());

    // Page mode should return to the anchor of the currently visible page.
    // This keeps page->ayah transitions aligned with what the user sees in
    // mushaf view (page-first ayah), instead of a previous ayah-mode anchor.
    final anchorAyah = _currentMushafAnchorAyah();
    final anchorSurah = _currentMushafAnchorSurah();
    final targetAyah = anchorAyah;
    final hasLoadedAyahsForAnchorSurah =
        _ayahs.isNotEmpty && _ayahs.first.surahNumber == anchorSurah;
    final shouldReloadSurah =
        anchorSurah != _selectedSurah || !hasLoadedAyahsForAnchorSurah;

    _scrollSaveTimer?.cancel();
    _setRestoreGuard(targetAyah, durationMs: 4200);

    debugPrint('🔄 PAGE→AYAH anchor: didNavigate=$didNavigateInPageMode, '
        'entryPage=$entryPageNumber, currentPage=$currentPageNumber, '
        'targetAyah=$targetAyah (ayahModeAnchor=$_ayahModeAnchorAyah), '
        'loadedSurah=${_ayahs.isEmpty ? '-' : _ayahs.first.surahNumber}, '
        'reload=$shouldReloadSurah');

    // Return to the selected anchor for the current page context.
    context.read<BookmarkProvider>().saveLastRead(
          anchorSurah,
          targetAyah,
          scrollOffset: 0.0,
          caller: '[toggle/page→ayah]',
        );

    setState(() {
      _viewMode = _ReaderViewMode.ayah;
      if (shouldReloadSurah) {
        _selectedSurah = anchorSurah;
      }
    });
    debugPrint(
        '🔄 VIEW MODE: now=ayah | surah=$anchorSurah, targetAyah=$targetAyah');
    _persistReaderViewMode(_ReaderViewMode.ayah);

    if (shouldReloadSurah) {
      _pendingScrollAyah = targetAyah;
      _pendingScrollOffset = 0.0;
      _loadSurah();
      return;
    }

    // Use the exact pixel offset saved when we entered page mode to pre-seed
    // the scroll position before ensureVisible runs. This avoids the linear
    // index approximation in _scrollToAyah overshooting on variable-height
    // surahs (e.g. Al-Baqarah).
    final canReuseAyahModeOffset =
        !didNavigateInPageMode && _ayahModeAnchorAyah == targetAyah;
    final returnOffset = canReuseAyahModeOffset ? _ayahModeReturnOffset : null;
    _ayahModeReturnOffset = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (returnOffset != null &&
          returnOffset > 0 &&
          _scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        if (max > 0) {
          final clamped = returnOffset.clamp(0.0, max);
          debugPrint(
              '🔄 PAGE→AYAH seed jump: offset=$clamped (saved=$returnOffset)');
          _scrollController.jumpTo(clamped);
        }
      } else if (didNavigateInPageMode) {
        debugPrint(
            '🔄 PAGE→AYAH saved-offset seed skipped: user navigated pages in mushaf mode');
      }
      _scrollToAyah(
        targetAyah,
        maxAttempts: 30,
        alignment: 0.0,
        allowSeedJump: true,
      );
    });

    _mushafEntryAnchorAyah = targetAyah;
    _mushafEntrySurah = anchorSurah;
    _mushafEntryPageNumber = currentPageNumber;
  }

  int? _findTopVisibleAyahNumber() {
    if (!mounted || _ayahs.isEmpty) return null;

    int? bestAyah;
    double bestDistance = double.infinity;

    for (final ayah in _ayahs) {
      final key = _ayahKeys[ayah.ayahNumber];
      if (key?.currentContext == null) continue;
      final renderObject = key!.currentContext!.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;

      final dy = renderObject.localToGlobal(Offset.zero).dy;
      final distance = dy.abs();

      if (dy >= -20 && distance < bestDistance) {
        bestDistance = distance;
        bestAyah = ayah.ayahNumber;
      }
    }

    return bestAyah;
  }

  String _surahArabicName(int surahNumber) {
    for (final s in _allSurahs) {
      if (s['id'] == surahNumber) {
        return (s['name_arabic'] as String?) ?? 'سورة';
      }
    }
    return 'سورة';
  }

  int _currentMushafAnchorAyah() {
    final pageNumber = _currentMushafPageIndex + 1;
    final localFirstAyah = _localFirstAyahForPage(pageNumber);
    final localAyahNumber = localFirstAyah?.ayahNumber;
    return _mushafPageAnchorCache[pageNumber]?.ayah ??
        _mushafCurrentAnchorAyah ??
        localAyahNumber ??
        _mushafEntryAnchorAyah ??
        _ayahModeAnchorAyah ??
        1;
  }

  int _currentMushafAnchorSurah() {
    final pageNumber = _currentMushafPageIndex + 1;
    final localFirstAyah = _localFirstAyahForPage(pageNumber);
    final localSurah = localFirstAyah?.surahNumber;
    return _mushafPageAnchorCache[pageNumber]?.surah ??
        _mushafCurrentAnchorSurah ??
        localSurah ??
        _mushafEntrySurah ??
        _mushafAnchorSurah ??
        _selectedSurah;
  }

  Ayah? _localFirstAyahForPage(int pageNumber) {
    if (_ayahs.isEmpty) return null;
    for (final ayah in _ayahs) {
      if (ayah.pageNumber == pageNumber) return ayah;
    }
    return null;
  }

  int _pageNumberForAyah(int ayahNumber) {
    final fallbackPage = (_currentMushafPageIndex + 1).clamp(1, 604);
    if (_ayahs.isEmpty) return fallbackPage;

    // Guard against transient stale ayah lists during cross-surah switches.
    // If the currently rendered ayahs belong to a different surah than the
    // selected one, use the current mushaf page instead of a wrong lookup.
    if (_ayahs.first.surahNumber != _selectedSurah) {
      debugPrint(
          '⚠️ _pageNumberForAyah fallback: stale ayahs for surah=${_ayahs.first.surahNumber}, selected=$_selectedSurah, ayah=$ayahNumber, page=$fallbackPage');
      return fallbackPage;
    }

    final idx = _ayahs.indexWhere(
      (a) => a.surahNumber == _selectedSurah && a.ayahNumber == ayahNumber,
    );
    if (idx < 0) return fallbackPage;
    return _ayahs[idx].pageNumber;
  }

  String _getMushafPagePath(int pageNumber) {
    final root = _mushafPagesDirPath;
    if (root == null) return '';
    final plain = '$root/images/$pageNumber.png';
    if (File(plain).existsSync()) return plain;

    final padded = pageNumber.toString().padLeft(3, '0');
    final paddedOnly = '$root/images/$padded.png';
    if (File(paddedOnly).existsSync()) return paddedOnly;

    final pagePrefixed = '$root/images/page$padded.png';
    if (File(pagePrefixed).existsSync()) return pagePrefixed;

    return plain;
  }

  Future<void> _updateMushafAnchorForPage(int pageNumber) async {
    if (!mounted) return;
    final cached = _mushafPageAnchorCache[pageNumber];
    // Always refetch multi-surah pages to ensure correct surah selection
    if (cached != null && pageNumber != 1 && pageNumber != 2) {
      setState(() {
        if (_currentMushafPageIndex + 1 == pageNumber) {
          _mushafCurrentAnchorSurah = cached.surah;
          _mushafCurrentAnchorAyah = cached.ayah;
        }
        if (_viewMode == _ReaderViewMode.page &&
            _currentMushafPageIndex + 1 == pageNumber) {
          // Keep selector/header consistent when cached page anchors are used.
          _selectedSurah = cached.surah;
        }
      });
      return;
    }

    try {
      final langCode = context.read<LocaleProvider>().locale.languageCode;
      final verses = await _api.fetchVersesByPage(
        pageNumber: pageNumber,
        langCode: langCode,
      );

      if (verses.isEmpty || !mounted) return;

      // Use the first ayah on the page as the return anchor when switching
      // back to ayah mode so the text view starts at the top of that page.
      final firstVerseKey = verses.first['verse_key'] as String? ?? '';
      final parts = firstVerseKey.split(':');
      if (parts.length != 2) return;

      final surah = int.tryParse(parts.first);
      final ayah = int.tryParse(parts.last);
      if (surah == null || ayah == null) return;

      final anchor = _MushafPageAnchor(
        pageNumber: pageNumber,
        surah: surah,
        ayah: ayah,
      );

      _mushafPageAnchorCache[pageNumber] = anchor;
      if (!mounted) return;
      setState(() {
        if (_currentMushafPageIndex + 1 == pageNumber) {
          _mushafCurrentAnchorSurah = surah;
          _mushafCurrentAnchorAyah = ayah;
        }
        if (_viewMode == _ReaderViewMode.page &&
            _currentMushafPageIndex + 1 == pageNumber) {
          // Keep the top selector in sync with the first ayah shown on page.
          _selectedSurah = surah;
        }
      });
    } catch (_) {
      // Ignore per-page metadata failure; image page remains readable.
    }
  }

  void _showMushafScrubberOverlay() {
    if (!mounted || _viewMode != _ReaderViewMode.page) return;
    setState(() {
      _showMushafScrubber = true;
    });
    _scheduleMushafScrubberAutoHide();
  }

  bool _hideMushafScrubberOverlay() {
    if (!mounted || _viewMode != _ReaderViewMode.page || !_showMushafScrubber) {
      return false;
    }
    _mushafScrubberHideTimer?.cancel();
    setState(() {
      _showMushafScrubber = false;
      _isMushafScrubberDragging = false;
      _mushafScrubberPreviewPage = null;
    });
    return true;
  }

  void _scheduleMushafScrubberAutoHide() {
    _mushafScrubberHideTimer?.cancel();
    if (!_showMushafScrubber || _isMushafScrubberDragging) return;
    _mushafScrubberHideTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || _isMushafScrubberDragging) return;
      setState(() {
        _showMushafScrubber = false;
      });
    });
  }

  void _handleMushafPageChanged(int index) {
    if (!mounted) return;
    final pageNumber = index + 1;
    final cached = _mushafPageAnchorCache[pageNumber];
    setState(() {
      _currentMushafPageIndex = index;
      _mushafCurrentAnchorSurah = cached?.surah;
      _mushafCurrentAnchorAyah = cached?.ayah;
      if (cached != null) {
        _selectedSurah = cached.surah;
      }
    });
    _showMushafScrubberOverlay();

    // Ensure last-read and selector use the anchor metadata for this page,
    // not stale data from the previous page while async metadata is pending.
    unawaited(() async {
      await _updateMushafAnchorForPage(pageNumber);
      if (!mounted || _currentMushafPageIndex != index) return;
      final anchorSurah = _currentMushafAnchorSurah();
      final anchorAyah = _currentMushafAnchorAyah();
      await context.read<BookmarkProvider>().saveLastRead(
          anchorSurah, anchorAyah,
          caller: '[page-mode/page-change]');
    }());
  }

  Widget _buildMushafScrubber() {
    final previewPage =
        _mushafScrubberPreviewPage ?? (_currentMushafPageIndex + 1);
    final previewSurah =
        _mushafPageAnchorCache[previewPage]?.surah ?? _selectedSurah;
    final previewSurahName = _surahArabicName(previewSurah);

    return IgnorePointer(
      ignoring: !_showMushafScrubber,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _showMushafScrubber ? 1 : 0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFBF6EA).withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD1BF98), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Page $previewPage',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5E4A23),
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          previewSurahName,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 20,
                            color: Color(0xFF6F5522),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      value: previewPage.toDouble(),
                      min: 1,
                      max: 604,
                      divisions: 603,
                      label: '$previewPage',
                      activeColor: const Color(0xFF8B6A2E),
                      inactiveColor: const Color(0xFFD8CCB1),
                      onChangeStart: (_) {
                        _mushafScrubberHideTimer?.cancel();
                        setState(() {
                          _isMushafScrubberDragging = true;
                        });
                      },
                      onChanged: (value) {
                        setState(() {
                          _mushafScrubberPreviewPage =
                              value.round().clamp(1, 604);
                          _showMushafScrubber = true;
                        });
                      },
                      onChangeEnd: (value) {
                        final page = value.round().clamp(1, 604);
                        setState(() {
                          _isMushafScrubberDragging = false;
                          _mushafScrubberPreviewPage = null;
                        });
                        _scheduleMushafScrubberAutoHide();

                        if (_mushafPageController.hasClients) {
                          _mushafPageController.jumpToPage(page - 1);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMushafPageView() {
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final hasPack = _mushafPagesDirPath != null;
    if (!hasPack) {
      if (_mushafPagesError != null) {
        return _MushafDownloadStateCard(
          title: 'Unable to load Mushaf pages',
          subtitle: '${_mushafPagesError.runtimeType}: $_mushafPagesError',
          actionLabel: 'Retry download',
          onAction: _initializeMushafPages,
          icon: Icons.cloud_off_outlined,
        );
      }

      final progress = _downloadTotal > 0
          ? (_downloadReceived / _downloadTotal).clamp(0.0, 1.0)
          : null;

      return _MushafDownloadStateCard(
        title: _isMushafDownloading
            ? 'Downloading Mushaf pages'
            : 'Preparing Mushaf pages',
        subtitle: _downloadTotal > 0
            ? '${(_downloadReceived / (1024 * 1024)).toStringAsFixed(1)} MB / ${(_downloadTotal / (1024 * 1024)).toStringAsFixed(1)} MB'
            : 'This happens once and pages are cached locally.',
        actionLabel: _isMushafDownloading ? null : 'Start download',
        onAction: _isMushafDownloading ? null : _initializeMushafPages,
        icon: Icons.cloud_download_outlined,
        progress: progress,
      );
    }

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _showMushafScrubberOverlay,
          onLongPress: _togglePageBookmark,
          child: PageView.builder(
            controller: _mushafPageController,
            itemCount: 604,
            onPageChanged: _handleMushafPageChanged,
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              final pageSurah =
                  _mushafPageAnchorCache[pageNumber]?.surah ?? _selectedSurah;
              final surahName = _surahArabicName(pageSurah);
              final isPageBookmarked =
                  bookmarkProvider.isPageBookmarked(pageNumber);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _QuranPageBackground(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _MushafHeaderChip(text: surahName),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '۞۞۞',
                                style: TextStyle(
                                  fontFamily: 'UthmanicHafs',
                                  fontSize: 18,
                                  color: Color(0xFF946E2A),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isPageBookmarked)
                                    const Padding(
                                      padding:
                                          EdgeInsetsDirectional.only(end: 6),
                                      child: Icon(
                                        Icons.bookmark,
                                        color: Color(0xFFB8860B),
                                        size: 18,
                                      ),
                                    ),
                                  Expanded(
                                    child: _MushafHeaderChip(
                                      text: 'الصفحة $pageNumber',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF9F4),
                            border: Border.all(
                                color: const Color(0xFF8E7C58), width: 1.2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                            child: Image.file(
                              File(_getMushafPagePath(pageNumber)),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                              alignment: Alignment.center,
                              isAntiAlias: false,
                              errorBuilder: (_, __, ___) =>
                                  _MissingLocalMushafPage(
                                pageNumber: pageNumber,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildMushafScrubber(),
      ],
    );
  }
}

class _MushafPageAnchor {
  final int pageNumber;
  final int surah;
  final int ayah;

  const _MushafPageAnchor({
    required this.pageNumber,
    required this.surah,
    required this.ayah,
  });
}

class _MissingLocalMushafPage extends StatelessWidget {
  final int pageNumber;

  const _MissingLocalMushafPage({
    required this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined,
              size: 28, color: Color(0xFF7D6E52)),
          const SizedBox(height: 8),
          const Text(
            'Downloaded page image not found',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5A4B2E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Expected file: $pageNumber.png',
            style: const TextStyle(fontSize: 11, color: Color(0xFF7E7158)),
          ),
        ],
      ),
    );
  }
}

class _MushafDownloadStateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
  final double? progress;

  const _MushafDownloadStateCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF9F4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF8E7C58), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: const Color(0xFF6F5A33)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4F4025),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6F5F40)),
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                color: const Color(0xFF1D9E75),
                backgroundColor: const Color(0xFFE1D8C6),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MushafHeaderChip extends StatelessWidget {
  final String text;
  const _MushafHeaderChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECE2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8A7958), width: 1.0),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: 20,
          color: Color(0xFF4D3E24),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SurahSelector extends StatelessWidget {
  final List<Map<String, dynamic>> surahs;
  final int selected;
  final bool Function()? onBeforeOpen;
  final void Function(int) onChanged;
  const _SurahSelector(
      {required this.surahs,
      required this.selected,
      this.onBeforeOpen,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Arabic name first, English second
    String arabicName = '';
    for (final s in surahs) {
      if (s['id'] == selected) {
        arabicName = s['name_arabic'] as String? ?? '';
        break;
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // Reserve room for 4 app bar icons + paddings so title stays balanced.
    final maxTitleWidth = (screenWidth - 260).clamp(96.0, 230.0);

    return GestureDetector(
      onTap: () {
        if (onBeforeOpen?.call() ?? false) return;
        _showSurahPicker(context);
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxTitleWidth),
              child: Text(
                arabicName.isNotEmpty ? arabicName : 'Surah $selected',
                maxLines: 1,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: arabicName.isNotEmpty ? 'UthmanicHafs' : null,
                      fontSize: arabicName.isNotEmpty ? 18 : 16,
                    ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSurahPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SurahPickerSheet(
        surahs: surahs,
        selected: selected,
        onChanged: (v) {
          onChanged(v);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _SurahPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> surahs;
  final int selected;
  final void Function(int) onChanged;
  const _SurahPickerSheet(
      {required this.surahs, required this.selected, required this.onChanged});

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  String _search = '';
  final _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients) return;
      final idx = widget.surahs
          .indexWhere((s) => (s['id'] as int? ?? 0) == widget.selected);
      if (idx < 0) return;

      // Keep the selected surah in view when opening instead of starting at top.
      final approxTileExtent = 64.0;
      final targetOffset = (idx * approxTileExtent - 3 * approxTileExtent)
          .clamp(0.0, _listController.position.maxScrollExtent);
      _listController.jumpTo(targetOffset);
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return widget.surahs;
    final q = _search.toLowerCase();
    return widget.surahs.where((s) {
      final name = (s['name_simple'] ?? '').toString().toLowerCase();
      final nameAr = (s['name_arabic'] ?? '').toString();
      final num = s['id'].toString();
      return name.contains(q) || nameAr.contains(q) || num == q;
    }).toList();
  }

  void _jumpToIndex(int startNumber) {
    // Find the index in the full list for that surah number
    final idx =
        widget.surahs.indexWhere((s) => (s['id'] as int? ?? 0) >= startNumber);
    if (idx >= 0) {
      _listController.animateTo(
        idx * 64.0, // approximate tile height
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surahs = _filtered;
    final showIndex =
        _search.isEmpty; // only show jump index when not searching

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Search surah by name or number...',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _search.isEmpty ? _listController : controller,
                    itemCount: surahs.length,
                    itemBuilder: (_, i) {
                      final s = surahs[i];
                      final id = s['id'] as int? ?? i + 1;
                      final isSelected = id == widget.selected;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1D9E75)
                                : const Color(0xFFF5F5F5),
                            shape: BoxShape.circle,
                          ),
                          child: Text('$id',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF3D3D3A),
                              )),
                        ),
                        // Arabic name is primary
                        title: Text(
                          s['name_arabic'] ?? '',
                          style: const TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          '${s['name_simple'] ?? 'Surah $id'} • ${s['verses_count'] ?? ''} verses',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFF1D9E75), size: 20)
                            : null,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          widget.onChanged(id);
                        },
                      );
                    },
                  ),
                ),
                // Quick jump index strip
                if (showIndex)
                  SizedBox(
                    width: 32,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        for (final n in [
                          1,
                          10,
                          20,
                          30,
                          40,
                          50,
                          60,
                          70,
                          80,
                          90,
                          100,
                          110
                        ])
                          GestureDetector(
                            onTap: () => _jumpToIndex(n),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                '$n',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1D9E75),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Juz Boundary Marker ─────────────────────────────────────────────────────

class _JuzMarker extends StatelessWidget {
  final int juzNumber;
  const _JuzMarker({required this.juzNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6C8),
        border: Border.symmetric(
          horizontal: BorderSide(
              color: const Color(0xFFD4A940).withValues(alpha: 0.5),
              width: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          'الجزء $juzNumber',
          style: const TextStyle(
            fontFamily: 'UthmanicHafs',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB8860B),
          ),
        ),
      ),
    );
  }
}

class _QuranPageBackground extends StatelessWidget {
  final Widget child;
  const _QuranPageBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF3E8D1),
                Color(0xFFEADCC0),
                Color(0xFFF3E8D1),
              ],
            ),
            border: Border.all(color: const Color(0xFF8F7A50), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _QuranPagePatternPainter(),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _QuranPagePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sideFill = Paint()
      ..color = const Color(0xFFDFC39A).withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, 18, size.height), sideFill);
    canvas.drawRect(
        Rect.fromLTWH(size.width - 18, 0, 18, size.height), sideFill);

    final motifPaint = Paint()
      ..color = const Color(0xFF8B6A2E).withValues(alpha: 0.55);
    for (double y = 16; y < size.height - 16; y += 20) {
      canvas.drawCircle(const Offset(9, 0) + Offset(0, y), 3.0, motifPaint);
      canvas.drawCircle(Offset(size.width - 9, y), 3.0, motifPaint);
    }

    final frame = Paint()
      ..color = const Color(0xFF7C6640).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18, 6, size.width - 36, size.height - 12),
        const Radius.circular(8),
      ),
      frame,
    );

    final inner = Paint()
      ..color = const Color(0xFF9A845A).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, 12, size.width - 48, size.height - 24),
        const Radius.circular(6),
      ),
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Ayah Tile (redesigned) ──────────────────────────────────────────────────

class _AyahTile extends StatelessWidget {
  final Ayah ayah;
  final bool tajweedEnabled;
  final bool showTranslation;
  final String langCode;
  final bool isPlaying;
  final int activeWordIndex;
  final bool isBookmarked;
  final void Function(TajweedRule, String, Ayah, {String? wordAudioUrl})
      onWordTapped;
  final VoidCallback onDoubleTap;
  final VoidCallback onTafseerTap;
  final VoidCallback onBookmarkTap;

  const _AyahTile({
    required this.ayah,
    required this.tajweedEnabled,
    required this.showTranslation,
    required this.langCode,
    required this.isPlaying,
    required this.activeWordIndex,
    required this.isBookmarked,
    required this.onWordTapped,
    required this.onDoubleTap,
    required this.onTafseerTap,
    required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onBookmarkTap,
      behavior: HitTestBehavior.opaque,
      // Increase double-tap detection window
      excludeFromSemantics: false,
      child: Container(
        color:
            isPlaying ? const Color(0xFF1D9E75).withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _AyahNumber(number: ayah.ayahNumber),
                const Spacer(),
                // Tafseer button
                IconButton(
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  color: const Color(0xFF888780),
                  tooltip: 'Tafseer',
                  onPressed: onTafseerTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                // Bookmark indicator
                if (isBookmarked)
                  const Icon(Icons.bookmark,
                      size: 18, color: Color(0xFFB8860B)),
              ],
            ),
            const SizedBox(height: 8),
            TajweedText(
              ayah: ayah,
              fontSize: 32,
              highlightEnabled: tajweedEnabled,
              highlightedWordIndex: activeWordIndex,
              suppressedRules: const {TajweedRule.izhar},
              onRuleTapped: (rule, word, wordAudioUrl) =>
                  onWordTapped(rule, word, ayah, wordAudioUrl: wordAudioUrl),
            ),
            if (showTranslation) ...[
              const SizedBox(height: 8),
              Text(
                ayah.translation(langCode),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PageAyahLine extends StatelessWidget {
  final Ayah ayah;
  final bool tajweedEnabled;
  final bool isPlaying;
  final int activeWordIndex;
  final double mushafFontSize;
  final void Function(TajweedRule, String, Ayah, {String? wordAudioUrl})
      onWordTapped;
  final VoidCallback onDoubleTap;
  final VoidCallback onBookmarkTap;

  const _PageAyahLine({
    required this.ayah,
    required this.tajweedEnabled,
    required this.isPlaying,
    required this.activeWordIndex,
    required this.mushafFontSize,
    required this.onWordTapped,
    required this.onDoubleTap,
    required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onBookmarkTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isPlaying
              ? const Color(0xFF1D9E75).withValues(alpha: 0.10)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
        child: TajweedText(
          ayah: ayah,
          fontSize: mushafFontSize,
          lineHeight: 1.9,
          compactFlow: true,
          highlightEnabled: tajweedEnabled,
          highlightedWordIndex: activeWordIndex,
          suppressedRules: const {TajweedRule.izhar},
          onRuleTapped: (rule, word, wordAudioUrl) =>
              onWordTapped(rule, word, ayah, wordAudioUrl: wordAudioUrl),
        ),
      ),
    );
  }
}

class _AyahNumber extends StatelessWidget {
  final int number;
  const _AyahNumber({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6C8),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD4A940), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFFB8860B)),
      ),
    );
  }
}

// ─── Bookmarks Sheet ─────────────────────────────────────────────────────────

class _BookmarksSheet extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final void Function(Bookmark) onTap;
  final void Function(Bookmark) onDelete;

  const _BookmarksSheet({
    required this.bookmarks,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bookmark_rounded,
                    color: Color(0xFFB8860B), size: 22),
                const SizedBox(width: 8),
                Text('Bookmarks',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 0.5),
          Expanded(
            child: bookmarks.isEmpty
                ? const Center(
                    child: Text(
                        'No bookmarks yet.\nLong-press an ayah or tap a Mushaf page to bookmark.',
                        textAlign: TextAlign.center))
                : ListView.separated(
                    controller: controller,
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0.5, indent: 16),
                    itemBuilder: (_, i) {
                      final bm = bookmarks[i];
                      final previousType = i > 0 ? bookmarks[i - 1].type : null;
                      final showHeader = i == 0 || previousType != bm.type;
                      final leadingText = bm.isPage
                          ? 'P${bm.pageNumber ?? '-'}'
                          : '${bm.surah}:${bm.ayah}';
                      final subtitleText = bm.isPage
                          ? 'Page ${bm.pageNumber ?? '-'} • Surah ${bm.surah}'
                          : 'Surah ${bm.surah} • Ayah ${bm.ayah}';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                bm.isPage ? 'Page bookmarks' : 'Ayah bookmarks',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7A6434),
                                ),
                              ),
                            ),
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5E6C8),
                                shape: BoxShape.circle,
                              ),
                              child: Text(leadingText,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFB8860B))),
                            ),
                            title: Text(bm.label ?? subtitleText),
                            subtitle: Text(
                              '${_formatDate(bm.timestamp)} • $subtitleText',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => onDelete(bm),
                            ),
                            onTap: () => onTap(bm),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: Color(0xFF888780)),
          const SizedBox(height: 12),
          Text('Could not load verses',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
