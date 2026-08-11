import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_links.dart';
import '../../core/l10n/app_localizations.dart';
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
import '../../core/services/quran_content_sync_service.dart';
import '../reader/widgets/audio_player_bar.dart';
import '../reader/widgets/single_page_scroll_physics.dart';
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

enum _AyahContentMode { arabicOnly, arabicWithTranslation }

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  static const String _readerViewModeKey = 'reader_view_mode';
  static const String _ayahContentModeKey = 'ayah_content_mode';
  static const String _mushafTextScaleKey = 'mushaf_text_scale';
  static const String _juzListCacheKey = 'reader_juz_list';

  final _api = QuranApiService();
  final _audio = AudioService();
  final _audioCache = AudioCacheService();
  final _quranOfflineSync = QuranOfflineSyncService();
  final _contentSync = QuranContentSyncService();
  late final ScrollController _scrollController;
  final PageController _mushafPageController = PageController();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;

  final Map<int, Future<List<Ayah>>> _mushafTextPageLoads = {};

  int _selectedSurah = 1;
  bool _tajweedEnabled = true;
  _AyahContentMode _ayahContentMode = _AyahContentMode.arabicWithTranslation;
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
  double _mushafTextScale = 1;
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
  Map<int, List<_JuzRange>> _juzRangesBySurah = {};

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
  String? _lastLoadedLanguageCode;
  bool _forceRefreshNextSurahLoad = false;
  int? _lastKnownVisibleAyah;
  int _suppressAutoSaveUntilMs = 0;
  int? _startupRestoreTargetAyah;
  int _restoreGuardToken = 0;
  bool _userInterruptedRestore = false;

  // GlobalKeys for scrolling to specific ayahs
  final Map<int, GlobalKey> _ayahKeys = {};
  ReaderNavigationProvider? _readerNavigationProvider;

  static String _surahListCacheKey(String langCode) =>
      'reader_surah_list_$langCode';

  static String _toArabicIndicDigits(int value) {
    const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final digits = value.toString().split('');
    return digits.map((d) => arabicIndic[int.parse(d)]).join();
  }

  static String _localizedDigits(int value, String languageCode) {
    if (languageCode == 'ar' || languageCode == 'ur') {
      return _toArabicIndicDigits(value);
    }
    return value.toString();
  }

  List<Map<String, dynamic>> _fallbackSurahList() {
    return List<Map<String, dynamic>>.generate(114, (index) {
      final id = index + 1;
      return {'id': id, 'name_simple': 'Surah $id', 'name_arabic': 'سورة $id'};
    }, growable: false);
  }

  List<Map<String, dynamic>> _surahsForSelector() {
    return _allSurahs.isNotEmpty ? _allSurahs : _fallbackSurahList();
  }

  Future<List<Map<String, dynamic>>?> _loadCachedSurahList(
    String langCode,
  ) async {
    try {
      final box = Hive.box('settings');
      final raw = box.get(_surahListCacheKey(langCode));
      if (raw is List) {
        final cached = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        if (cached.isNotEmpty) {
          return cached;
        }
      }
    } catch (_) {
      // Ignore cache failures and continue with fallback behavior.
    }
    return null;
  }

  Future<void> _saveCachedSurahList(
    String langCode,
    List<Map<String, dynamic>> surahs,
  ) async {
    try {
      final box = Hive.box('settings');
      await box.put(_surahListCacheKey(langCode), surahs);
    } catch (_) {
      // Ignore cache persistence failures.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadSavedReaderViewMode();
    _loadSavedAyahContentMode();
    _loadSavedMushafTextScale();

    // Restore last read position
    final bookmarks = context.read<BookmarkProvider>();
    _selectedSurah = bookmarks.lastReadSurah;
    _ayahModeAnchorAyah = bookmarks.lastReadAyah;
    _scrollController = ScrollController(initialScrollOffset: 0.0);
    if (kDebugMode) {
      print(
        '📱 initState: restored surah=$_selectedSurah, lastReadAyah=${bookmarks.lastReadAyah}',
      );
    }

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

      final ayahIdx = _ayahs.indexWhere(
        (a) => a.ayahNumber == _playingAyahNumber,
      );
      if (ayahIdx < 0) return;
      final wordCount = _ayahs[ayahIdx].words.length;
      if (wordCount <= 0) return;

      final ratio = (position.inMilliseconds / total.inMilliseconds).clamp(
        0.0,
        0.9999,
      );
      final nextWordIndex = (ratio * wordCount).floor().clamp(0, wordCount - 1);

      if (nextWordIndex != _activeWordIndex) {
        setState(() => _activeWordIndex = nextWordIndex);
      }
    });

    // Debounced scroll tracking - save every 1 second while scrolling
    _scrollController.addListener(() {
      _scrollSaveTimer?.cancel();
      _scrollSaveTimer = Timer(
        const Duration(milliseconds: 500),
        _saveScrollPosition,
      );
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
    unawaited(
      context
          .read<DailyLessonProvider>()
          .markReaderProgress(surah: request.surah, ayah: request.ayah)
          .then((completedNow) async {
            if (!completedNow || !mounted) return;
            await context.read<StreakProvider>().recordActivity();
          }),
    );

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
      final saved =
          box.get(_readerViewModeKey, defaultValue: _ReaderViewMode.ayah.name)
              as String;
      _viewMode = saved == _ReaderViewMode.page.name
          ? _ReaderViewMode.page
          : _ReaderViewMode.ayah;
    } catch (_) {
      _viewMode = _ReaderViewMode.ayah;
    }
  }

  void _loadSavedAyahContentMode() {
    try {
      final box = Hive.box('settings');
      final saved =
          box.get(
                _ayahContentModeKey,
                defaultValue: _AyahContentMode.arabicWithTranslation.name,
              )
              as String;
      _ayahContentMode = _AyahContentMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => _AyahContentMode.arabicWithTranslation,
      );
    } catch (_) {
      _ayahContentMode = _AyahContentMode.arabicWithTranslation;
    }
  }

  void _loadSavedMushafTextScale() {
    try {
      final saved = Hive.box(
        'settings',
      ).get(_mushafTextScaleKey, defaultValue: 1.0);
      _mushafTextScale = (saved as num).toDouble().clamp(0.8, 1.6).toDouble();
    } catch (_) {
      _mushafTextScale = 1;
    }
  }

  void _persistMushafTextScale() {
    try {
      unawaited(
        Hive.box('settings').put(_mushafTextScaleKey, _mushafTextScale),
      );
    } catch (_) {
      // Ignore persistence failures and keep runtime state.
    }
  }

  void _persistReaderViewMode(_ReaderViewMode mode) {
    try {
      final box = Hive.box('settings');
      unawaited(box.put(_readerViewModeKey, mode.name));
    } catch (_) {
      // Ignore persistence failures and keep runtime state.
    }
  }

  void _persistAyahContentMode(_AyahContentMode mode) {
    try {
      final box = Hive.box('settings');
      unawaited(box.put(_ayahContentModeKey, mode.name));
    } catch (_) {
      // Ignore persistence failures and keep runtime state.
    }
  }

  void _cycleAyahContentMode() {
    final nextIndex =
        (_ayahContentMode.index + 1) % _AyahContentMode.values.length;
    final nextMode = _AyahContentMode.values[nextIndex];
    setState(() {
      _ayahContentMode = nextMode;
    });
    _persistAyahContentMode(nextMode);
  }

  bool get _showsArabicText => true;

  bool get _showsTranslationText =>
      _ayahContentMode == _AyahContentMode.arabicWithTranslation;

  String get _ayahContentModeTooltip {
    switch (_ayahContentMode) {
      case _AyahContentMode.arabicOnly:
        return 'Reading mode: Arabic only';
      case _AyahContentMode.arabicWithTranslation:
        return 'Reading mode: Arabic and translation';
    }
  }

  IconData get _ayahContentModeIcon {
    switch (_ayahContentMode) {
      case _AyahContentMode.arabicOnly:
        return Icons.translate;
      case _AyahContentMode.arabicWithTranslation:
        return Icons.translate;
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
        debugPrint(
          '🧭 Restore guard release: immediate '
          '(mode=$_viewMode, userInterrupted=$_userInterruptedRestore)',
        );
        _startupRestoreTargetAyah = null;
        _suppressAutoSaveUntilMs = 0;
        return;
      }

      final visibleAyah = _findTopVisibleAyahNumber();
      final aligned =
          visibleAyah != null && (visibleAyah - targetAyah).abs() <= 0;
      debugPrint(
        '🧭 Restore guard check: target=$targetAyah, '
        'visible=${visibleAyah ?? '-'}, aligned=$aligned, '
        'remaining=$remainingChecks',
      );
      if (aligned || remainingChecks <= 0) {
        debugPrint(
          '🧭 Restore guard release: '
          '${aligned ? 'aligned' : 'retries-exhausted'}',
        );
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
      _suppressAutoSaveUntilMs = DateTime.now().millisecondsSinceEpoch + 900;

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

          final scrollOffset = _scrollController.hasClients
              ? _scrollController.offset
              : 0.0;
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
          final progress = (_scrollController.offset / maxExtent).clamp(
            0.0,
            1.0,
          );
          final idx = (progress * (_ayahs.length - 1)).round().clamp(
            0,
            _ayahs.length - 1,
          );
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
          final scrollOffset = _scrollController.hasClients
              ? _scrollController.offset
              : 0.0;
          context.read<BookmarkProvider>().saveLastRead(
            _selectedSurah,
            topVisibleAyah,
            scrollOffset: scrollOffset,
            caller: '[ayah-mode/scroll]',
          );
          unawaited(_recordTodayLessonProgress(topVisibleAyah));
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error saving to BookmarkProvider: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _saveScrollPosition: $e');
      }
    }
  }

  Future<void> _recordTodayLessonProgress(int ayahNumber) async {
    if (!mounted) return;

    final completedNow = await context
        .read<DailyLessonProvider>()
        .markReaderProgress(surah: _selectedSurah, ayah: ayahNumber);

    if (completedNow && mounted) {
      await context.read<StreakProvider>().recordActivity();
    }
  }

  Future<void> _initData() async {
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    _lastLoadedLanguageCode = langCode;
    final cachedSurahs = await _loadCachedSurahList(langCode);
    if (mounted && cachedSurahs != null) {
      setState(() => _allSurahs = cachedSurahs);
    }
    try {
      final surahs = await _api.fetchSurahList(langCode: langCode);
      if (mounted) setState(() => _allSurahs = surahs);
      await _saveCachedSurahList(langCode, surahs);
    } catch (_) {}
    _loadSurah();
  }

  Future<void> _handleLocaleChange(String langCode) async {
    if (!mounted || _lastLoadedLanguageCode == langCode) return;

    final anchorAyah = _viewMode == _ReaderViewMode.ayah
        ? (_findTopVisibleAyahNumber() ??
              _playingAyahNumber ??
              _lastKnownVisibleAyah ??
              1)
        : _currentMushafAnchorAyah();

    _lastLoadedLanguageCode = langCode;
    _forceRefreshNextSurahLoad = true;
    _pendingScrollAyah = anchorAyah;
    _pendingScrollOffset = 0.0;
    _didInitialReopenRestore = true;

    try {
      final surahs = await _api.fetchSurahList(langCode: langCode);
      if (mounted) {
        setState(() {
          _allSurahs = surahs;
        });
      }
      await _saveCachedSurahList(langCode, surahs);
    } catch (_) {
      // Fall back to cached surah metadata when offline.
      final cachedSurahs = await _loadCachedSurahList(langCode);
      if (mounted && cachedSurahs != null && cachedSurahs.isNotEmpty) {
        setState(() {
          _allSurahs = cachedSurahs;
        });
      }
    }

    if (mounted) {
      _loadSurah();
    }
  }

  @override
  void dispose() {
    // Cancel the scroll save timer
    _scrollSaveTimer?.cancel();
    _mushafScrubberHideTimer?.cancel();
    // Save position one final time before closing
    _saveScrollPosition();
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _loadSurah({bool allowFallback = true}) async {
    final loadVersion = ++_surahLoadVersion;
    final langCode = context.read<LocaleProvider>().locale.languageCode;
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
      final cachedVerses = await _quranOfflineSync.getCachedSurah(
        _selectedSurah,
      );
      final allVerses = <Map<String, dynamic>>[];
      Map<String, String> tajweedMap = <String, String>{};
      final forceRefresh = _forceRefreshNextSurahLoad;
      final needsLocalizedRefresh = !_cacheHasTranslationForLanguage(
        cachedVerses,
        langCode,
      );

      if (cachedVerses != null &&
          cachedVerses.isNotEmpty &&
          !needsLocalizedRefresh &&
          !forceRefresh) {
        allVerses.addAll(cachedVerses);
        tajweedMap = await _quranOfflineSync.getCachedTajweedMap(
          _selectedSurah,
        );
      } else {
        int page = 1;
        while (true) {
          final verses = await _api.fetchVerses(
            surahNumber: _selectedSurah,
            langCode: langCode,
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

      Map<String, String> audioMap = _contentSync.getCachedRecitationMap(
        reciterId: reciterId,
        surahNumber: _selectedSurah,
      );
      try {
        if (audioMap.isEmpty) {
          audioMap = await _api.fetchAudioFiles(
            reciterId: reciterId,
            surahNumber: _selectedSurah,
          );
          await _contentSync.cacheRecitationMap(
            reciterId: reciterId,
            surahNumber: _selectedSurah,
            audioUrls: audioMap,
          );
        }
      } catch (_) {
        // Audio URLs are optional when offline. Cached audio still works.
      }

      await _loadJuzBoundaries();

      if (kDebugMode) {
        print('📻 AUDIO MAP KEYS: ${audioMap.keys.toList()}');
        print('📻 AUDIO MAP SIZE: ${audioMap.length}');
        if (audioMap.isNotEmpty) {
          print('📻 FIRST ENTRY: ${audioMap.entries.first}');
        } else {
          print('❌ AUDIO MAP IS EMPTY!');
        }
      }

      if (mounted && loadVersion == _surahLoadVersion) {
        setState(() {
          _loading = false;
          _ayahs = AyahMapper.fromApiList(
            allVerses,
            tajweedMap: tajweedMap,
            requestedLangCode: langCode,
          );
          _audioUrls = audioMap;
          _activeWordIndex = -1;
          _currentMushafPageIndex = 0;
          _ayahKeys.clear();
          for (final a in _ayahs) {
            _ayahKeys[a.ayahNumber] = GlobalKey();
          }
        });
        if (kDebugMode) {
          print('📻 AFTER SETSTATE: _audioUrls.length=${_audioUrls.length}');
        }
        _refreshOfflineStatus();
        // Defer position restore until widgets are rendered.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restorePositionAfterSurahLoad();
        });
      }
      _forceRefreshNextSurahLoad = false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ ERROR IN LOAD SURAH: $e');
      }

      final fallbackSurah = await _quranOfflineSync.getFirstCachedSurahNumber();
      if (allowFallback &&
          fallbackSurah != null &&
          fallbackSurah != _selectedSurah) {
        final fallbackVerses = await _quranOfflineSync.getCachedSurah(
          fallbackSurah,
        );
        if (fallbackVerses != null && fallbackVerses.isNotEmpty) {
          final fallbackTajweed = await _quranOfflineSync.getCachedTajweedMap(
            fallbackSurah,
          );
          if (mounted && loadVersion == _surahLoadVersion) {
            setState(() {
              _selectedSurah = fallbackSurah;
              _loading = false;
              _ayahs = AyahMapper.fromApiList(
                fallbackVerses,
                tajweedMap: fallbackTajweed,
                requestedLangCode: langCode,
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
          _ayahs = const [];
          _audioUrls = {};
        });
      }
    }
  }

  bool _cacheHasTranslationForLanguage(
    List<Map<String, dynamic>>? verses,
    String langCode,
  ) {
    if (verses == null || verses.isEmpty) return false;
    if (langCode == 'ar') return true;

    for (final verse in verses) {
      final rawTranslations = verse['translations'];
      if (rawTranslations is! List) continue;
      for (final translation in rawTranslations) {
        if (translation is! Map) continue;
        final map = Map<String, dynamic>.from(translation);
        final resourceId = map['resource_id'];
        final text = (map['text'] as String? ?? '').trim();
        final translationLang = AyahMapper.langCodeFromResourceId(resourceId);
        if (translationLang == langCode && text.isNotEmpty) {
          return true;
        }
      }
    }

    return false;
  }

  void _applyReciterChange(int reciterId) {
    if (_lastObservedReciterId == -1) {
      _lastObservedReciterId = reciterId;
      return;
    }
    if (reciterId == _lastObservedReciterId) return;

    _lastObservedReciterId = reciterId;
    final currentOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    _stopAudio();
    setState(() {
      _pendingScrollOffset = currentOffset;
      _activeWordIndex = -1;
    });
    _loadSurah();
  }

  Future<Map<int, int>> _loadJuzBoundaries() async {
    List<Map<String, dynamic>> juzs = const [];
    try {
      juzs = await _api.fetchJuzList();
      await Hive.box('settings').put(_juzListCacheKey, juzs);
    } catch (_) {
      final cached = Hive.box('settings').get(_juzListCacheKey);
      if (cached is List) {
        juzs = cached
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }

    final boundaries = <int, int>{};
    final rangesBySurah = <int, List<_JuzRange>>{};
    final surahStr = _selectedSurah.toString();
    for (final j in juzs) {
      final juzNum = j['juz_number'] as int;
      final mappingRaw = j['verse_mapping'];
      final mapping = mappingRaw is Map
          ? Map<String, dynamic>.from(mappingRaw)
          : <String, dynamic>{};
      for (final entry in mapping.entries) {
        final surah = int.tryParse(entry.key);
        final range = entry.value as String?;
        if (surah == null || range == null || range.isEmpty) continue;
        final parts = range.split('-');
        final startAyah = int.tryParse(parts.first) ?? 0;
        final endAyah = parts.length > 1
            ? (int.tryParse(parts.last) ?? startAyah)
            : startAyah;
        if (startAyah <= 0 || endAyah <= 0) continue;
        rangesBySurah
            .putIfAbsent(surah, () => <_JuzRange>[])
            .add(
              _JuzRange(
                juzNumber: juzNum,
                startAyah: startAyah,
                endAyah: endAyah,
              ),
            );
      }
      if (mapping.containsKey(surahStr)) {
        final range = mapping[surahStr] as String;
        final startAyah = int.tryParse(range.split('-').first) ?? 0;
        if (startAyah > 1) boundaries[startAyah] = juzNum;
        if (startAyah == 1 && juzNum > 1) boundaries[1] = juzNum;
      }
    }
    for (final list in rangesBySurah.values) {
      list.sort((a, b) => a.startAyah.compareTo(b.startAyah));
    }
    if (mounted) {
      setState(() {
        _juzBoundaries = boundaries;
        _juzRangesBySurah = rangesBySurah;
      });
    }
    return boundaries;
  }

  void _scrollToLastReadAyah() {
    final bookmarks = context.read<BookmarkProvider>();
    if (bookmarks.lastReadSurah != _selectedSurah || _ayahs.isEmpty) {
      if (kDebugMode) {
        print(
          '⚠️ Not scrolling: mismatch/empty (lastReadSurah=${bookmarks.lastReadSurah}, _selectedSurah=$_selectedSurah, count=${_ayahs.length})',
        );
      }
      return;
    }
    if (kDebugMode) {
      print(
        '🎯 _scrollToLastReadAyah: ayah=${bookmarks.lastReadAyah} in surah $_selectedSurah',
      );
    }
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

    // Proportional seed jump: estimate target position based on ayah index
    // ratio, then refine with directional steps. This handles surahs with
    // very long ayahs (e.g. Al-Hajj) where fixed 1200px steps can't converge.
    if (allowSeedJump && _scrollController.hasClients) {
      final targetIdx = _ayahs.indexWhere((a) => a.ayahNumber == ayahNumber);
      if (targetIdx >= 0) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          final anchorAyah =
              _findTopVisibleAyahNumber() ?? _lastKnownVisibleAyah;
          final anchorIdx = anchorAyah == null
              ? -1
              : _ayahs.indexWhere((a) => a.ayahNumber == anchorAyah);
          final goingDown = anchorIdx >= 0
              ? targetIdx > anchorIdx
              : targetIdx >= (_ayahs.length ~/ 2);

          final deltaAyahs = anchorIdx >= 0
              ? (targetIdx - anchorIdx).abs()
              : _ayahs.length;

          double seed;
          if (deltaAyahs > 15 || anchorIdx < 0) {
            // Large distance or no anchor: jump proportionally by index ratio.
            final ratio =
                targetIdx / (_ayahs.length - 1).clamp(1, _ayahs.length);
            seed = (ratio * maxExtent).clamp(0.0, maxExtent);
          } else {
            // Small distance: use fixed steps for precision.
            final stepPx = deltaAyahs <= 3
                ? 220.0
                : deltaAyahs <= 10
                ? 520.0
                : 1200.0;
            final current = _scrollController.offset;
            seed = (current + (goingDown ? stepPx : -stepPx)).clamp(
              0.0,
              maxExtent,
            );

            if ((seed - current).abs() < 0.5) {
              seed = (current + (goingDown ? -stepPx : stepPx)).clamp(
                0.0,
                maxExtent,
              );
            }
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
        _scrollToAyah(
          ayah,
          maxAttempts: 8,
          alignment: 0.0,
          allowSeedJump: true,
        );
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

    if (kDebugMode) {
      print(
        '🔄 Restoring scroll to offset=$validOffset (target=$offset, max=$maxExtent)',
      );
    }
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
    if (kDebugMode) {
      print('🔢 DOUBLE TAP: ayah ${ayah.ayahNumber}');
    }
    context.read<BookmarkProvider>().saveLastRead(
      ayah.surahNumber,
      ayah.ayahNumber,
      caller: '[ayah-mode/double-tap]',
    );

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
      if (kDebugMode) {
        print('🎵 CALLING _playAyah FOR ${ayah.ayahNumber}');
      }
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
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
        ayah.surahNumber,
        ayah.ayahNumber,
        caller: '[ayah-mode/play-all]',
      );

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

    if (kDebugMode) {
      print(
        '🎵 PLAY AYAH: verseKey=$verseKey, mapHas=${_audioUrls.containsKey(verseKey)}, url=$url',
      );
    }

    if (url.isEmpty) {
      if (kDebugMode) {
        print('❌ ERROR: EMPTY URL FOR $verseKey');
      }
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
    if (kDebugMode) {
      print('📂 PLAYING URL: $preview');
    }
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
        if (kDebugMode) {
          print('✅ playFile succeeded from cache');
        }
      } else {
        await _audio.playUrl(url);
        if (kDebugMode) {
          print('✅ playUrl succeeded');
        }
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
      if (kDebugMode) {
        print('❌ Exception in playUrl: $e');
      }
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
        ayah.surahNumber,
        ayah.ayahNumber,
        caller: '[ayah-mode/play-single]',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving last read: $e');
      }
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
        if (kDebugMode) {
          print('❌ Error scrolling: $e');
        }
      }
    }

    return true;
  }

  String _resolveAyahAudioUrl(Ayah ayah) {
    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    final verseKey = '${ayah.surahNumber}:${ayah.ayahNumber}';
    final rawUrl =
        _audioUrls[verseKey] ??
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
      unawaited(
        showDialog<void>(
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6E6E6E),
                      ),
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
        ),
      );
    }

    try {
      var audioMap = _audioUrls;
      if (audioMap.isEmpty) {
        audioMap = _contentSync.getCachedRecitationMap(
          reciterId: reciterId,
          surahNumber: _selectedSurah,
        );
      }
      if (audioMap.isEmpty) {
        audioMap = await _api.fetchAudioFiles(
          reciterId: reciterId,
          surahNumber: _selectedSurah,
        );
        await _contentSync.cacheRecitationMap(
          reciterId: reciterId,
          surahNumber: _selectedSurah,
          audioUrls: audioMap,
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

    final readerStrings = _ReaderStrings.of(context);
    final tafsirId = context.read<TafseerProvider>().selectedTafsirId;
    final progress = ValueNotifier<Map<String, int>>({'done': 0, 'total': 1});

    setState(() {
      _isDownloadingSurahTafseer = true;
    });

    if (mounted) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(readerStrings.text('downloading_tafseer')),
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
                      readerStrings.text('surah_tafseer_status', {
                        'surah': '$_selectedSurah',
                        'id': '$tafsirId',
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6E6E6E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: ratio),
                    const SizedBox(height: 8),
                    Text(
                      readerStrings.text('downloaded_of_ayahs', {
                        'done': '$done',
                        'total': '$total',
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    try {
      final keys = await _fetchCurrentSurahVerseKeysForTafseer();
      if (keys.isEmpty) {
        throw Exception(readerStrings.text('no_verses_for_surah'));
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
            content: Text(
              readerStrings.text('surah_tafseer_downloaded', {
                'surah': '$_selectedSurah',
              }),
            ),
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
            content: Text(
              readerStrings.text('tafseer_download_failed', {'error': '$e'}),
            ),
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
    final tafseerProvider = context.read<TafseerProvider>();
    final tafsirId = tafseerProvider.selectedTafsirId;
    final tafsirName = tafseerProvider.selectedTafsirName;
    final verseKey = '${ayah.surahNumber}:${ayah.ayahNumber}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TafseerSheet(
        verseKey: verseKey,
        tafsirId: tafsirId,
        tafsirName: tafsirName,
        surahName: _surahArabicName(ayah.surahNumber),
        languageCode: Localizations.localeOf(context).languageCode,
        onTafsirSelected: (id, name) {
          return tafseerProvider.setTafsir(id, name: name);
        },
      ),
    );
  }

  // ─── Bookmarks ────────────────────────────────────────────────────────────

  void _toggleBookmark(Ayah ayah) {
    final l10n = AppLocalizations.of(context);
    final bm = context.read<BookmarkProvider>();
    if (bm.isBookmarked(ayah.surahNumber, ayah.ayahNumber)) {
      bm.removeBookmark(ayah.surahNumber, ayah.ayahNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.get('bookmark_removed')),
            duration: const Duration(seconds: 1),
          ),
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

      final scrollOffset = _scrollController.hasClients
          ? _scrollController.offset
          : 0.0;
      bm.addBookmark(
        ayah.surahNumber,
        ayah.ayahNumber,
        label: label,
        scrollOffset: scrollOffset,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.get('bookmark_added')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _shareAyah(Ayah ayah, Rect shareOrigin) async {
    Ayah shareAyah = ayah;
    if (shareAyah.translation('en').isEmpty ||
        shareAyah.plainArabicText().isEmpty) {
      try {
        final raw = await _api.fetchVerse(
          surahNumber: ayah.surahNumber,
          ayahNumber: ayah.ayahNumber,
          langCode: 'en',
        );
        shareAyah = AyahMapper.fromApi(raw, requestedLangCode: 'en');
      } catch (error) {
        debugPrint('Unable to load English translation for sharing: $error');
      }
    }

    final surahName = _surahDisplayName(ayah.surahNumber);
    final translation = shareAyah.translation('en');
    final arabic = shareAyah.plainArabicText();
    final text = <String>[
      '$surahName ${ayah.surahNumber}:${ayah.ayahNumber}',
      if (arabic.isNotEmpty) '',
      if (arabic.isNotEmpty) arabic,
      if (translation.isNotEmpty) '',
      if (translation.isNotEmpty) translation,
      '',
      AppLinks.appStore,
    ].join('\n');

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: '$surahName ${ayah.surahNumber}:${ayah.ayahNumber}',
          sharePositionOrigin: shareOrigin,
        ),
      );
    } catch (error) {
      debugPrint('Ayah share failed: $error');
    }
  }

  void _togglePageBookmark() {
    final l10n = AppLocalizations.of(context);
    final bm = context.read<BookmarkProvider>();
    final pageNumber = _currentMushafPageIndex + 1;
    if (bm.isPageBookmarked(pageNumber)) {
      bm.removePageBookmark(pageNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.get('page_bookmark_removed')),
            duration: const Duration(seconds: 1),
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
        SnackBar(
          content: Text(l10n.get('page_bookmark_added')),
          duration: const Duration(seconds: 1),
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
              bookmark.surah,
              bookmark.ayah,
              caller: '[ayah-mode/bookmark-tap]',
            );
            _setRestoreGuard(bookmark.ayah, durationMs: 2200);
            _scrollToAyah(
              bookmark.ayah,
              maxAttempts: 20,
              alignment: 0.0,
              allowSeedJump: true,
            );
            Future.delayed(const Duration(milliseconds: 650), () {
              if (!mounted || _viewMode != _ReaderViewMode.ayah) return;
              _scrollToAyah(
                bookmark.ayah,
                maxAttempts: 8,
                alignment: 0.0,
                allowSeedJump: true,
              );
            });
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

  void _onWordTapped(
    TajweedRule rule,
    String word,
    Ayah ayah, {
    String? wordAudioUrl,
  }) {
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    final l10n = AppLocalizations.of(context);
    final langCode = context.watch<LocaleProvider>().locale.languageCode;
    final selectedReciterId = context
        .watch<RecitationProvider>()
        .selectedReciterId;

    if (_lastLoadedLanguageCode != null &&
        langCode != _lastLoadedLanguageCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleLocaleChange(langCode);
        }
      });
    }

    if (selectedReciterId != _lastObservedReciterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyReciterChange(selectedReciterId);
      });
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          actionsPadding: const EdgeInsets.only(left: 2, right: 8),
          title: Padding(
            padding: const EdgeInsets.only(left: 0, right: 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _SurahSelector(
                surahs: _surahsForSelector(),
                selected: _selectedSurah,
                juzStarts: _juzStartReferences(),
                onBeforeOpen: () => _hideMushafScrubberOverlay(),
                onChanged: (surah, {ayah}) {
                  _selectedSurah = surah;
                  if (ayah != null) {
                    _pendingScrollAyah = ayah;
                    _pendingScrollOffset = 0.0;
                    unawaited(
                      context.read<BookmarkProvider>().saveLastRead(
                        surah,
                        ayah,
                        caller: '[surah-picker/juz-jump]',
                      ),
                    );
                  }
                  _stopAudio();
                  _loadSurah(allowFallback: false);
                },
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _viewMode == _ReaderViewMode.page
                    ? Icons.view_list_outlined
                    : Icons.chrome_reader_mode_outlined,
                size: 22,
              ),
              tooltip: _viewMode == _ReaderViewMode.page
                  ? l10n.get('switch_to_ayah_view')
                  : l10n.get('switch_to_page_view'),
              onPressed: _toggleReaderViewMode,
            ),
            // Bookmarks
            IconButton(
              icon: const Icon(Icons.bookmark_border_rounded, size: 22),
              tooltip: l10n.get('bookmarks'),
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
              tooltip: _isPlayingAll ? l10n.get('stop') : l10n.get('play_all'),
              onPressed: _ayahs.isNotEmpty ? _togglePlayAll : null,
            ),
            IconButton(
              icon: Icon(
                _viewMode == _ReaderViewMode.page
                    ? Icons.text_fields_rounded
                    : _ayahContentModeIcon,
                size: 22,
              ),
              tooltip: _viewMode == _ReaderViewMode.page
                  ? 'Quran text size'
                  : _ayahContentModeTooltip,
              onPressed: _viewMode == _ReaderViewMode.page
                  ? _showMushafTextSizeControls
                  : _cycleAyahContentMode,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_viewMode == _ReaderViewMode.ayah) ...[
              if (_showsArabicText) ...[
                TajweedLegend(rules: TajweedRule.values, langCode: langCode),
                const Divider(height: 0.5),
              ],
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
      ),
    );
  }

  Widget _buildAyahList(String langCode, {required bool pageMode}) {
    final showOpeningHeader =
        !pageMode && _showsArabicText && _shouldShowOpeningSurahHeader();
    final showOpeningBasmala = showOpeningHeader && _shouldShowOpeningBasmala();
    final topJuzNumber = !pageMode ? _topJuzNumberForCurrentSurah() : null;
    final showTopJuzMarker = !pageMode && topJuzNumber != null;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _cancelProgrammaticAyahScroll(),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(vertical: pageMode ? 12 : 8),
        itemCount:
            _ayahs.length +
            (showOpeningHeader ? 1 : 0) +
            (showTopJuzMarker ? 1 : 0),
        itemBuilder: (context, i) {
          if (showTopJuzMarker && i == 0) {
            return _JuzMarker(juzNumber: topJuzNumber);
          }

          final openingHeaderIndex = showTopJuzMarker ? 1 : 0;
          if (showOpeningHeader && i == openingHeaderIndex) {
            return _BasmalaOpener(
              surahName: _surahArabicName(_selectedSurah),
              showBasmala: showOpeningBasmala,
            );
          }

          final ayahIndex =
              i - (showOpeningHeader ? 1 : 0) - (showTopJuzMarker ? 1 : 0);
          final ayah = _ayahs[ayahIndex];
          final juzNumber = _juzBoundaries[ayah.ayahNumber];
          final showInlineJuzMarker =
              juzNumber != null &&
              !(showTopJuzMarker &&
                  ayah.ayahNumber == 1 &&
                  juzNumber == topJuzNumber);
          final isPlaying = _playingAyahNumber == ayah.ayahNumber;
          final isBookmarked = context.watch<BookmarkProvider>().isBookmarked(
            ayah.surahNumber,
            ayah.ayahNumber,
          );

          return Column(
            key: _ayahKeys[ayah.ayahNumber],
            children: [
              if (showInlineJuzMarker) _JuzMarker(juzNumber: juzNumber),
              if (!pageMode && ayahIndex > 0 && juzNumber == null)
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
                  showArabic: _showsArabicText,
                  showTranslation: _showsTranslationText,
                  langCode: langCode,
                  isPlaying: isPlaying,
                  activeWordIndex: isPlaying ? _activeWordIndex : -1,
                  isBookmarked: isBookmarked,
                  onWordTapped: _onWordTapped,
                  onDoubleTap: () => _playSingleAyah(ayah),
                  onTafseerTap: () => _showTafseer(ayah),
                  onBookmarkTap: () => _toggleBookmark(ayah),
                  onShareTap: _shareAyah,
                ),
            ],
          );
        },
      ),
    );
  }

  bool _shouldShowOpeningSurahHeader() {
    if (_selectedSurah <= 0 || _selectedSurah > 114) return false;
    if (_ayahs.isEmpty) return false;
    return _ayahs.first.surahNumber == _selectedSurah;
  }

  bool _shouldShowOpeningBasmala() {
    return _shouldShowOpeningSurahHeader() && _selectedSurah != 9;
  }

  int? _topJuzNumberForCurrentSurah() {
    // Only show a top-of-list Juz marker when the surah itself starts at a
    // Juz boundary (ayah 1). Otherwise, show markers inline at true boundary
    // ayahs (e.g. Al-Baqarah ayah 142 for Juz 2).
    return _juzBoundaries[1];
  }

  int? _juzNumberForAyah(int surahNumber, int ayahNumber) {
    final ranges = _juzRangesBySurah[surahNumber];
    if (ranges == null || ranges.isEmpty) {
      if (surahNumber == _selectedSurah) return _juzBoundaries[ayahNumber];
      return null;
    }
    for (final range in ranges) {
      if (ayahNumber >= range.startAyah && ayahNumber <= range.endAyah) {
        return range.juzNumber;
      }
    }
    return null;
  }

  Map<int, ({int surah, int ayah})> _juzStartReferences() {
    final starts = <int, ({int surah, int ayah})>{};

    for (final entry in _juzRangesBySurah.entries) {
      final surah = entry.key;
      for (final range in entry.value) {
        final existing = starts[range.juzNumber];
        if (existing == null ||
            surah < existing.surah ||
            (surah == existing.surah && range.startAyah < existing.ayah)) {
          starts[range.juzNumber] = (surah: surah, ayah: range.startAyah);
        }
      }
    }

    return starts;
  }

  Future<void> _toggleReaderViewMode() async {
    if (_viewMode == _ReaderViewMode.ayah) {
      final ayahOffset = _scrollController.hasClients
          ? _scrollController.offset
          : context.read<BookmarkProvider>().lastScrollOffset;
      final anchorAyah =
          _findTopVisibleAyahNumber() ??
          context.read<BookmarkProvider>().lastReadAyah;
      debugPrint(
        '🔄 VIEW TOGGLE: ayah → page | surah=$_selectedSurah, anchorAyah=$anchorAyah, offset=$ayahOffset',
      );
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
      '🔄 VIEW TOGGLE: page → ayah | page=${_currentMushafPageIndex + 1}',
    );
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
    final didNavigateInPageMode =
        entryPageNumber == null ||
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

    debugPrint(
      '🔄 PAGE→AYAH anchor: didNavigate=$didNavigateInPageMode, '
      'entryPage=$entryPageNumber, currentPage=$currentPageNumber, '
      'targetAyah=$targetAyah (ayahModeAnchor=$_ayahModeAnchorAyah), '
      'loadedSurah=${_ayahs.isEmpty ? '-' : _ayahs.first.surahNumber}, '
      'reload=$shouldReloadSurah',
    );

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
      '🔄 VIEW MODE: now=ayah | surah=$anchorSurah, targetAyah=$targetAyah',
    );
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
            '🔄 PAGE→AYAH seed jump: offset=$clamped (saved=$returnOffset)',
          );
          _scrollController.jumpTo(clamped);
        }
      } else if (didNavigateInPageMode) {
        debugPrint(
          '🔄 PAGE→AYAH saved-offset seed skipped: user navigated pages in mushaf mode',
        );
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

  String _surahDisplayName(int surahNumber) {
    for (final surah in _allSurahs) {
      if (surah['id'] != surahNumber) continue;
      final simple = (surah['name_simple'] as String? ?? '').trim();
      final arabic = (surah['name_arabic'] as String? ?? '').trim();
      if (simple.isNotEmpty && arabic.isNotEmpty) return '$simple ($arabic)';
      if (simple.isNotEmpty) return simple;
      if (arabic.isNotEmpty) return arabic;
    }
    return 'Surah $surahNumber';
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

  _MushafPageAnchor? _localMushafAnchorForPage(int pageNumber) {
    final ayah = _localFirstAyahForPage(pageNumber);
    if (ayah == null) return null;
    return _MushafPageAnchor(
      pageNumber: pageNumber,
      surah: ayah.surahNumber,
      ayah: ayah.ayahNumber,
      juzNumber: ayah.juzNumber,
    );
  }

  int _pageNumberForAyah(int ayahNumber) {
    final fallbackPage = (_currentMushafPageIndex + 1).clamp(1, 604);
    if (_ayahs.isEmpty) return fallbackPage;

    // Guard against transient stale ayah lists during cross-surah switches.
    // If the currently rendered ayahs belong to a different surah than the
    // selected one, use the current mushaf page instead of a wrong lookup.
    if (_ayahs.first.surahNumber != _selectedSurah) {
      debugPrint(
        '⚠️ _pageNumberForAyah fallback: stale ayahs for surah=${_ayahs.first.surahNumber}, selected=$_selectedSurah, ayah=$ayahNumber, page=$fallbackPage',
      );
      return fallbackPage;
    }

    final idx = _ayahs.indexWhere(
      (a) => a.surahNumber == _selectedSurah && a.ayahNumber == ayahNumber,
    );
    if (idx < 0) return fallbackPage;
    return _ayahs[idx].pageNumber;
  }

  Future<List<Ayah>> _loadMushafTextPage(int pageNumber) {
    final safePage = pageNumber.clamp(1, 604);
    return _mushafTextPageLoads.putIfAbsent(safePage, () async {
      var raw = await _quranOfflineSync.getCachedVersesForPage(safePage);
      final needsDivisionMetadata =
          raw.isNotEmpty &&
          raw.any((verse) => verse['rub_el_hizb_number'] == null);
      if (raw.isEmpty || needsDivisionMetadata) {
        final refreshed = await _api.fetchVersesByPage(
          pageNumber: safePage,
          langCode: 'ar',
        );
        if (refreshed.isNotEmpty) {
          raw = refreshed;
        }
      }
      if (raw.isEmpty) {
        throw StateError('No Quran text was returned for page $safePage');
      }
      return AyahMapper.fromApiList(raw, requestedLangCode: 'ar');
    });
  }

  void _retryMushafTextPage(int pageNumber) {
    setState(() {
      _mushafTextPageLoads.remove(pageNumber);
    });
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

    final localAnchor = _localMushafAnchorForPage(pageNumber);
    if (localAnchor != null) {
      _applyMushafPageAnchor(localAnchor);
      return;
    }

    try {
      final ayahs = await _loadMushafTextPage(pageNumber);
      if (ayahs.isEmpty || !mounted) return;
      final first = ayahs.first;
      _applyMushafPageAnchor(
        _MushafPageAnchor(
          pageNumber: pageNumber,
          surah: first.surahNumber,
          ayah: first.ayahNumber,
          juzNumber: first.juzNumber,
        ),
      );
    } catch (error) {
      debugPrint('Unable to load Mushaf page $pageNumber metadata: $error');
    }
  }

  void _applyMushafPageAnchor(_MushafPageAnchor anchor) {
    _mushafPageAnchorCache[anchor.pageNumber] = anchor;
    if (!mounted) return;
    setState(() {
      if (_currentMushafPageIndex + 1 == anchor.pageNumber) {
        _mushafCurrentAnchorSurah = anchor.surah;
        _mushafCurrentAnchorAyah = anchor.ayah;
      }
      if (_viewMode == _ReaderViewMode.page &&
          _currentMushafPageIndex + 1 == anchor.pageNumber) {
        _selectedSurah = anchor.surah;
      }
    });
  }

  void _showMushafScrubberOverlay() {
    if (!mounted || _viewMode != _ReaderViewMode.page) return;
    setState(() {
      _showMushafScrubber = true;
    });
    _scheduleMushafScrubberAutoHide();
  }

  void _showMushafTextSizeControls() {
    _hideMushafScrubberOverlay();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final percentage = (_mushafTextScale * 100).round();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_fields_rounded),
                        const SizedBox(width: 10),
                        const Text(
                          'Quran text size',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$percentage%',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Slider(
                      value: _mushafTextScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      label: '$percentage%',
                      onChanged: (value) {
                        setState(() => _mushafTextScale = value);
                        setSheetState(() {});
                      },
                      onChangeEnd: (_) => _persistMushafTextScale(),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _mushafTextScale = 1);
                        _persistMushafTextScale();
                        setSheetState(() {});
                      },
                      child: const Text('Reset to 100%'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

    // Ensure last-read and selector use the anchor metadata for this page,
    // not stale data from the previous page while async metadata is pending.
    unawaited(() async {
      await _updateMushafAnchorForPage(pageNumber);
      if (!mounted || _currentMushafPageIndex != index) return;
      final anchorSurah = _currentMushafAnchorSurah();
      final anchorAyah = _currentMushafAnchorAyah();
      await context.read<BookmarkProvider>().saveLastRead(
        anchorSurah,
        anchorAyah,
        caller: '[page-mode/page-change]',
      );
    }());
  }

  Widget _buildMushafScrubber() {
    final previewPage =
        _mushafScrubberPreviewPage ?? (_currentMushafPageIndex + 1);
    final l10n = AppLocalizations.of(context);
    final langCode = Localizations.localeOf(context).languageCode;
    final previewPageText = _localizedDigits(previewPage, langCode);
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
                color: const Color(0xFFFFFCF3).withValues(alpha: 0.99),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF5F9584), width: 1.2),
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
                        '${l10n.get('page')} $previewPageText',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A4B39),
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
                            color: Color(0xFF123F32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: previewPage.toDouble(),
                        min: 1,
                        max: 604,
                        divisions: 603,
                        label: previewPageText,
                        activeColor: const Color(0xFF0B6B50),
                        inactiveColor: const Color(0xFFA9C4BA),
                        onChangeStart: (_) {
                          _mushafScrubberHideTimer?.cancel();
                          setState(() {
                            _isMushafScrubberDragging = true;
                          });
                        },
                        onChanged: (value) {
                          setState(() {
                            _mushafScrubberPreviewPage = value.round().clamp(
                              1,
                              604,
                            );
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
    return Stack(
      children: [
        AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: _showMushafScrubber ? 108 : 0),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _showMushafScrubberOverlay,
            onLongPress: _togglePageBookmark,
            child: PageView.builder(
              controller: _mushafPageController,
              itemCount: 604,
              reverse: true,
              pageSnapping: false,
              physics: const SinglePageScrollPhysics(),
              onPageChanged: _handleMushafPageChanged,
              itemBuilder: (context, index) {
                final pageNumber = index + 1;
                final isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;
                final pageAnchor =
                    _mushafPageAnchorCache[pageNumber] ??
                    _localMushafAnchorForPage(pageNumber);
                final pageSurah = pageAnchor?.surah ?? _selectedSurah;
                final pageAyah = pageAnchor?.ayah ?? 1;
                final pageJuz =
                    pageAnchor?.juzNumber ??
                    (pageAnchor != null
                        ? _juzNumberForAyah(pageSurah, pageAyah)
                        : null);
                final langCode = Localizations.localeOf(context).languageCode;
                final localizedPageNumber = _localizedDigits(
                  pageNumber,
                  langCode,
                );
                final surahName = _surahArabicName(pageSurah);
                final isPageBookmarked = bookmarkProvider.isPageBookmarked(
                  pageNumber,
                );

                return Padding(
                  padding: isLandscape
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _QuranPageBackground(
                        child: Column(
                          children: [
                            if (!isLandscape)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _MushafHeaderChip(
                                        text: pageJuz != null
                                            ? '${AppLocalizations.of(context).get('juz')} ${_localizedDigits(pageJuz, langCode)}'
                                            : '',
                                        alignment: Alignment.center,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _MushafHeaderChip(
                                        text: surahName,
                                        alignment: Alignment.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                margin: isLandscape
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFCF3),
                                  border: Border.all(
                                    color: const Color(0xFF5F9584),
                                    width: isLandscape ? 1.0 : 1.4,
                                  ),
                                ),
                                child: _MushafTextPage(
                                  pageNumber: pageNumber,
                                  pageFuture: _loadMushafTextPage(pageNumber),
                                  isLandscape: isLandscape,
                                  textScale: _mushafTextScale,
                                  onRetry: () =>
                                      _retryMushafTextPage(pageNumber),
                                ),
                              ),
                            ),
                            if (!isLandscape)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                                child: Text(
                                  localizedPageNumber,
                                  style: const TextStyle(
                                    fontFamily: 'UthmanicHafs',
                                    fontSize: 16,
                                    color: Color(0xFF0B5C45),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isPageBookmarked)
                        Positioned(
                          top: 2,
                          right: 6,
                          child: Icon(
                            Icons.bookmark,
                            color: Color(0xFFB8860B),
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
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
  final int? juzNumber;

  const _MushafPageAnchor({
    required this.pageNumber,
    required this.surah,
    required this.ayah,
    this.juzNumber,
  });
}

class _JuzRange {
  final int juzNumber;
  final int startAyah;
  final int endAyah;

  const _JuzRange({
    required this.juzNumber,
    required this.startAyah,
    required this.endAyah,
  });
}

class _MushafTextPage extends StatelessWidget {
  final int pageNumber;
  final Future<List<Ayah>> pageFuture;
  final bool isLandscape;
  final double textScale;
  final VoidCallback onRetry;

  const _MushafTextPage({
    required this.pageNumber,
    required this.pageFuture,
    required this.isLandscape,
    required this.textScale,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Ayah>>(
      future: pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
          );
        }
        if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 30,
                    color: Color(0xFF27866A),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Unable to load this Quran page',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF245B4B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final ayahs = snapshot.data!;
        final pageTexts = ayahs
            .map((ayah) => ayah.plainArabicText())
            .where((text) => text.isNotEmpty)
            .toList(growable: false);
        if (pageTexts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.text_snippet_outlined,
                    size: 30,
                    color: Color(0xFF27866A),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Quran text is unavailable for this page',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF245B4B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final fontSize = (isLandscape ? 22.0 : 26.0) * textScale;
        final pageText = StringBuffer();
        final markers = <_MushafBoundaryPlacement>[];
        for (var index = 0; index < ayahs.length; index++) {
          final ayah = ayahs[index];
          final arabic = ayah.plainArabicText();
          if (arabic.isEmpty) continue;
          final previousRubNumber = index == 0
              ? null
              : ayahs[index - 1].rubElHizbNumber;
          final startsRubElHizb =
              ayah.rubElHizbNumber != null &&
              (index == 0
                  ? arabic.contains('\u06DE')
                  : previousRubNumber != ayah.rubElHizbNumber);
          if (startsRubElHizb) {
            markers.add(
              _MushafBoundaryPlacement(
                textOffset: pageText.length,
                symbol: '\u06DE',
                label: _rubElHizbLabel(ayah),
                semanticLabel: 'Hizb boundary',
              ),
            );
          }
          pageText.write(
            '$arabic \u06DD${_arabicIndicDigits(ayah.ayahNumber)} ',
          );
        }
        final textStyle = TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: fontSize,
          height: isLandscape ? 1.8 : 2.0,
          color: const Color(0xFF050807),
          fontWeight: FontWeight.w500,
        );

        return Semantics(
          label: 'Quran page $pageNumber',
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(vertical: isLandscape ? 10 : 16),
              child: _MushafFlowText(
                text: pageText.toString(),
                style: textStyle,
                markers: markers,
                horizontalInset: isLandscape ? 20 : 14,
              ),
            ),
          ),
        );
      },
    );
  }

  static String _arabicIndicDigits(int value) {
    const western = '0123456789';
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    return value
        .toString()
        .split('')
        .map((digit) => arabicIndic[western.indexOf(digit)])
        .join();
  }

  static String _rubElHizbLabel(Ayah ayah) {
    final rubNumber = ayah.rubElHizbNumber;
    final hizbNumber =
        ayah.hizbNumber ?? (rubNumber == null ? null : (rubNumber + 3) ~/ 4);
    if (hizbNumber == null) return 'رُبْع حِزْب';

    final hizb = _arabicIndicDigits(hizbNumber);
    if (rubNumber == null) return 'الْحِزْبُ $hizb';

    final quarter = ((rubNumber - 1) % 4) + 1;
    return switch (quarter) {
      1 => 'الْحِزْبُ $hizb',
      2 => 'رُبْعُ الْحِزْبِ',
      3 => 'نِصْفُ الْحِزْبِ',
      _ => 'ثَلَاثَةُ أَرْبَاعِ الْحِزْبِ',
    };
  }
}

class _MushafBoundaryPlacement {
  final int textOffset;
  final String symbol;
  final String label;
  final String semanticLabel;

  const _MushafBoundaryPlacement({
    required this.textOffset,
    required this.symbol,
    required this.label,
    required this.semanticLabel,
  });
}

class _MushafFlowText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<_MushafBoundaryPlacement> markers;
  final double horizontalInset;

  const _MushafFlowText({
    required this.text,
    required this.style,
    required this.markers,
    required this.horizontalInset,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = constraints.maxWidth - (horizontalInset * 2);
        final textScaler = MediaQuery.textScalerOf(context);
        final textSpan = _buildTextSpan();
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          textScaler: textScaler,
        )..layout(maxWidth: textWidth);
        final textHeight = textPainter.height;
        final lineHeight = textPainter.preferredLineHeight;
        final markerOffsets = markers
            .map((marker) {
              final caret = textPainter.getOffsetForCaret(
                TextPosition(offset: marker.textOffset),
                Rect.zero,
              );
              return (
                marker: marker,
                top:
                    caret.dy +
                    ((lineHeight - 22) / 2).clamp(0, double.infinity),
                useLeftBorder: caret.dx < textPainter.width / 2,
              );
            })
            .toList(growable: false);
        textPainter.dispose();

        return SizedBox(
          width: constraints.maxWidth,
          height: textHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                left: horizontalInset,
                right: horizontalInset,
                child: Text.rich(
                  textSpan,
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                ),
              ),
              for (final placement in markerOffsets)
                Positioned(
                  top: placement.top,
                  left: placement.useLeftBorder ? 0 : null,
                  right: placement.useLeftBorder ? null : 0,
                  child: _MushafBorderMarker(
                    marker: placement.marker,
                    placedOnLeft: placement.useLeftBorder,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  TextSpan _buildTextSpan() {
    const sajdahGlyph = '\u06E9';
    if (!text.contains(sajdahGlyph)) {
      return TextSpan(text: text, style: style);
    }

    final parts = text.split(sajdahGlyph);
    final children = <InlineSpan>[];
    for (var index = 0; index < parts.length; index++) {
      if (parts[index].isNotEmpty) {
        children.add(TextSpan(text: parts[index], style: style));
      }
      if (index < parts.length - 1) {
        children.add(
          TextSpan(
            text: sajdahGlyph,
            style: TajweedText.sajdahMarkerStyle(
              style,
              color: TajweedRule.sajdah.color,
            ),
          ),
        );
      }
    }
    return TextSpan(children: children);
  }
}

class _MushafBorderMarker extends StatelessWidget {
  final _MushafBoundaryPlacement marker;
  final bool placedOnLeft;

  const _MushafBorderMarker({required this.marker, required this.placedOnLeft});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0B5C45);
    const fill = Color(0xFFDDECE6);
    return Tooltip(
      message: marker.label,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Semantics(
        label: '${marker.semanticLabel}: ${marker.label}',
        child: Container(
          width: 14,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(placedOnLeft ? 0 : 7),
              right: Radius.circular(placedOnLeft ? 7 : 0),
            ),
            border: Border.all(color: accent, width: 0.8),
          ),
          child: Text(
            marker.symbol,
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 11,
              height: 1,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MushafHeaderChip extends StatelessWidget {
  final String text;
  final AlignmentGeometry alignment;
  const _MushafHeaderChip({
    required this.text,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDDECE6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5F9584), width: 1.2),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'UthmanicHafs',
          fontSize: 20,
          color: Color(0xFF0A4B39),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SurahSelector extends StatelessWidget {
  final List<Map<String, dynamic>> surahs;
  final int selected;
  final Map<int, ({int surah, int ayah})> juzStarts;
  final bool Function()? onBeforeOpen;
  final void Function(int surah, {int? ayah}) onChanged;
  const _SurahSelector({
    required this.surahs,
    required this.selected,
    required this.juzStarts,
    this.onBeforeOpen,
    required this.onChanged,
  });

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
    // Reserve room for app bar icons + paddings so title stays balanced.
    final maxTitleWidth = (screenWidth - 220).clamp(96.0, 280.0);

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
        juzStarts: juzStarts,
        onChanged: (surah, {ayah}) {
          onChanged(surah, ayah: ayah);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _SurahPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> surahs;
  final int selected;
  final Map<int, ({int surah, int ayah})> juzStarts;
  final void Function(int surah, {int? ayah}) onChanged;
  const _SurahPickerSheet({
    required this.surahs,
    required this.selected,
    required this.juzStarts,
    required this.onChanged,
  });

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  String _search = '';
  final _listController = ScrollController();

  String _normalizeSearchText(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      switch (ch) {
        case '٠':
        case '۰':
          buffer.write('0');
          break;
        case '١':
        case '۱':
          buffer.write('1');
          break;
        case '٢':
        case '۲':
          buffer.write('2');
          break;
        case '٣':
        case '۳':
          buffer.write('3');
          break;
        case '٤':
        case '۴':
          buffer.write('4');
          break;
        case '٥':
        case '۵':
          buffer.write('5');
          break;
        case '٦':
        case '۶':
          buffer.write('6');
          break;
        case '٧':
        case '۷':
          buffer.write('7');
          break;
        case '٨':
        case '۸':
          buffer.write('8');
          break;
        case '٩':
        case '۹':
          buffer.write('9');
          break;
        default:
          buffer.write(ch);
      }
    }
    return buffer.toString().toLowerCase().trim();
  }

  List<String> _surahSearchableNames(
    Map<String, dynamic> surah,
    String locale,
  ) {
    final translated = surah['translated_name'];
    final translatedName = translated is Map
        ? (translated['name'] as String? ?? '')
        : (translated as String? ?? '');

    final names = <String>[
      if ((surah['name_arabic'] as String?)?.isNotEmpty ?? false)
        surah['name_arabic'] as String,
      if ((translatedName).isNotEmpty) translatedName,
      if ((surah['name_simple'] as String?)?.isNotEmpty ?? false)
        surah['name_simple'] as String,
      if ((surah['name_complex'] as String?)?.isNotEmpty ?? false)
        surah['name_complex'] as String,
    ];

    // Keep locale-preferred names first so typing in current app language
    // feels natural while still allowing cross-language fallback search.
    if (locale == 'ar') {
      names.sort((a, b) {
        final aArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(a);
        final bArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(b);
        if (aArabic == bArabic) return 0;
        return aArabic ? -1 : 1;
      });
    }

    return names;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients) return;
      final idx = widget.surahs.indexWhere(
        (s) => (s['id'] as int? ?? 0) == widget.selected,
      );
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
    if (_searchedJuzNumber != null) return <Map<String, dynamic>>[];
    final locale = Localizations.localeOf(context).languageCode;
    final q = _normalizeSearchText(_search);
    return widget.surahs.where((s) {
      final names = _surahSearchableNames(
        s,
        locale,
      ).map(_normalizeSearchText).where((name) => name.isNotEmpty);
      final num = _normalizeSearchText(s['id'].toString());
      return names.any((name) => name.contains(q)) || num == q;
    }).toList();
  }

  int? get _searchedJuzNumber {
    if (_search.trim().isEmpty) return null;

    // Support localized Juz queries like:
    // - juz2 / j2 / goz2
    // - الجزء2 / الجزء ٢ / جزء2
    // - پارہ2
    final normalized = _normalizeSearchText(_search);
    final compact = normalized.replaceAll(RegExp(r'[\s\-._:/]+'), '');
    final match = RegExp(
      r'^(?:juz|goz|j|cuz|cüz|dschuz|yuz|الجزء|جزء|پارہ|پاره)(\d{1,2})$',
    ).firstMatch(compact);
    if (match == null) return null;

    final juz = int.tryParse(match.group(1)!);
    if (juz == null || juz < 1 || juz > 30) return null;
    return juz;
  }

  Map<String, dynamic>? _surahById(int id) {
    for (final s in widget.surahs) {
      if ((s['id'] as int? ?? 0) == id) return s;
    }
    return null;
  }

  void _jumpToIndex(int startNumber) {
    // Find the index in the full list for that surah number
    final idx = widget.surahs.indexWhere(
      (s) => (s['id'] as int? ?? 0) >= startNumber,
    );
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
    final langCode = Localizations.localeOf(context).languageCode;
    final searchedJuz = _searchedJuzNumber;
    final juzTarget = searchedJuz == null
        ? null
        : widget.juzStarts[searchedJuz];
    final hasJuzQuickResult = searchedJuz != null && juzTarget != null;
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(
                  context,
                ).get('search_surah_or_juz'),
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                    itemCount: surahs.length + (hasJuzQuickResult ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (hasJuzQuickResult && i == 0) {
                        final target = juzTarget!;
                        final targetSurah = _surahById(target.surah);
                        final targetArabic =
                            (targetSurah?['name_arabic'] as String?) ??
                            'سورة ${target.surah}';
                        final targetSimple =
                            (targetSurah?['name_simple'] as String?) ??
                            'Surah ${target.surah}';
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1E7CF),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _ReaderScreenState._localizedDigits(
                                searchedJuz,
                                langCode,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8B6A2E),
                              ),
                            ),
                          ),
                          title: Text(
                            '${AppLocalizations.of(context).get('juz')} ${_ReaderScreenState._localizedDigits(searchedJuz, langCode)} • $targetArabic',
                            style: const TextStyle(
                              fontFamily: 'UthmanicHafs',
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Text(
                            '$targetSimple • Ayah ${target.ayah}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.subdirectory_arrow_left,
                            size: 18,
                            color: Color(0xFF1D9E75),
                          ),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            widget.onChanged(target.surah, ayah: target.ayah);
                          },
                        );
                      }

                      final dataIndex = i - (hasJuzQuickResult ? 1 : 0);
                      final s = surahs[dataIndex];
                      final id = s['id'] as int? ?? i + 1;
                      final isSelected = id == widget.selected;
                      final localizedId = _ReaderScreenState._localizedDigits(
                        id,
                        langCode,
                      );
                      final versesCount = s['verses_count'];
                      final versesText = versesCount is int
                          ? _ReaderScreenState._localizedDigits(
                              versesCount,
                              langCode,
                            )
                          : (versesCount?.toString() ?? '');
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
                          child: Text(
                            localizedId,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF3D3D3A),
                            ),
                          ),
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
                          '${s['name_simple'] ?? '${AppLocalizations.of(context).get('surah')} $localizedId'} • $versesText ${AppLocalizations.of(context).get('verses')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF1D9E75),
                                size: 20,
                              )
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
                          110,
                        ])
                          GestureDetector(
                            onTap: () => _jumpToIndex(n),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                _ReaderScreenState._localizedDigits(
                                  n,
                                  langCode,
                                ),
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
    final juzLabel = AppLocalizations.of(context).get('juz');
    final langCode = Localizations.localeOf(context).languageCode;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6C8),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: const Color(0xFFD4A940).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: Text(
          '$juzLabel ${_ReaderScreenState._localizedDigits(juzNumber, langCode)}',
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
              colors: [Color(0xFFFCF7EB), Color(0xFFF3EBDD), Color(0xFFFFFBF2)],
            ),
            border: Border.all(color: const Color(0xFF4D8674), width: 1.4),
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
                child: CustomPaint(painter: _QuranPagePatternPainter()),
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
      ..color = const Color(0xFFD8CBB5).withValues(alpha: 0.76);
    canvas.drawRect(Rect.fromLTWH(0, 0, 18, size.height), sideFill);
    canvas.drawRect(
      Rect.fromLTWH(size.width - 18, 0, 18, size.height),
      sideFill,
    );

    final motifPaint = Paint()
      ..color = const Color(0xFF176C53).withValues(alpha: 0.64);
    for (double y = 16; y < size.height - 16; y += 20) {
      canvas.drawCircle(const Offset(9, 0) + Offset(0, y), 3.0, motifPaint);
      canvas.drawCircle(Offset(size.width - 9, y), 3.0, motifPaint);
    }

    final frame = Paint()
      ..color = const Color(0xFF3C7965).withValues(alpha: 0.84)
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
      ..color = const Color(0xFF9D8D70).withValues(alpha: 0.58)
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
  final bool showArabic;
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
  final Future<void> Function(Ayah, Rect) onShareTap;

  const _AyahTile({
    required this.ayah,
    required this.tajweedEnabled,
    required this.showArabic,
    required this.showTranslation,
    required this.langCode,
    required this.isPlaying,
    required this.activeWordIndex,
    required this.isBookmarked,
    required this.onWordTapped,
    required this.onDoubleTap,
    required this.onTafseerTap,
    required this.onBookmarkTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final readerStrings = _ReaderStrings.of(context);
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onBookmarkTap,
      behavior: HitTestBehavior.opaque,
      // Increase double-tap detection window
      excludeFromSemantics: false,
      child: Container(
        color: isPlaying
            ? const Color(0xFF1D9E75).withValues(alpha: 0.08)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _AyahNumber(number: ayah.ayahNumber),
                const Spacer(),
                Builder(
                  builder: (shareContext) => IconButton(
                    icon: const Icon(CupertinoIcons.share, size: 22),
                    color: const Color(0xFF1D9E75),
                    tooltip: MaterialLocalizations.of(context).shareButtonLabel,
                    onPressed: () {
                      final box = shareContext.findRenderObject() as RenderBox?;
                      final origin = box == null
                          ? Rect.zero
                          : box.localToGlobal(Offset.zero) & box.size;
                      onShareTap(ayah, origin);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                // Tafseer button
                IconButton(
                  icon: const Icon(Icons.lightbulb, size: 23),
                  color: const Color(0xFF1D9E75),
                  tooltip: readerStrings.text('tafseer'),
                  onPressed: onTafseerTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                // Bookmark indicator
                if (isBookmarked)
                  const Icon(
                    Icons.bookmark,
                    size: 18,
                    color: Color(0xFFB8860B),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (showArabic)
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
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w500,
                  fontSize:
                      (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) +
                      6,
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

class _BasmalaOpener extends StatelessWidget {
  static const String _bismillah = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

  final String surahName;
  final bool showBasmala;

  const _BasmalaOpener({required this.surahName, required this.showBasmala});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF8E8), Color(0xFFF5E6C8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD4A940), width: 0.8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                surahName,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF8B6B2A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showBasmala) ...[
                const SizedBox(height: 10),
                const Text(
                  _bismillah,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 28,
                    height: 1.8,
                    color: Color(0xFF3F3122),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderStrings {
  final String _languageCode;

  const _ReaderStrings._(this._languageCode);

  factory _ReaderStrings.of(BuildContext context) {
    return _ReaderStrings._(Localizations.localeOf(context).languageCode);
  }

  static const Map<String, Map<String, String>> _localized = {
    'en': {
      'tafseer': 'Tafseer',
      'downloading_tafseer': 'Downloading tafseer',
      'surah_tafseer_status': 'Surah {surah} · Tafseer ID {id}',
      'downloaded_of_ayahs': 'Downloaded {done} of {total} ayahs',
      'no_verses_for_surah': 'No verses returned for this surah.',
      'surah_tafseer_downloaded': 'Surah {surah} tafseer downloaded.',
      'tafseer_download_failed': 'Tafseer download failed: {error}',
    },
    'ar': {
      'tafseer': 'التفسير',
      'downloading_tafseer': 'جارٍ تنزيل التفسير',
      'surah_tafseer_status': 'سورة {surah} · معرف التفسير {id}',
      'downloaded_of_ayahs': 'تم تنزيل {done} من {total} آيات',
      'no_verses_for_surah': 'لم يتم إرجاع آيات لهذه السورة.',
      'surah_tafseer_downloaded': 'تم تنزيل تفسير السورة {surah}.',
      'tafseer_download_failed': 'فشل تنزيل التفسير: {error}',
    },
    'ur': {
      'tafseer': 'تفسیر',
      'downloading_tafseer': 'تفسیر ڈاؤن لوڈ ہو رہی ہے',
      'surah_tafseer_status': 'سورہ {surah} · تفسیر آئی ڈی {id}',
      'downloaded_of_ayahs': '{total} میں سے {done} آیات ڈاؤن لوڈ ہوئیں',
      'no_verses_for_surah': 'اس سورہ کے لیے کوئی آیات واپس نہیں آئیں۔',
      'surah_tafseer_downloaded': 'سورہ {surah} کی تفسیر ڈاؤن لوڈ ہو گئی۔',
      'tafseer_download_failed': 'تفسیر ڈاؤن لوڈ ناکام: {error}',
    },
    'tr': {
      'tafseer': 'Tefsir',
      'downloading_tafseer': 'Tefsir indiriliyor',
      'surah_tafseer_status': 'Sure {surah} · Tefsir kimliği {id}',
      'downloaded_of_ayahs': '{total} ayetin {done} tanesi indirildi',
      'no_verses_for_surah': 'Bu sure için ayet döndürülmedi.',
      'surah_tafseer_downloaded': '{surah}. sure için tefsir indirildi.',
      'tafseer_download_failed': 'Tefsir indirme başarısız: {error}',
    },
    'fr': {
      'tafseer': 'Tafsir',
      'downloading_tafseer': 'Téléchargement du tafsir',
      'surah_tafseer_status': 'Sourate {surah} · ID du tafsir {id}',
      'downloaded_of_ayahs': '{done} ayats téléchargées sur {total}',
      'no_verses_for_surah': 'Aucun verset renvoyé pour cette sourate.',
      'surah_tafseer_downloaded': 'Tafsir de la sourate {surah} téléchargé.',
      'tafseer_download_failed': 'Échec du téléchargement du tafsir : {error}',
    },
    'id': {
      'tafseer': 'Tafsir',
      'downloading_tafseer': 'Mengunduh tafsir',
      'surah_tafseer_status': 'Surah {surah} · ID tafsir {id}',
      'downloaded_of_ayahs': 'Mengunduh {done} dari {total} ayat',
      'no_verses_for_surah':
          'Tidak ada ayat yang dikembalikan untuk surah ini.',
      'surah_tafseer_downloaded':
          'Tafsir untuk surah {surah} berhasil diunduh.',
      'tafseer_download_failed': 'Gagal mengunduh tafsir: {error}',
    },
    'de': {
      'tafseer': 'Tafsir',
      'downloading_tafseer': 'Tafsir wird heruntergeladen',
      'surah_tafseer_status': 'Sura {surah} · Tafsir-ID {id}',
      'downloaded_of_ayahs': '{done} von {total} Ayat heruntergeladen',
      'no_verses_for_surah': 'Für diese Sura wurden keine Verse zurückgegeben.',
      'surah_tafseer_downloaded': 'Tafsir für Sura {surah} heruntergeladen.',
      'tafseer_download_failed':
          'Herunterladen des Tafsir fehlgeschlagen: {error}',
    },
    'es': {
      'tafseer': 'Tafsir',
      'downloading_tafseer': 'Descargando tafsir',
      'surah_tafseer_status': 'Sura {surah} · ID de tafsir {id}',
      'downloaded_of_ayahs': '{done} de {total} ayat descargadas',
      'no_verses_for_surah': 'No se devolvieron versículos para esta sura.',
      'surah_tafseer_downloaded': 'Se descargó el tafsir de la sura {surah}.',
      'tafseer_download_failed': 'Error al descargar el tafsir: {error}',
    },
  };

  String text(String key, [Map<String, String> replacements = const {}]) {
    var value =
        _localized[_languageCode]?[key] ?? _localized['en']![key] ?? key;
    replacements.forEach((placeholder, replacement) {
      value = value.replaceAll('{$placeholder}', replacement);
    });
    return value;
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
          color: Color(0xFFB8860B),
        ),
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
    final l10n = AppLocalizations.of(context);
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_rounded,
                  color: Color(0xFFB8860B),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.get('bookmarks'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5),
          Expanded(
            child: bookmarks.isEmpty
                ? Center(
                    child: Text(
                      l10n.get('bookmarks_empty_hint'),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0.5, indent: 16),
                    itemBuilder: (_, i) {
                      final bm = bookmarks[i];
                      final langCode = Localizations.localeOf(
                        context,
                      ).languageCode;
                      final previousType = i > 0 ? bookmarks[i - 1].type : null;
                      final showHeader = i == 0 || previousType != bm.type;
                      final localizedPageNumber = bm.pageNumber == null
                          ? '-'
                          : _ReaderScreenState._localizedDigits(
                              bm.pageNumber!,
                              langCode,
                            );
                      final localizedSurah =
                          _ReaderScreenState._localizedDigits(
                            bm.surah,
                            langCode,
                          );
                      final localizedAyah = _ReaderScreenState._localizedDigits(
                        bm.ayah,
                        langCode,
                      );
                      final leadingText = bm.isPage
                          ? 'P$localizedPageNumber'
                          : '$localizedSurah:$localizedAyah';
                      final subtitleText = bm.isPage
                          ? '${l10n.get('page')} $localizedPageNumber • ${l10n.get('surah')} $localizedSurah'
                          : '${l10n.get('surah')} $localizedSurah • ${l10n.get('ayah')} $localizedAyah';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                bm.isPage
                                    ? l10n.get('page_bookmarks')
                                    : l10n.get('ayah_bookmarks'),
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
                              child: Text(
                                leadingText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFB8860B),
                                ),
                              ),
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
          const Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: Color(0xFF888780),
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load verses',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
