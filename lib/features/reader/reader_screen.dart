import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/models/tajweed_models.dart';
import '../../core/providers/bookmark_provider.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/recitation_provider.dart';
import '../../core/providers/tafseer_provider.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/ayah_mapper.dart';
import '../../core/services/quran_api_service.dart';
import '../reader/widgets/audio_player_bar.dart';
import '../reader/widgets/tajweed_text.dart';
import '../reader/widgets/tafseer_sheet.dart';
import '../reader/widgets/word_detail_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _api = QuranApiService();
  final _audio = AudioService();
  final _scrollController = ScrollController();

  int _selectedSurah = 1;
  bool _tajweedEnabled = true;
  bool _showTranslation = true;
  List<Ayah> _ayahs = [];
  bool _loading = true;
  List<Map<String, dynamic>> _allSurahs = [];
  Map<String, String> _audioUrls = {};

  // Audio state
  bool _isPlayingAll = false;
  int? _playingAyahNumber;
  int _currentPlayIndex = 0;

  // Juz boundaries: ayahNumber → juz number (only for first ayah of each juz in this surah)
  Map<int, int> _juzBoundaries = {};

  // GlobalKeys for scrolling to specific ayahs
  final Map<int, GlobalKey> _ayahKeys = {};

  @override
  void initState() {
    super.initState();

    // Restore last read position
    final bookmarks = context.read<BookmarkProvider>();
    _selectedSurah = bookmarks.lastReadSurah;

    _initData();

    _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_isPlayingAll && mounted) {
          _playNextAyah();
        } else {
          if (mounted) setState(() { _playingAyahNumber = null; });
        }
      }
    });
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
    _audio.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSurah() async {
    setState(() { _loading = true; _ayahs = []; _audioUrls = {}; _juzBoundaries = {}; });
    final langCode = context.read<LocaleProvider>().locale.languageCode;
    final reciterId = context.read<RecitationProvider>().selectedReciterId;

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

      if (mounted) {
        setState(() {
          _loading = false;
          _ayahs = AyahMapper.fromApiList(allVerses, tajweedMap: tajweedMap);
          _audioUrls = audioMap;
          _ayahKeys.clear();
          for (final a in _ayahs) {
            _ayahKeys[a.ayahNumber] = GlobalKey();
          }
        });
        _scrollToLastReadAyah();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    final bookmarks = context.read<BookmarkProvider>();
    if (bookmarks.lastReadSurah == _selectedSurah && bookmarks.lastReadAyah > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _ayahKeys[bookmarks.lastReadAyah];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  // ─── Audio Controls ───────────────────────────────────────────────────────

  /// Double-tap on a single ayah — play just that one.
  void _playSingleAyah(Ayah ayah) {
    if (_playingAyahNumber == ayah.ayahNumber) {
      _audio.pause();
      setState(() { _playingAyahNumber = null; _isPlayingAll = false; });
    } else {
      _isPlayingAll = false;
      _playAyah(ayah);
    }
  }

  /// Play all ayahs sequentially from the first (or resume from current).
  void _togglePlayAll() {
    if (_isPlayingAll) {
      _audio.pause();
      setState(() { _isPlayingAll = false; _playingAyahNumber = null; });
    } else if (_ayahs.isNotEmpty) {
      _isPlayingAll = true;
      _currentPlayIndex = 0;
      _playAyah(_ayahs[_currentPlayIndex]);
    }
  }

  void _playAyah(Ayah ayah) {
    final verseKey = '${ayah.surahNumber}:${ayah.ayahNumber}';
    final url = _audioUrls[verseKey] ?? ayah.audioUrl ?? '';
    debugPrint('Playing ayah: $verseKey, URL: $url');
    if (url.isNotEmpty) {
      try {
        _audio.playUrl(url);
      } catch (e) {
        debugPrint('Error playing URL for $verseKey: $e');
      }
    } else {
      debugPrint('URL is empty for $verseKey');
    }
    setState(() { _playingAyahNumber = ayah.ayahNumber; });

    // Update last read position
    context.read<BookmarkProvider>().saveLastRead(ayah.surahNumber, ayah.ayahNumber);

    // Scroll to currently playing ayah
    final key = _ayahKeys[ayah.ayahNumber];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  void _playNextAyah() {
    _currentPlayIndex++;
    if (_currentPlayIndex < _ayahs.length) {
      _playAyah(_ayahs[_currentPlayIndex]);
    } else {
      // Reached end
      setState(() { _isPlayingAll = false; _playingAyahNumber = null; });
    }
  }

  void _stopAudio() {
    _audio.stop();
    setState(() { _isPlayingAll = false; _playingAyahNumber = null; });
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
      bm.addBookmark(ayah.surahNumber, ayah.ayahNumber, label: label);
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
          setState(() => _selectedSurah = bookmark.surah);
          // Save so we scroll to the right ayah after load
          context.read<BookmarkProvider>().saveLastRead(bookmark.surah, bookmark.ayah);
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
    final l10n = AppLocalizations.of(context);
    final langCode = context.read<LocaleProvider>().locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: _SurahSelector(
          surahs: _allSurahs,
          selected: _selectedSurah,
          onChanged: (v) { _selectedSurah = v; _stopAudio(); _loadSurah(); },
        ),
        actions: [
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
            icon: Icon(_showTranslation ? Icons.translate : Icons.translate_outlined),
            tooltip: l10n.get('translation'),
            onPressed: () => setState(() => _showTranslation = !_showTranslation),
          ),
        ],
      ),
      body: Column(
        children: [
          TajweedLegend(
            rules: TajweedRule.values,
            langCode: langCode,
          ),
          const Divider(height: 0.5),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _ayahs.isEmpty
                    ? _EmptyState(onRetry: _loadSurah)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
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
                              // Juz boundary marker
                              if (juzNumber != null)
                                _JuzMarker(juzNumber: juzNumber),
                              // Divider between ayahs (not before first)
                              if (i > 0 && juzNumber == null)
                                const Divider(height: 0.5, indent: 16),
                              _AyahTile(
                                ayah: ayah,
                                tajweedEnabled: _tajweedEnabled,
                                showTranslation: _showTranslation,
                                langCode: langCode,
                                isPlaying: isPlaying,
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
    String englishName = 'Surah $selected';
    for (final s in surahs) {
      if (s['id'] == selected) {
        arabicName = s['name_arabic'] as String? ?? '';
        englishName = s['name_simple'] as String? ?? 'Surah $selected';
        break;
      }
    }

    return GestureDetector(
      onTap: () => _showSurahPicker(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (arabicName.isNotEmpty) ...[
            Text(arabicName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'UthmanicHafs',
                      fontSize: 18,
                    )),
            const SizedBox(width: 6),
          ],
          Text('($englishName)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
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
              autofocus: true,
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
                        onTap: () => widget.onChanged(id),
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

// ─── Ayah Tile (redesigned) ──────────────────────────────────────────────────

class _AyahTile extends StatelessWidget {
  final Ayah ayah;
  final bool tajweedEnabled;
  final bool showTranslation;
  final String langCode;
  final bool isPlaying;
  final bool isBookmarked;
  final void Function(TajweedRule, String) onWordTapped;
  final VoidCallback onDoubleTap;
  final VoidCallback onTafseerTap;
  final VoidCallback onBookmarkTap;

  const _AyahTile({
    required this.ayah, required this.tajweedEnabled,
    required this.showTranslation, required this.langCode,
    required this.isPlaying, required this.isBookmarked,
    required this.onWordTapped, required this.onDoubleTap,
    required this.onTafseerTap, required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onBookmarkTap,
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
              fontSize: 24,
              highlightEnabled: tajweedEnabled,
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
