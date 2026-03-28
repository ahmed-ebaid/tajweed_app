import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Bookmark {
  final int surah;
  final int ayah;
  final String? label;
  final int timestamp; // millisecondsSinceEpoch

  const Bookmark({
    required this.surah,
    required this.ayah,
    this.label,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'surah': surah,
        'ayah': ayah,
        'label': label,
        'timestamp': timestamp,
      };

  factory Bookmark.fromMap(Map<dynamic, dynamic> map) => Bookmark(
        surah: map['surah'] as int,
        ayah: map['ayah'] as int,
        label: map['label'] as String?,
        timestamp: map['timestamp'] as int,
      );
}

class BookmarkProvider extends ChangeNotifier {
  static const _boxKey = 'bookmarks';
  static const _lastSurahKey = 'last_surah';
  static const _lastAyahKey = 'last_ayah';
  static const _bookmarksListKey = 'bookmarks_list';

  int _lastReadSurah = 1;
  int _lastReadAyah = 1;
  List<Bookmark> _bookmarks = [];

  int get lastReadSurah => _lastReadSurah;
  int get lastReadAyah => _lastReadAyah;
  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);

  BookmarkProvider() {
    _load();
  }

  void _load() {
    final box = Hive.box(_boxKey);
    _lastReadSurah = box.get(_lastSurahKey, defaultValue: 1) as int;
    _lastReadAyah = box.get(_lastAyahKey, defaultValue: 1) as int;

    final raw = box.get(_bookmarksListKey, defaultValue: <dynamic>[]) as List;
    _bookmarks = raw
        .map((e) => Bookmark.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveLastRead(int surah, int ayah) async {
    if (surah == _lastReadSurah && ayah == _lastReadAyah) return;
    _lastReadSurah = surah;
    _lastReadAyah = ayah;
    final box = Hive.box(_boxKey);
    await box.put(_lastSurahKey, surah);
    await box.put(_lastAyahKey, ayah);
    notifyListeners();
  }

  Future<void> addBookmark(int surah, int ayah, {String? label}) async {
    // Don't duplicate
    if (_bookmarks.any((b) => b.surah == surah && b.ayah == ayah)) return;
    final bm = Bookmark(
      surah: surah,
      ayah: ayah,
      label: label,
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
