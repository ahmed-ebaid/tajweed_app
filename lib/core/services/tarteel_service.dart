import 'dart:io';
import 'package:dio/dio.dart';
import '../models/tajweed_models.dart';

/// Wraps the Tarteel AI API for real-time tajweed recitation evaluation.
/// Sign up for a free API key at https://tarteel.ai
class TarteelService {
  static const _baseUrl = 'https://tarteel.ai/api/v1';

  // Set your key via --dart-define=TARTEEL_API_KEY=your_key at build time,
  // or inject it from a secure config.
  static const _apiKey = String.fromEnvironment('TARTEEL_API_KEY', defaultValue: '');

  final Dio _dio;

  TarteelService()
      : _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          headers: {
            'Authorization': 'Token $_apiKey',
            'Content-Type': 'multipart/form-data',
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Upload a recorded audio file and receive tajweed feedback.
  ///
  /// [audioPath]    Path to the recorded .m4a / .wav file on device.
  /// [surahNumber]  1-based surah index.
  /// [ayahNumber]   1-based ayah index.
  ///
  /// Returns a [RecitationFeedback] with per-rule scores,
  /// or throws a [TarteelException] on failure.
  Future<RecitationFeedback> evaluateRecitation({
    required String audioPath,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    // Use mock feedback if no API key is configured (development mode)
    if (_apiKey.isEmpty) {
      return _mockFeedback(audioPath);
    }

    final file = File(audioPath);
    if (!file.existsSync()) {
      throw TarteelException('Audio file not found: $audioPath');
    }

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(audioPath),
      'surah_num': surahNumber,
      'ayah_num': ayahNumber,
    });

    try {
      final response = await _dio.post('/evaluate', data: formData);
      return _parseFeedback(response.data, audioPath);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw TarteelException('Rate limited — please wait and try again');
      }
      throw TarteelException(
          'Network error: ${e.message ?? 'Connection failed'}');
    }
  }

  /// Returns mock feedback for development when no API key is set.
  RecitationFeedback _mockFeedback(String audioPath) {
    return RecitationFeedback(
      overallScore: 78,
      ruleScores: {
        TajweedRule.ghunnah: 0.85,
        TajweedRule.maddTabeei: 0.90,
        TajweedRule.qalqalah: 0.72,
        TajweedRule.ikhfa: 0.65,
        TajweedRule.idghamWithGhunnah: 0.80,
      },
      audioPath: audioPath,
      timestamp: DateTime.now(),
    );
  }

  RecitationFeedback _parseFeedback(
      Map<String, dynamic> data, String audioPath) {
    final overall = (data['overall_score'] as num).toInt();

    // Tarteel returns rule scores as a map of rule_name → 0–100
    final rawScores = Map<String, dynamic>.from(data['rule_scores'] ?? {});
    final ruleScores = <TajweedRule, double>{};

    for (final entry in rawScores.entries) {
      final rule = _ruleFromTarteelKey(entry.key);
      if (rule != null) {
        ruleScores[rule] = (entry.value as num).toDouble() / 100.0;
      }
    }

    return RecitationFeedback(
      overallScore: overall,
      ruleScores: ruleScores,
      audioPath: audioPath,
      timestamp: DateTime.now(),
    );
  }

  static TajweedRule? _ruleFromTarteelKey(String key) {
    switch (key) {
      case 'ghunnah':              return TajweedRule.ghunnah;
      case 'qalqalah':             return TajweedRule.qalqalah;
      case 'madd_tabeei':          return TajweedRule.maddTabeei;
      case 'madd_muttasil':        return TajweedRule.maddMuttasil;
      case 'madd_munfasil':        return TajweedRule.maddMunfasil;
      case 'idgham_ghunnah':       return TajweedRule.idghamWithGhunnah;
      case 'idgham_no_ghunnah':    return TajweedRule.idghamWithoutGhunnah;
      case 'ikhfa':                return TajweedRule.ikhfa;
      case 'iqlab':                return TajweedRule.iqlab;
      case 'izhar':                return TajweedRule.izhar;
      default:                     return null;
    }
  }
}

class TarteelException implements Exception {
  final String message;
  TarteelException(this.message);

  @override
  String toString() => 'TarteelException: $message';
}
