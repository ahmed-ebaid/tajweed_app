import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Bookmark {
  final int surah;
  final int ayah;
  final String? label;
  final double scrollOffset; // Saved scroll position
  final int timestamp; // millisecondsSinceEpoch

  const Bookmark({
    required this.surah,
    required this.ayah,
    this.label,
    this.scrollOffset = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'surah': surah,
        'ayah': ayah,
        'label': label,
        'scrollOffset': scrollOffset,
        'timestamp': timestamp,
      };

  factory Bookmark.fromMap(Map<dynamic, dynamic> map) => Bookmark(
        surah: map['surah'] as int,
        ayah: map['ayah'] as int,
        label: map['label'] as String?,
        scrollOffset: (map['scrollOffset'] as num?)?.toDouble() ?? 0.0,
        timestamp: map['timestamp'] as int,
      );
}

class BookmarkProvider extends ChangeNotifier {
  static const _boxKey = 'bookmarks';
  static const _lastSurahKey = 'last_surah';
  static const _lastAyahKey = 'last_ayah';
  static const _lastScrollOffsetKey = 'last_scroll_offset';
  static const _bookmarksListKey = 'bookmarks_list';

  int _lastReadSurah = 1;
  int _lastReadAyah = 1;
  double _lastScrollOffset = 0.0;
  List<Bookmark> _bookmarks = [];

  int get lastReadSurah => _lastReadSurah;
  int get lastReadAyah => _lastReadAyah;
  double get lastScrollOffset => _lastScrollOffset;
  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);

  BookmarkProvider() {
    _load();
  }

  void _load() {
    try {
      final box = Hive.box(_boxKey);
      _lastReadSurah = box.get(_lastSurahKey, defaultValue: 1) as int;
      _lastReadAyah = box.get(_lastAyahKey, defaultValue: 1) as int;
      _lastScrollOffset = (box.get(_lastScrollOffsetKey, defaultValue: 0.0) as num).toDouble();

      final raw = box.get(_bookmarksListKey, defaultValue: <dynamic>[]) as List;
      _bookmarks = raw
          .map((e) {
            try {
              return Bookmark.fromMap(Map<dynamic, dynamic>.from(e as Map));
            } catch (_) {
              return null;
            }
          })
          .whereType<Bookmark>()
          .toList();
    } catch (e) {
      // If Hive data is corrupted, reset to defaults
      _lastReadSurah = 1;
      _lastReadAyah = 1;
      _lastScrollOffset = 0.0;
      _bookmarks = [];
    }
  }

  Future<void> saveLastRead(int surah, int ayah, {double? scrollOffset, String? caller}) async {
    final sameReference = surah == _lastReadSurah && ayah == _lastReadAyah;
    final sameOffset = scrollOffset == null || scrollOffset == _lastScrollOffset;
    if (sameReference && sameOffset) return;
    _lastReadSurah = surah;
    _lastReadAyah = ayah;
    if (scrollOffset != null) {
      _lastScrollOffset = scrollOffset;
    }
    final box = Hive.box(_boxKey);
    await box.put(_lastSurahKey, surah);
    await box.put(_lastAyahKey, ayah);
    if (scrollOffset != null) {
      await box.put(_lastScrollOffsetKey, scrollOffset);
    }
    await box.compact(); // Force persist to disk
    print('✅ SAVE LAST READ [${caller ?? '-'}]: surah=$surah, ayah=$ayah, offset=$_lastScrollOffset');
    // Do NOT call notifyListeners() here — last-read position changes don't
    // affect any visible UI, and notifying causes a full reader rebuild on
    // every scroll-debounce save, creating an oscillation loop.
  }

  Future<void> addBookmark(int surah, int ayah, {String? label, double scrollOffset = 0.0}) async {
    // Don't duplicate
    if (_bookmarks.any((b) => b.surah == surah && b.ayah == ayah)) return;
    final bm = Bookmark(
      surah: surah,
      ayah: ayah,
      label: label,
      scrollOffset: scrollOffset,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _bookmarks.add(bm);
    await _persist();
    notifyListeners();
  }

  Future<void> removeBookmark(int surah, int ayah) async {
    _bookmarks.removeWhere((b) => b.surah == surah && b.ayah == ayah);
    await _persist();
    notifyListeners();
  }

  bool isBookmarked(int surah, int ayah) =>
      _bookmarks.any((b) => b.surah == surah && b.ayah == ayah);

  Future<void> _persist() async {
    final box = Hive.box(_boxKey);
    await box.put(
        _bookmarksListKey, _bookmarks.map((b) => b.toMap()).toList());
  }
}
