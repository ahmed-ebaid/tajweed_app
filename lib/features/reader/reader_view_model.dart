import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/tajweed_models.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/ayah_mapper.dart';
import '../../core/services/quran_api_service.dart';

/// ViewModel for the Reader screen — handles surah loading, caching,
/// audio playback state, and tajweed display toggles.
class ReaderViewModel extends ChangeNotifier {
  final QuranApiService _api = QuranApiService();
  final AudioService audioService = AudioService();

  int _selectedSurah = 67;
  String _langCode = 'en';
  bool _tajweedEnabled = true;
  bool _showTranslation = true;
  bool _loading = false;
  List<Ayah> _ayahs = [];
  int? _playingAyah; // ayahNumber currently playing, or null

  // ── Public getters ────────────────────────────────────────────────────────

  int get selectedSurah => _selectedSurah;
  bool get tajweedEnabled => _tajweedEnabled;
  bool get showTranslation => _showTranslation;
  bool get loading => _loading;
  List<Ayah> get ayahs => _ayahs;
  int? get playingAyah => _playingAyah;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> loadSurah(int surahNumber, String langCode) async {
    _selectedSurah = surahNumber;
    _langCode = langCode;
    _loading = true;
    notifyListeners();

    try {
      // Try cache first
      final cached = _loadFromCache(surahNumber, langCode);
      if (cached != null) {
        _ayahs = cached;
        _loading = false;
        notifyListeners();
        return;
      }

      final raw = await _api.fetchVerses(
        surahNumber: surahNumber,
        langCode: langCode,
      );
      _ayahs = AyahMapper.fromApiList(raw);
      _cacheVerses(surahNumber, langCode, raw);
    } catch (_) {
      _ayahs = [];
    }

    _loading = false;
    notifyListeners();
  }

  void toggleTajweed() {
    _tajweedEnabled = !_tajweedEnabled;
    notifyListeners();
  }

  void toggleTranslation() {
    _showTranslation = !_showTranslation;
    notifyListeners();
  }

  Future<void> playAyah(Ayah ayah) async {
    if (_playingAyah == ayah.ayahNumber) {
      await audioService.stop();
      _playingAyah = null;
    } else {
      _playingAyah = ayah.ayahNumber;
      final url = ayah.audioUrl ??
          _api.audioUrl(
            reciterId: 7,
            surahNumber: ayah.surahNumber,
            ayahNumber: ayah.ayahNumber,
          );
      await audioService.playUrl(url);
      // Reset when done
      audioService.playerStateStream.listen((state) {
        if (state.processingState.name == 'completed') {
          _playingAyah = null;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    await audioService.setSpeed(speed);
  }

  // ── Cache helpers (Hive) ────────────────────────────────────────────────

  static const _cacheBox = 'verse_cache';

  List<Ayah>? _loadFromCache(int surah, String lang) {
    try {
      final box = Hive.box(_cacheBox);
      final key = '${surah}_$lang';
      final raw = box.get(key);
      if (raw is List) {
        return raw
            .cast<Map>()
            .map((m) => AyahMapper.fromApi(Map<String, dynamic>.from(m)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  void _cacheVerses(
      int surah, String lang, List<Map<String, dynamic>> raw) {
    try {
      final box = Hive.box(_cacheBox);
      box.put('${surah}_$lang', raw);
    } catch (_) {}
  }

  @override
  void dispose() {
    audioService.dispose();
    super.dispose();
  }
}
