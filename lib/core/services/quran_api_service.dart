import 'package:dio/dio.dart';
import '../models/tajweed_models.dart';
import 'quran_attestation_service.dart';

class QuranContentMutation {
  final String type;
  final String resourceGroup;
  final int resourceId;
  final String? recordKey;
  final Map<String, dynamic>? data;

  const QuranContentMutation({
    required this.type,
    required this.resourceGroup,
    required this.resourceId,
    required this.recordKey,
    required this.data,
  });

  factory QuranContentMutation.fromJson(Map<String, dynamic> json) {
    final resourceId = json['resource_id'];
    if (resourceId is! int) {
      throw const FormatException('Content Sync mutation has no resource ID');
    }
    final rawData = json['data'];
    return QuranContentMutation(
      type: json['type']?.toString() ?? '',
      resourceGroup: json['resource_group']?.toString() ?? '',
      resourceId: resourceId,
      recordKey: json['record_key']?.toString(),
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : null,
    );
  }
}

class QuranContentSyncPage {
  final bool hasMore;
  final String? nextPageUrl;
  final String? nextSyncToken;
  final List<QuranContentMutation> mutations;

  const QuranContentSyncPage({
    required this.hasMore,
    required this.nextPageUrl,
    required this.nextSyncToken,
    required this.mutations,
  });

  factory QuranContentSyncPage.fromJson(Map<String, dynamic> json) {
    final rawSync = json['sync'];
    if (rawSync is! Map) {
      throw const FormatException('Content Sync response is malformed');
    }
    final sync = Map<String, dynamic>.from(rawSync);
    final rawMutations = sync['mutations'];
    return QuranContentSyncPage(
      hasMore: sync['has_more'] == true,
      nextPageUrl: sync['next_page_url']?.toString(),
      nextSyncToken: sync['next_sync_token']?.toString(),
      mutations: rawMutations is List
          ? rawMutations
                .whereType<Map>()
                .map(
                  (item) => QuranContentMutation.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class QuranContentSnapshot {
  final String resourceGroup;
  final int resourceId;
  final List<Map<String, dynamic>> records;

  const QuranContentSnapshot({
    required this.resourceGroup,
    required this.resourceId,
    required this.records,
  });

  factory QuranContentSnapshot.fromJson(Map<String, dynamic> json) {
    final resourceId = json['resource_id'];
    final rawRecords = json['records'];
    if (resourceId is! int || rawRecords is! List) {
      throw const FormatException('Content snapshot is malformed');
    }
    return QuranContentSnapshot(
      resourceGroup: json['resource_group']?.toString() ?? '',
      resourceId: resourceId,
      records: rawRecords
          .whereType<Map>()
          .map((record) => Map<String, dynamic>.from(record))
          .toList(growable: false),
    );
  }
}

/// Accesses Quran Foundation content through the app-owned backend proxy.
class QuranApiService {
  static const _configuredContentApiBaseUrl = String.fromEnvironment(
    'QURAN_CONTENT_API_BASE_URL',
  );
  static const _productionContentApiBaseUrl =
      'https://tajweed-quran-proxy-production.ebaidllc.workers.dev/v2/content';

  static String get contentApiBaseUrl {
    if (_configuredContentApiBaseUrl.isNotEmpty) {
      return _configuredContentApiBaseUrl;
    }
    return _productionContentApiBaseUrl;
  }

  static const _audioBaseUrl = 'https://verses.quran.com';

  final Dio _contentDio;

  QuranApiService({
    Dio? contentClient,
    QuranAttestationService? attestationService,
  }) : _contentDio =
           contentClient ??
           Dio(
             BaseOptions(
               baseUrl: contentApiBaseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           ) {
    if (contentClient == null) {
      final attestation =
          attestationService ??
          QuranAttestationService.forContentApi(contentApiBaseUrl);
      _contentDio.interceptors.add(
        QueuedInterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              options.headers['authorization'] =
                  'Bearer ${await attestation.accessToken()}';
              handler.next(options);
            } catch (error, stackTrace) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: error,
                  stackTrace: stackTrace,
                  type: DioExceptionType.unknown,
                ),
              );
            }
          },
          onError: (error, handler) async {
            if (error.response?.statusCode != 401 ||
                error.requestOptions.extra['appAttestRetried'] == true) {
              handler.next(error);
              return;
            }
            try {
              attestation.invalidateAccessToken();
              final options = error.requestOptions;
              options.extra['appAttestRetried'] = true;
              options.headers['authorization'] =
                  'Bearer ${await attestation.accessToken()}';
              handler.resolve(await _contentDio.fetch(options));
            } catch (_) {
              handler.next(error);
            }
          },
        ),
      );
    }
  }

  // ─── Surahs ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchSurahList({
    required String langCode,
  }) async {
    final response = await _contentDio.get(
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
    final response = await _contentDio.get(
      '/verses/by_chapter/$surahNumber',
      queryParameters: {
        'language': langCode,
        'words': true,
        'fields': 'page_number,verse_key',
        'word_fields':
            'text_uthmani,text_imlaei,text_uthmani_tajweed,tajweed,char_type_name,transliteration,audio_url',
        'translations': translationIdFor(langCode),
        'audio': reciterId,
        'page': page ?? 1,
        'per_page': 50,
      },
    );
    return List<Map<String, dynamic>>.from(response.data['verses']);
  }

  /// Returns all verses that belong to a Mushaf page number (1..604).
  Future<List<Map<String, dynamic>>> fetchVersesByPage({
    required int pageNumber,
    required String langCode,
  }) async {
    final safePage = pageNumber.clamp(1, 604);
    final response = await _contentDio.get(
      '/verses/by_page/$safePage',
      queryParameters: {
        'language': langCode,
        'words': 'false',
        'fields': 'text_uthmani,page_number,verse_key,juz_number',
        'per_page': 50,
      },
    );
    return List<Map<String, dynamic>>.from(response.data['verses'] ?? const []);
  }

  /// Returns a single verse.
  Future<Map<String, dynamic>> fetchVerse({
    required int surahNumber,
    required int ayahNumber,
    required String langCode,
    int reciterId = 1, // AbdulBasit Mujawwad
  }) async {
    final response = await _contentDio.get(
      '/verses/by_key/$surahNumber:$ayahNumber',
      queryParameters: {
        'language': langCode,
        'words': true,
        'fields': 'text_uthmani,page_number,verse_key',
        'word_fields':
            'text_uthmani,text_imlaei,text_uthmani_tajweed,tajweed,char_type_name,audio_url',
        'translations': translationIdFor(langCode),
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
      final response = await _contentDio.get(
        '/recitations/$reciterId/by_chapter/$surahNumber',
        queryParameters: {'page': page, 'per_page': 50},
      );
      final files = response.data['audio_files'] as List<dynamic>? ?? [];
      for (final f in files) {
        final key = f['verse_key'] as String? ?? '';
        final url = f['url'] as String? ?? '';
        if (key.isNotEmpty && url.isNotEmpty) {
          map[key] = url.startsWith('http')
              ? url
              : url.startsWith('//')
              ? 'https:$url'
              : '$_audioBaseUrl/$url';
        }
      }

      if (files.length < 50) break;
      page++;
    }

    return map;
  }

  // ─── Audio ────────────────────────────────────────────────────────────────

  /// Fetches tajweed-annotated text for all verses in a chapter.
  /// Returns a map of verse_key → HTML string with `<tajweed>` tags.
  Future<Map<String, String>> fetchTajweedText({
    required int chapterNumber,
  }) async {
    final response = await _contentDio.get(
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
    final response = await _contentDio.get('/juzs');
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
    final response = await _contentDio.get(
      '/tafsirs/$tafsirId/by_ayah/$verseKey',
    );
    final tafsirRaw = response.data['tafsir'];
    final tafsir = tafsirRaw is Map
        ? Map<String, dynamic>.from(tafsirRaw)
        : <String, dynamic>{};
    return tafsir['text'] as String? ?? '';
  }

  /// Fetches the list of available tafsirs from the resources API.
  Future<List<Map<String, dynamic>>> fetchAvailableTafsirs() async {
    final response = await _contentDio.get('/resources/tafsirs');
    return List<Map<String, dynamic>>.from(response.data['tafsirs']);
  }

  // ─── Reciters ─────────────────────────────────────────────────────────────

  /// Fetches the list of available reciters from the resources API.
  Future<List<Map<String, dynamic>>> fetchAvailableReciters() async {
    final response = await _contentDio.get('/resources/recitations');
    return List<Map<String, dynamic>>.from(
      response.data['recitations'],
    ).where((reciter) => (reciter['id'] as int?) != 7).toList(growable: false);
  }

  Future<QuranContentSyncPage> fetchContentSyncPage({
    required String resources,
    String? syncToken,
    String? nextPageUrl,
  }) async {
    Map<String, dynamic> query;
    if (nextPageUrl != null) {
      final uri = Uri.parse(nextPageUrl);
      if (!uri.path.endsWith('/resources/sync')) {
        throw const FormatException('Unexpected Content Sync next-page URL');
      }
      query = Map<String, dynamic>.from(uri.queryParameters);
    } else {
      query = {
        'resources': resources,
        'per_page': 100,
        if (syncToken == null) 'bootstrap': true,
        if (syncToken != null) 'sync_token': syncToken,
      };
    }

    final response = await _contentDio.get(
      '/resources/sync',
      queryParameters: query,
    );
    return QuranContentSyncPage.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<QuranContentSnapshot> fetchContentSnapshot({
    required String resourceGroup,
    required int resourceId,
  }) async {
    const supportedGroups = {'translations', 'tafsirs', 'recitations'};
    if (!supportedGroups.contains(resourceGroup)) {
      throw ArgumentError.value(
        resourceGroup,
        'resourceGroup',
        'Unsupported Content Sync resource group',
      );
    }
    final response = await _contentDio.get(
      '/resources/snapshots/$resourceGroup/$resourceId',
    );
    return QuranContentSnapshot.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
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
      case 'g':
        return TajweedRule.ghunnah;
      case 'q':
        return TajweedRule.qalqalah;
      case 'm':
        return TajweedRule.maddTabeei;
      case 'M':
        return TajweedRule.maddMuttasil;
      case 'n':
        return TajweedRule.maddMunfasil;
      case 'i':
        return TajweedRule.ikhfa;
      case 'I':
        return TajweedRule.iqlab;
      case 'd':
        return TajweedRule.idghamWithGhunnah;
      case 'D':
        return TajweedRule.idghamWithoutGhunnah;
      case 'z':
        return TajweedRule.izhar;
      case 's':
        return TajweedRule.shaddah;
      default:
        return null;
    }
  }

  // ─── Translation IDs ──────────────────────────────────────────────────────

  /// Maps language codes to Quran.com translation resource IDs.
  static String translationIdFor(String langCode) {
    switch (langCode) {
      case 'ar':
        return '16'; // Muhammad Taqī-ud-Dīn al-Hilālī (Arabic tafsir)
      case 'ur':
        return '97'; // Fateh Muhammad Jalandhari
      case 'tr':
        return '52'; // Diyanet İşleri
      case 'fr':
        return '31'; // Muhammad Hamidullah
      case 'id':
        return '33'; // Indonesian Ministry of Religious Affairs
      case 'de':
        return '27'; // Adul Hye & Ahmad von Denffer
      case 'es':
        return '83'; // Sheikh Isa Garcia
      default:
        return '85'; // M.A.S. Abdel Haleem (English)
    }
  }
}
