import 'package:dio/dio.dart';
import '../models/tajweed_models.dart';

/// Wraps the Quran.com v4 API.
/// Docs: https://api.quran.com/api/v4
class QuranApiService {
  static const _baseUrl = 'https://api.quran.com/api/v4';
  static const _audioBaseUrl = 'https://verses.quran.com';

  final Dio _dio;

  QuranApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ));

  // ─── Surahs ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchSurahList({
    required String langCode,
  }) async {
    final response = await _dio.get(
      '/chapters',
      queryParameters: {'language': langCode},
    );
    return List<Map<String, dynamic>>.from(response.data['chapters']);
  }

  // ─── Verses (with tajweed word data) ──────────────────────────────────────

  /// Returns verses for a surah with word-by-word data including tajweed codes.
  /// The API returns tajweed color codes per word which we map to [TajweedRule].
  Future<List<Map<String, dynamic>>> fetchVerses({
    required int surahNumber,
    required String langCode,
    int reciterId = 1, // AbdulBasit Mujawwad
    int? page,
  }) async {
    final response = await _dio.get(
      '/verses/by_chapter/$surahNumber',
      queryParameters: {
        'language': langCode,
        'words': true,
        'word_fields': 'text_uthmani,tajweed,transliteration',
        'translations': _translationIdFor(langCode),
        'audio': reciterId,
        'page': page ?? 1,
        'per_page': 50,
      },
    );
    return List<Map<String, dynamic>>.from(response.data['verses']);
  }

  /// Returns a single verse.
  Future<Map<String, dynamic>> fetchVerse({
    required int surahNumber,
    required int ayahNumber,
    required String langCode,
    int reciterId = 1, // AbdulBasit Mujawwad
  }) async {
    final response = await _dio.get(
      '/verses/by_key/$surahNumber:$ayahNumber',
      queryParameters: {
        'language': langCode,
        'words': true,
        'word_fields': 'text_uthmani,tajweed',
        'translations': _translationIdFor(langCode),
        'audio': reciterId,
      },
    );
    return response.data['verse'];
  }

  /// Fetches per-ayah audio file URLs for a surah from the recitations API.
  /// Returns a map of verseKey (e.g. '1:1') → full audio URL.
  Future<Map<String, String>> fetchAudioFiles({
    required int reciterId,
    required int surahNumber,
  }) async {
    final map = <String, String>{};
    int page = 1;

    while (true) {
      final response = await _dio.get(
        '/recitations/$reciterId/by_chapter/$surahNumber',
        queryParameters: {'page': page, 'per_page': 50},
      );
      final files = response.data['audio_files'] as List<dynamic>? ?? [];
      for (final f in files) {
        final key = f['verse_key'] as String? ?? '';
        final url = f['url'] as String? ?? '';
        if (key.isNotEmpty && url.isNotEmpty) {
          map[key] = url.startsWith('http') ? url : '$_audioBaseUrl/$url';
        }
      }

      if (files.length < 50) break;
      page++;
    }

    return map;
  }

  // ─── Audio ────────────────────────────────────────────────────────────────

  /// Fetches tajweed-annotated text for all verses in a chapter.
  /// Returns a map of verse_key → HTML string with <tajweed> tags.
  Future<Map<String, String>> fetchTajweedText({
    required int chapterNumber,
  }) async {
    final response = await _dio.get(
      '/quran/verses/uthmani_tajweed',
      queryParameters: {'chapter_number': chapterNumber},
    );
    final verses = response.data['verses'] as List<dynamic>? ?? [];
    final map = <String, String>{};
    for (final v in verses) {
      final key = v['verse_key'] as String? ?? '';
      final text = v['text_uthmani_tajweed'] as String? ?? '';
      if (key.isNotEmpty && text.isNotEmpty) {
        map[key] = text;
      }
    }
    return map;
  }

  /// Returns the CDN URL for a verse audio file.
  /// Format: https://verses.quran.com/{reciterId}/{surah:3digits}{ayah:3digits}.mp3
  String audioUrl({
    required int reciterId,
    required int surahNumber,
    required int ayahNumber,
  }) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return '$_audioBaseUrl/$reciterId/$s$a.mp3';
  }

  // ─── Juz Mappings ──────────────────────────────────────────────────────────

  /// Fetches juz data and builds a map of surah:ayah → juz number for boundary markers.
  /// Returns { juzNumber: { chapterNumber: "startAyah-endAyah" } }.
  Future<List<Map<String, dynamic>>> fetchJuzList() async {
    final response = await _dio.get('/juzs');
    final raw = response.data['juzs'] as List<dynamic>? ?? [];
    // API may return duplicates — deduplicate by juz_number
    final seen = <int>{};
    final juzs = <Map<String, dynamic>>[];
    for (final j in raw) {
      final num = j['juz_number'] as int;
      if (seen.add(num)) juzs.add(Map<String, dynamic>.from(j as Map));
    }
    return juzs;
  }

  // ─── Tafseer ──────────────────────────────────────────────────────────────

  /// Fetches tafseer for a single ayah.
  Future<String> fetchTafsirForAyah({
    required int tafsirId,
    required String verseKey,
  }) async {
    final response = await _dio.get('/tafsirs/$tafsirId/by_ayah/$verseKey');
    final tafsir = response.data['tafsir'] as Map<String, dynamic>? ?? {};
    return tafsir['text'] as String? ?? '';
  }

  /// Fetches the list of available tafsirs from the resources API.
  Future<List<Map<String, dynamic>>> fetchAvailableTafsirs() async {
    final response = await _dio.get('/resources/tafsirs');
    return List<Map<String, dynamic>>.from(response.data['tafsirs']);
  }

  // ─── Reciters ─────────────────────────────────────────────────────────────

  /// Fetches the list of available reciters from the resources API.
  Future<List<Map<String, dynamic>>> fetchAvailableReciters() async {
    final response = await _dio.get('/resources/recitations');
    return List<Map<String, dynamic>>.from(response.data['recitations']);
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> search({
    required String query,
    required String langCode,
  }) async {
    final response = await _dio.get(
      '/search',
      queryParameters: {
        'q': query,
        'language': langCode,
        'size': 20,
      },
    );
    return List<Map<String, dynamic>>.from(response.data['search']['results']);
  }

  // ─── Tajweed code mapping ─────────────────────────────────────────────────

  /// The Quran.com API encodes tajweed rules as single characters in a
  /// `tajweed` field per word. This maps those codes to [TajweedRule].
  ///
  /// Known codes (from Quran.com tajweed encoding):
  ///   g = ghunnah
  ///   q = qalqalah
  ///   m = madd (natural)
  ///   M = madd muttasil
  ///   n = madd munfasil
  ///   i = ikhfa
  ///   I = iqlab
  ///   d = idgham with ghunnah
  ///   D = idgham without ghunnah
  ///   z = izhar
  ///   s = shaddah
  static TajweedRule? ruleFromCode(String code) {
    switch (code) {
      case 'g': return TajweedRule.ghunnah;
      case 'q': return TajweedRule.qalqalah;
      case 'm': return TajweedRule.maddTabeei;
      case 'M': return TajweedRule.maddMuttasil;
      case 'n': return TajweedRule.maddMunfasil;
      case 'i': return TajweedRule.ikhfa;
      case 'I': return TajweedRule.iqlab;
      case 'd': return TajweedRule.idghamWithGhunnah;
      case 'D': return TajweedRule.idghamWithoutGhunnah;
      case 'z': return TajweedRule.izhar;
      case 's': return TajweedRule.shaddah;
      default:  return null;
    }
  }

  // ─── Translation IDs ──────────────────────────────────────────────────────

  /// Maps language codes to Quran.com translation resource IDs.
  static String _translationIdFor(String langCode) {
    switch (langCode) {
      case 'ar': return '16';   // Muhammad Taqī-ud-Dīn al-Hilālī (Arabic tafsir)
      case 'ur': return '97';   // Fateh Muhammad Jalandhari
      case 'tr': return '52';   // Diyanet İşleri
      case 'fr': return '31';   // Muhammad Hamidullah
      case 'id': return '33';   // Indonesian Ministry of Religious Affairs
      case 'de': return '27';   // Adul Hye & Ahmad von Denffer
      default:   return '131';  // Dr. Mustafa Khattab (English)
    }
  }
}
