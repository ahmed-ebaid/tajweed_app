import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/models/tajweed_models.dart';
import '../../core/providers/bookmark_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/recitation_provider.dart';
import '../../core/providers/tafseer_provider.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/audio_cache_service.dart';
import '../../core/services/ayah_mapper.dart';
import '../../core/services/quran_api_service.dart';
import '../reader/widgets/audio_player_bar.dart';
import '../reader/widgets/tajweed_text.dart';
import '../reader/widgets/tafseer_sheet.dart';
import '../reader/widgets/word_detail_sheet.dart';
import '../settings/settings_screen.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

enum _ReaderViewMode { page, ayah }

class _ReaderScreenState extends State<ReaderScreen> {
  static const String _readerViewModeKey = 'reader_view_mode';
  static const String _mushafAssetsDir = 'assets/mushaf_pages/tajweed';

  final _api = QuranApiService();
  final _audio = AudioService();
  final _audioCache = AudioCacheService();
  final _scrollController = ScrollController();
  final PageController _mushafPageController = PageController();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;

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
  int _currentMushafPageIndex = 0;
  int? _ayahModeAnchorAyah;
  int? _mushafAnchorSurah;
  double? _ayahModeReturnOffset;
  final Map<int, _MushafPageAnchor> _mushafPageAnchorCache = {};

  // Juz boundaries: ayahNumber → juz number (only for first ayah of each juz in this surah)
  Map<int, int> _juzBoundaries = {};

  // Target scroll offset to restore after loading a surah
  double _pendingScrollOffset = 0.0;

  // Flag to avoid saving scroll position while automatic jump is in progress
  bool _isProgrammaticScroll = false;

  // GlobalKeys for scrolling to specific ayahs
  final Map<int, GlobalKey> _ayahKeys = {};

  @override
  void initState() {
    super.initState();
    _lockPortraitForReader();

    _loadSavedReaderViewMode();

    // Restore last read position
    final bookmarks = context.read<BookmarkProvider>();
    _selectedSurah = bookmarks.lastReadSurah;
    _ayahModeAnchorAyah = bookmarks.lastReadAyah;
    print('📱 initState: restored surah=$_selectedSurah, lastReadAyah=${bookmarks.lastReadAyah}');

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

      final ayahIdx = _ayahs.indexWhere((a) => a.ayahNumber == _playingAyahNumber);
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
      _scrollSaveTimer = Timer(const Duration(milliseconds: 500), _saveScrollPosition);
    });
  }

  void _loadSavedReaderViewMode() {
    try {
      final box = Hive.box('settings');
      final saved = box.get(_readerViewModeKey, defaultValue: _ReaderViewMode.ayah.name) as String;
      _viewMode = saved == _ReaderViewMode.page.name
          ? _ReaderViewMode.page
          : _ReaderViewMode.ayah;
    } catch (_) {
      _viewMode = _ReaderViewMode.ayah;
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

  void _saveScrollPosition() {
    try {
      if (_ayahs.isEmpty || !mounted) return;

      if (_viewMode == _ReaderViewMode.page) {
        final anchorSurah = _currentMushafAnchorSurah();
        final anchorAyah = _currentMushafAnchorAyah();
        context.read<BookmarkProvider>().saveLastRead(
              anchorSurah,
              anchorAyah,
            );
        return;
      }

      int? topVisibleAyah;
      double bestDistance = double.infinity;
      final screenHeight = MediaQuery.of(context).size.height;

      for (final ayah in _ayahs) {
        final key = _ayahKeys[ayah.ayahNumber];
        if (key?.currentContext == null) continue;

        try {
          final renderObject = key!.currentContext!.findRenderObject();
          if (renderObject is! RenderBox) continue;
          final renderBox = renderObject;
          if (!renderBox.hasSize) continue;

          final offset = renderBox.localToGlobal(Offset.zero).dy;
          final distance = (offset - 0).abs();

          if (distance < bestDistance && offset < screenHeight * 0.8) {
            bestDistance = distance;
            topVisibleAyah = ayah.ayahNumber;
          }
        } catch (e) {
          print('⚠️ Error processing ayah ${ayah.ayahNumber} in scroll save: $e');
          continue;
        }
      }

      if (topVisibleAyah == null && _playingAyahNumber != null) {
        topVisibleAyah = _playingAyahNumber;
      }

      if (_isProgrammaticScroll) {
        // Ignore automatic jump positions until the final scroll settle.
        return;
      }

      if (topVisibleAyah != null && mounted) {
        try {
          final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
          context.read<BookmarkProvider>().saveLastRead(_selectedSurah, topVisibleAyah, scrollOffset: scrollOffset);
          print('✅ Saved scroll position: surah=$_selectedSurah, ayah=$topVisibleAyah, offset=$scrollOffset');
        } catch (e) {
          print('❌ Error saving to BookmarkProvider: $e');
        }
      }
    } catch (e) {
      print('❌ Error in _saveScrollPosition: $e');
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
    // Save position one final time before closing
    _saveScrollPosition();
    _restoreAppOrientations();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _mushafPageController.dispose();
    _audio.dispose();
    _scrollController.dispose();
    super.dispose();
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
    setState(() { _loading = true; _ayahs = []; _audioUrls = {}; _juzBoundaries = {}; });
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final reciterId = context.read<RecitationProvider>().selectedReciterId;
    _lastObservedReciterId = reciterId;

    try {
      final allVerses = <Map<String, dynamic>>[];
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

      final results = await Future.wait([
        _api.fetchAudioFiles(reciterId: reciterId, surahNumber: _selectedSurah),
        _api.fetchTajweedText(chapterNumber: _selectedSurah),
        _loadJuzBoundaries(),
      ]);
      final audioMap = results[0] as Map<String, String>;
      final tajweedMap = results[1] as Map<String, String>;

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
    final currentOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
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
        final mapping = j['verse_mapping'] as Map<String, dynamic>? ?? {};
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
    try {
      final bookmarks = context.read<BookmarkProvider>();
      if (bookmarks.lastReadSurah != _selectedSurah || _ayahs.isEmpty) {
        print('⚠️ Not scrolling: mismatch/empty (lastReadSurah=${bookmarks.lastReadSurah}, _selectedSurah=$_selectedSurah, count=${_ayahs.length})');
        return;
      }

      final lastAyah = bookmarks.lastReadAyah;
      final savedOffset = bookmarks.lastScrollOffset;
      print('🎯 _scrollToLastReadAyah using ayah=$lastAyah and offset=$savedOffset in surah $_selectedSurah');

      if (_restoreAyahByNumber(lastAyah, retries: 10)) {
        return;
      }

      if (savedOffset > 0) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted && _viewMode == _ReaderViewMode.ayah) {
            _restoreScrollOffset(savedOffset);
          }
        });
      }
    } catch (e) {
      print('❌ Error in _scrollToLastReadAyah: $e');
    }
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
      _restoreMushafPageForLastRead();
      return;
    }

    if (_pendingScrollOffset > 0) {
      _restoreScrollOffset(_pendingScrollOffset);
      _pendingScrollOffset = 0.0;
    } else {
      _scrollToLastReadAyah();
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
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mushafPageController.hasClients) return;
      _mushafPageController.jumpToPage(pageIndex);
      unawaited(_updateMushafAnchorForPage(targetPage));
    });
  }

  void _restoreScrollOffset(double offset) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollOffset(offset);
      });
      return;
    }

    // Clamp offset to valid range
    final validOffset = offset.clamp(0.0, _scrollController.position.maxScrollExtent);
    _isProgrammaticScroll = true;
    
    print('🔄 Restoring scroll to offset=$validOffset');
    _scrollController.jumpTo(validOffset);
    
    // Save the position
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        try {
          final bookmarks = context.read<BookmarkProvider>();
          context.read<BookmarkProvider>().saveLastRead(_selectedSurah, bookmarks.lastReadAyah, scrollOffset: validOffset);
          print('✅ Restored scroll position at offset=$validOffset');
        } catch (e) {
          print('❌ Error saving during restore: $e');
        }
      }
      _isProgrammaticScroll = false;
    });
  }

  // ─── Audio Controls ───────────────────────────────────────────────────────

  /// Double-tap on a single ayah — play just that one.
  void _playSingleAyah(Ayah ayah) {
    print('🔢 DOUBLE TAP: ayah ${ayah.ayahNumber}');
    context.read<BookmarkProvider>().saveLastRead(ayah.surahNumber, ayah.ayahNumber);

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
  void _togglePlayAll() {
    if (_isPlayingAll) {
      _audio.stop();
      setState(() {
        _isPlayingAll = false;
        _playingAyahNumber = null;
        _activeWordIndex = -1;
      });
    } else if (_ayahs.isNotEmpty) {
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
      context.read<BookmarkProvider>().saveLastRead(ayah.surahNumber, ayah.ayahNumber);

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
    final giveFromMap = _audioUrls[verseKey];
    final fallbackUrl = _api.audioUrl(
      reciterId: reciterId,
      surahNumber: ayah.surahNumber,
      ayahNumber: ayah.ayahNumber,
    );
    final rawUrl = giveFromMap ?? ayah.audioUrl ?? fallbackUrl;
    final url = rawUrl.startsWith('http') ? rawUrl : 'https://verses.quran.com/$rawUrl';

    print('🎵 PLAY AYAH: verseKey=$verseKey, mapHas=${giveFromMap != null}, raw=$rawUrl, url=$url');

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
    try {
      final localPath = await _audioCache.getCachedAyahPath(
        reciterId: reciterId,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
      );

      if (localPath != null && File(localPath).existsSync()) {
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
            content: Text('Error playing audio: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    // Update last read position
    try {
      context.read<BookmarkProvider>().saveLastRead(ayah.surahNumber, ayah.ayahNumber);
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

  Future<bool> _waitForCurrentAyahCompletion() async {
    if (!_isPlayingAll) return false;

    final completer = Completer<bool>();
    late StreamSubscription<PlayerState> sub;
    late final Timer stopPoll;

    sub = _audio.playerStateStream.listen((state) {
      if (!completer.isCompleted && _isPlayingAll && state.processingState == ProcessingState.completed) {
        completer.complete(true);
      }

      if (!completer.isCompleted && state.processingState == ProcessingState.idle) {
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
          const SnackBar(content: Text('Bookmark removed'), duration: Duration(seconds: 1)),
        );
      }
    } else {
      // Find surah name for label
      String label = '${ayah.surahNumber}:${ayah.ayahNumber}';
      for (final s in _allSurahs) {
        if (s['id'] == ayah.surahNumber) {
          label = '${s['name_arabic'] ?? s['name_simple']} — Ayah ${ayah.ayahNumber}';
          break;
        }
      }
      final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
      bm.addBookmark(ayah.surahNumber, ayah.ayahNumber, label: label, scrollOffset: scrollOffset);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmark added'), duration: Duration(seconds: 1)),
        );
      }
    }
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
        bookmarks: bm.bookmarks,
        onTap: (bookmark) {
          Navigator.pop(context);
          if (_selectedSurah == bookmark.surah) {
            // Same surah: direct scroll without full reload
            _isProgrammaticScroll = true;
            _restoreScrollOffset(bookmark.scrollOffset);
            context.read<BookmarkProvider>().saveLastRead(bookmark.surah, bookmark.ayah, scrollOffset: bookmark.scrollOffset);
            return;
          }

          // Different surah: load it then restore offset
          setState(() {
            _selectedSurah = bookmark.surah;
            _pendingScrollOffset = bookmark.scrollOffset;
          });
          _loadSurah();
        },
        onDelete: (bookmark) {
          bm.removeBookmark(bookmark.surah, bookmark.ayah);
          // Rebuild the sheet content
          Navigator.pop(context);
          _showBookmarksList();
        },
      ),
    );
  }

  void _onWordTapped(TajweedRule rule, String word) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => WordDetailSheet(rule: rule, word: word),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final selectedReciterId = context.watch<RecitationProvider>().selectedReciterId;

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
              onChanged: (v) { _selectedSurah = v; _stopAudio(); _loadSurah(); },
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
              _isPlayingAll ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              size: 22,
            ),
            color: _isPlayingAll ? Colors.red : const Color(0xFF1D9E75),
            tooltip: _isPlayingAll ? 'Stop' : 'Play All',
            onPressed: _ayahs.isNotEmpty ? _togglePlayAll : null,
          ),
          IconButton(
            icon: Icon(_tajweedEnabled ? Icons.palette : Icons.palette_outlined),
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
              label: '$_selectedSurah:$_playingAyahNumber${_isPlayingAll ? ' (All)' : ''}',
              onClose: _stopAudio,
            ),
        ],
      ),
    );
  }

  Widget _buildAyahList(String langCode, {required bool pageMode}) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: pageMode ? 12 : 8),
      itemCount: _ayahs.length,
      itemBuilder: (context, i) {
        final ayah = _ayahs[i];
        final juzNumber = _juzBoundaries[ayah.ayahNumber];
        final isPlaying = _playingAyahNumber == ayah.ayahNumber;
        final isBookmarked = context.watch<BookmarkProvider>()
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
    );
  }

  void _toggleReaderViewMode() {
    if (_viewMode == _ReaderViewMode.ayah) {
      final ayahOffset = _scrollController.hasClients
          ? _scrollController.offset
          : context.read<BookmarkProvider>().lastScrollOffset;
      final anchorAyah = _findTopVisibleAyahNumber() ??
          context.read<BookmarkProvider>().lastReadAyah;
      _ayahModeAnchorAyah = anchorAyah;
      _mushafAnchorSurah = _selectedSurah;
      _ayahModeReturnOffset = ayahOffset;
      context.read<BookmarkProvider>().saveLastRead(
            _selectedSurah,
            anchorAyah,
            scrollOffset: ayahOffset,
          );
      final targetPageIndex = _pageNumberForAyah(anchorAyah) - 1;

      setState(() {
        _viewMode = _ReaderViewMode.page;
        _currentMushafPageIndex = targetPageIndex;
      });
      _persistReaderViewMode(_ReaderViewMode.page);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mushafPageController.hasClients) return;
        _mushafPageController.jumpToPage(targetPageIndex);
        unawaited(_updateMushafAnchorForPage(targetPageIndex + 1));
      });
      return;
    }

    _goToAnchoredAyah();
  }

  void _goToAnchoredAyah() {
    final anchorAyah = _ayahModeAnchorAyah ??
        context.read<BookmarkProvider>().lastReadAyah;
    final anchorSurah = _mushafAnchorSurah ?? _selectedSurah;
    final rawOffset = _ayahModeReturnOffset ??
        context.read<BookmarkProvider>().lastScrollOffset;
    final shouldReloadSurah = anchorSurah != _selectedSurah;
    final targetOffset = shouldReloadSurah ? 0.0 : rawOffset;

    // Persist anchor and offset before switching back to ayah mode.
    context.read<BookmarkProvider>().saveLastRead(
          anchorSurah,
          anchorAyah,
          scrollOffset: targetOffset,
        );

    setState(() {
      _viewMode = _ReaderViewMode.ayah;
      if (shouldReloadSurah) {
        _selectedSurah = anchorSurah;
      }
    });
    _persistReaderViewMode(_ReaderViewMode.ayah);

    if (shouldReloadSurah) {
      _loadSurah();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (targetOffset > 0) {
        _restoreScrollOffset(targetOffset);
      } else {
        _restoreAyahByNumber(anchorAyah, retries: 12);
      }

      // Extra safety: if list build takes longer, try again shortly.
      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted || _viewMode != _ReaderViewMode.ayah) return;
        if (targetOffset > 0) {
          _restoreScrollOffset(targetOffset);
        } else {
          _restoreAyahByNumber(anchorAyah, retries: 6);
        }
      });
    });
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
    return _mushafPageAnchorCache[pageNumber]?.ayah ?? _ayahModeAnchorAyah ?? 1;
  }

  int _currentMushafAnchorSurah() {
    final pageNumber = _currentMushafPageIndex + 1;
    return _mushafPageAnchorCache[pageNumber]?.surah ?? _mushafAnchorSurah ?? _selectedSurah;
  }

  int _pageNumberForAyah(int ayahNumber) {
    if (_ayahs.isEmpty) return (_currentMushafPageIndex + 1).clamp(1, 604);
    final idx = _ayahs.indexWhere((a) => a.ayahNumber == ayahNumber);
    if (idx < 0) return _ayahs.first.pageNumber;
    return _ayahs[idx].pageNumber;
  }

  Future<void> _updateMushafAnchorForPage(int pageNumber) async {
    if (!mounted) return;
    final cached = _mushafPageAnchorCache[pageNumber];
    // Always refetch multi-surah pages to ensure correct surah selection
    if (cached != null && pageNumber != 1 && pageNumber != 2) {
      setState(() {
        _mushafAnchorSurah = cached.surah;
        _ayahModeAnchorAyah = cached.ayah;
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
      
      // For pages spanning multiple surahs, use the highest surah number 
      // (the surah that dominates the page content).
      int? maxSurah;
      String? anchorVerseKey;
      for (final verse in verses) {
        final verseKey = verse['verse_key'] as String? ?? '';
        final parts = verseKey.split(':');
        if (parts.length != 2) continue;
        
        final surah = int.tryParse(parts.first);
        if (surah == null) continue;
        
        if (maxSurah == null || surah > maxSurah) {
          maxSurah = surah;
          anchorVerseKey = verseKey;
        }
      }
      
      if (maxSurah == null || anchorVerseKey == null) return;
      
      final parts = anchorVerseKey.split(':');
      final ayah = int.tryParse(parts.last);
      if (ayah == null) return;

      final anchor = _MushafPageAnchor(
        pageNumber: pageNumber,
        surah: maxSurah,
        ayah: ayah,
      );

      _mushafPageAnchorCache[pageNumber] = anchor;
      if (!mounted) return;
      setState(() {
        _mushafAnchorSurah = maxSurah!;
        _ayahModeAnchorAyah = ayah;
        if (_viewMode == _ReaderViewMode.page) {
          // Keep the top selector in sync while swiping Mushaf pages.
          _selectedSurah = maxSurah;
        }
      });
    } catch (_) {
      // Ignore per-page metadata failure; image page remains readable.
    }
  }

  String _mushafPageAsset(int pageNumber) {
    final safePage = pageNumber.clamp(1, 604);
    return '$_mushafAssetsDir/$safePage.png';
  }

  Widget _buildMushafPageView() {
    return PageView.builder(
      controller: _mushafPageController,
      itemCount: 604,
      onPageChanged: (index) {
        final pageNumber = index + 1;
        setState(() {
          _currentMushafPageIndex = index;
        });

        unawaited(_updateMushafAnchorForPage(pageNumber));

        final anchorSurah = _currentMushafAnchorSurah();
        final anchorAyah = _currentMushafAnchorAyah();
        context.read<BookmarkProvider>().saveLastRead(anchorSurah, anchorAyah);
      },
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final pageAsset = _mushafPageAsset(pageNumber);
        final pageSurah = _mushafPageAnchorCache[pageNumber]?.surah ?? _selectedSurah;
        final surahName = _surahArabicName(pageSurah);

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
                        child: _MushafHeaderChip(text: 'الصفحة $pageNumber'),
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
                      border: Border.all(color: const Color(0xFF8E7C58), width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                      child: Image.asset(
                              pageAsset,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                              alignment: Alignment.center,
                              isAntiAlias: false,
                              errorBuilder: (_, __, ___) => _MissingLocalMushafPage(
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
          const Icon(Icons.image_not_supported_outlined, size: 28, color: Color(0xFF7D6E52)),
          const SizedBox(height: 8),
          const Text(
            'Bundled page image not found',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5A4B2E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Expected asset: $pageNumber.png',
            style: const TextStyle(fontSize: 11, color: Color(0xFF7E7158)),
          ),
        ],
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
  final void Function(int) onChanged;
  const _SurahSelector({required this.surahs, required this.selected, required this.onChanged});

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
      onTap: () => _showSurahPicker(context),
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
  const _SurahPickerSheet({required this.surahs, required this.selected, required this.onChanged});

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  String _search = '';
  final _listController = ScrollController();

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
    final idx = widget.surahs.indexWhere((s) => (s['id'] as int? ?? 0) >= startNumber);
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
    final showIndex = _search.isEmpty; // only show jump index when not searching

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
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
                          width: 36, height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1D9E75) : const Color(0xFFF5F5F5),
                            shape: BoxShape.circle,
                          ),
                          child: Text('$id',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF3D3D3A),
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
                            ? const Icon(Icons.check_circle, color: Color(0xFF1D9E75), size: 20)
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
                        for (final n in [1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110])
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
          horizontal: BorderSide(color: const Color(0xFFD4A940).withValues(alpha: 0.5), width: 0.5),
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
    final sideFill = Paint()..color = const Color(0xFFDFC39A).withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, 18, size.height), sideFill);
    canvas.drawRect(Rect.fromLTWH(size.width - 18, 0, 18, size.height), sideFill);

    final motifPaint = Paint()..color = const Color(0xFF8B6A2E).withValues(alpha: 0.55);
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
  final void Function(TajweedRule, String) onWordTapped;
  final VoidCallback onDoubleTap;
  final VoidCallback onTafseerTap;
  final VoidCallback onBookmarkTap;

  const _AyahTile({
    required this.ayah, required this.tajweedEnabled,
    required this.showTranslation, required this.langCode,
    required this.isPlaying, required this.activeWordIndex, required this.isBookmarked,
    required this.onWordTapped, required this.onDoubleTap,
    required this.onTafseerTap, required this.onBookmarkTap,
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
        color: isPlaying ? const Color(0xFF1D9E75).withValues(alpha: 0.08) : null,
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
                  const Icon(Icons.bookmark, size: 18, color: Color(0xFFB8860B)),
              ],
            ),
            const SizedBox(height: 8),
            TajweedText(
              ayah: ayah,
              fontSize: 28,
              highlightEnabled: tajweedEnabled,
              highlightedWordIndex: activeWordIndex,
              onRuleTapped: onWordTapped,
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
  final void Function(TajweedRule, String) onWordTapped;
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
          color: isPlaying ? const Color(0xFF1D9E75).withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
        child: TajweedText(
          ayah: ayah,
          fontSize: mushafFontSize,
          lineHeight: 1.72,
          compactFlow: true,
          highlightEnabled: tajweedEnabled,
          highlightedWordIndex: activeWordIndex,
          onRuleTapped: onWordTapped,
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
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6C8),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD4A940), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFB8860B)),
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
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bookmark_rounded, color: Color(0xFFB8860B), size: 22),
                const SizedBox(width: 8),
                Text('Bookmarks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 0.5),
          Expanded(
            child: bookmarks.isEmpty
                ? const Center(
                    child: Text('No bookmarks yet.\nLong-press an ayah to bookmark it.',
                        textAlign: TextAlign.center))
                : ListView.separated(
                    controller: controller,
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 16),
                    itemBuilder: (_, i) {
                      final bm = bookmarks[i];
                      return ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5E6C8),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${bm.surah}:${bm.ayah}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                                color: Color(0xFFB8860B))),
                        ),
                        title: Text(bm.label ?? '${bm.surah}:${bm.ayah}'),
                        subtitle: Text(
                          _formatDate(bm.timestamp),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => onDelete(bm),
                        ),
                        onTap: () => onTap(bm),
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
          const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFF888780)),
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
