import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_version.dart';
import 'memorization_speech_service.dart';
import 'quran_api_service.dart';
import 'quran_attestation_service.dart';

const quranAsrExperimentEnabled = bool.fromEnvironment('QURAN_ASR_EXPERIMENT');
const quranAsrRetainDebugAudio =
    quranAsrExperimentEnabled &&
    bool.fromEnvironment('QURAN_ASR_RETAIN_DEBUG_AUDIO');
const quranAsrContextRecoveryEnabled =
    quranAsrExperimentEnabled &&
    bool.fromEnvironment('QURAN_ASR_CONTEXT_RECOVERY', defaultValue: true);

/// Lab-only rolling snapshots, not a streaming ASR model. Capture continues
/// until stopped; each report covers at most the latest 30 seconds.
class QuranAsrSpeechInput implements WindowedMemorizationSpeechInput {
  static const _maxInitialRecoveryAttemptsWithoutWords = 3;
  static const _channel = MethodChannel(
    'com.ebaidllc.tajweed_practice/quran_asr',
  );
  Timer? _poll;
  double _windowStartSeconds = 0;
  double _lastDurationSeconds = 0;
  double _ordinaryWindowStartSeconds = 0;
  double _audioEndSeconds = 0;
  double? _snapshotRequestedAtUnixMs;
  int? _visibleWordsHighWater;
  double? _lastProgressAudioEnd;
  double? _lastVisibleAdvanceAudioEnd;
  double? _lastRecoveryAudioEnd;
  int _nextRecoveryContextSeconds = 12;
  int _initialRecoveryAttemptsWithoutWords = 0;
  @override
  double get windowStartSeconds => _windowStartSeconds;
  double get lastDurationSeconds => _lastDurationSeconds;
  Future<void>? _inFlight;
  Future<void>? _finalizing;
  void Function(String, bool)? _onResult;
  void Function(String)? _onError;
  var _generation = 0;
  bool _active = false;
  bool _stopping = false;

  static Future<void>? _uploadInFlight;

  static Future<List<String>> exportDiagnostics() async {
    if (!quranAsrExperimentEnabled ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return const [];
    }
    try {
      final paths = await _channel.invokeListMethod<String>(
        'exportDiagnostics',
      );
      return paths ?? const [];
    } on PlatformException catch (error) {
      debugPrint('Quran ASR diagnostics export failed: ${error.code}');
      return const [];
    } on MissingPluginException {
      debugPrint('Quran ASR diagnostics export is unavailable.');
      return const [];
    }
  }

  static Future<bool> uploadDiagnosticsToCloud({
    required String verseKey,
    Dio? client,
    Future<List<String>> Function()? exportPaths,
  }) async {
    if (!quranAsrExperimentEnabled ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final previousUpload = _uploadInFlight;
    final completer = Completer<void>();
    _uploadInFlight = completer.future;
    try {
      final paths = await (exportPaths ?? exportDiagnostics)();
      if (paths.isEmpty) return false;

      var diagnosticsJsonl = '';
      final jsonBySlot = <int, String>{};
      final wavBySlot = <int, String>{};
      final slotPattern = RegExp(r'(?:quran-asr-)?snapshot-(\d+)\.(json|wav)$');

      for (final path in paths) {
        final file = File(path);
        if (!file.existsSync()) continue;
        if (path.endsWith('quran-asr-diagnostics.jsonl')) {
          diagnosticsJsonl = await file.readAsString();
          if (diagnosticsJsonl.length > 120 * 1024) {
            diagnosticsJsonl = diagnosticsJsonl.substring(
              diagnosticsJsonl.length - 120 * 1024,
            );
          }
          continue;
        }
        if (!quranAsrRetainDebugAudio) continue;
        final match = slotPattern.firstMatch(path);
        if (match == null) continue;
        final slot = int.tryParse(match.group(1) ?? '');
        final ext = match.group(2);
        if (slot == null || slot < 0 || slot >= 6) continue;
        if (ext == 'json') {
          jsonBySlot[slot] = await file.readAsString();
        } else if (ext == 'wav') {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty && bytes.length <= 1000000) {
            wavBySlot[slot] = base64Encode(bytes);
          }
        }
      }

      final slots = jsonBySlot.keys.where(wavBySlot.containsKey).toList()
        ..sort();
      if (diagnosticsJsonl.isEmpty && slots.isEmpty) {
        return false;
      }

      final snapshots = <Map<String, Object>>[
        for (final slot in slots)
          {
            'slot': slot,
            'json': jsonBySlot[slot]!,
            'wav_base64': wavBySlot[slot]!,
          },
      ];

      // Capture the files before waiting for an earlier HTTP upload.
      await previousUpload;
      final origin = Uri.parse(QuranApiService.contentApiBaseUrl).origin;
      final dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: origin,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              contentType: Headers.jsonContentType,
            ),
          );

      final headers = <String, String>{};
      if (QuranAttestationService.appAttestBypassEnabled) {
        final proxyTestToken = QuranAttestationService.proxyTestToken;
        if (proxyTestToken != null) {
          headers['x-simulator-test-token'] = proxyTestToken;
        }
      } else if (client == null) {
        try {
          final attestation = QuranAttestationService.forContentApi(
            QuranApiService.contentApiBaseUrl,
          );
          headers['authorization'] =
              'Bearer ${await attestation.accessToken()}';
        } catch (error) {
          debugPrint('Quran ASR diagnostics token skipped: $error');
        }
      }

      await dio.post<Map<String, dynamic>>(
        '/v1/asr-diagnostics/upload',
        data: {
          'verse_key': verseKey,
          'app_version': appVersion,
          'diagnostics_jsonl': diagnosticsJsonl,
          'snapshots': snapshots,
        },
        options: Options(headers: headers),
      );
      return true;
    } catch (error) {
      debugPrint('Quran ASR cloud diagnostics upload skipped: $error');
      return false;
    } finally {
      await previousUpload;
      completer.complete();
      if (identical(_uploadInFlight, completer.future)) {
        _uploadInFlight = null;
      }
    }
  }

  Future<void> recordProgress({
    required int expectedIndex,
    required int rawWords,
    required int visibleWords,
    required bool isFinal,
    required bool contradictsPrefix,
    Map<String, int> alignment = const {},
  }) async {
    if (quranAsrContextRecoveryEnabled &&
        _active &&
        !_stopping &&
        !isFinal &&
        visibleWords >= 0 &&
        _audioEndSeconds > 0) {
      _lastProgressAudioEnd = _audioEndSeconds;
      if (_visibleWordsHighWater == null ||
          visibleWords > _visibleWordsHighWater!) {
        _visibleWordsHighWater = visibleWords;
        _lastVisibleAdvanceAudioEnd = _audioEndSeconds;
        _nextRecoveryContextSeconds = 12;
        _initialRecoveryAttemptsWithoutWords = 0;
      }
    }
    if (!quranAsrExperimentEnabled ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('traceProgress', {
        ...alignment,
        'expectedIndex': expectedIndex,
        'rawWords': rawWords,
        'visibleWords': visibleWords,
        'final': isFinal ? 1 : 0,
        'contradiction': contradictsPrefix ? 1 : 0,
        'generation': _generation,
        'active': _active ? 1 : 0,
        'stopping': _stopping ? 1 : 0,
      });
    } on PlatformException catch (error) {
      debugPrint('Quran ASR progress diagnostics failed: ${error.code}');
    } on MissingPluginException {
      debugPrint('Quran ASR progress diagnostics are unavailable.');
    }
  }

  Future<void> recordPreviewReveal({
    required int newVisibleWords,
    required int visibleWords,
    required Future<void> frame,
  }) async {
    final requestedAt = _snapshotRequestedAtUnixMs;
    if (!quranAsrExperimentEnabled ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        !_active ||
        newVisibleWords <= 0 ||
        requestedAt == null) {
      return;
    }
    final generation = _generation;
    final audioEndSeconds = _windowStartSeconds + _lastDurationSeconds;
    await frame;
    if (!_active || generation != _generation) return;
    final milliseconds =
        DateTime.now().microsecondsSinceEpoch / 1000 - requestedAt;
    if (milliseconds < 0) return;
    try {
      await _channel.invokeMethod<void>('tracePreviewReveal', {
        'generation': generation,
        'audioEndSeconds': audioEndSeconds,
        'newVisibleWords': newVisibleWords,
        'visibleWords': visibleWords,
        'snapshotToRevealMs': milliseconds,
      });
    } on PlatformException catch (error) {
      debugPrint('Quran ASR reveal diagnostics failed: ${error.code}');
    } on MissingPluginException {
      debugPrint('Quran ASR reveal diagnostics are unavailable.');
    }
  }

  @override
  Future<void> start({
    required void Function(String, bool) onResult,
    required void Function() onDone,
    required void Function(String) onError,
  }) async {
    if (!quranAsrExperimentEnabled) {
      throw const MemorizationSpeechException('quran_asr_unavailable');
    }
    if (_active || _stopping || _inFlight != null || _finalizing != null) {
      throw const MemorizationSpeechException('quran_asr_busy');
    }
    final generation = ++_generation;
    _windowStartSeconds = 0;
    _lastDurationSeconds = 0;
    _ordinaryWindowStartSeconds = 0;
    _audioEndSeconds = 0;
    _snapshotRequestedAtUnixMs = null;
    _visibleWordsHighWater = null;
    _lastProgressAudioEnd = null;
    _lastVisibleAdvanceAudioEnd = null;
    _lastRecoveryAudioEnd = null;
    _nextRecoveryContextSeconds = 12;
    _initialRecoveryAttemptsWithoutWords = 0;
    _onResult = onResult;
    _onError = onError;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'interrupted' && generation == _generation) {
        _fail(generation, 'quran_asr_interrupted');
        await cancel();
      }
    });
    try {
      if (await _channel.invokeMethod<bool>('available') != true) {
        throw const MemorizationSpeechException('quran_asr_unavailable');
      }
      if (generation != _generation) return;
      await _channel.invokeMethod<void>('start', {
        'retainDebugAudio': quranAsrRetainDebugAudio,
      });
      if (generation != _generation) return;
      _active = true;
      _schedulePreview(generation, initial: true);
    } on MissingPluginException {
      throw const MemorizationSpeechException('quran_asr_unavailable');
    }
  }

  void _schedulePreview(int generation, {bool initial = false}) {
    // Probe capture after 500ms; native returns no report until 1s of audio.
    // Subsequent checks wait for fresh audio after inference without overlap.
    final delay = initial
        ? const Duration(milliseconds: 500)
        : const Duration(milliseconds: 200);
    _poll = Timer(delay, () {
      if (!_active || _stopping || generation != _generation) return;
      _inFlight = _preview(generation);
      unawaited(
        _inFlight!.whenComplete(() {
          _inFlight = null;
          if (_active && !_stopping && generation == _generation) {
            _schedulePreview(generation);
          }
        }),
      );
    });
  }

  Future<void> _preview(int generation) async {
    final noVisibleWords = _visibleWordsHighWater == 0;
    final initialRecoveryExhausted =
        noVisibleWords &&
        _initialRecoveryAttemptsWithoutWords >=
            _maxInitialRecoveryAttemptsWithoutWords;
    final recovery =
        quranAsrContextRecoveryEnabled &&
        !initialRecoveryExhausted &&
        _audioEndSeconds > 8 &&
        _lastProgressAudioEnd == _audioEndSeconds &&
        _lastVisibleAdvanceAudioEnd != null &&
        _audioEndSeconds - _lastVisibleAdvanceAudioEnd! >= 4 &&
        (_lastRecoveryAudioEnd == null ||
            _audioEndSeconds - _lastRecoveryAudioEnd! >= 8);
    final contextSeconds = _nextRecoveryContextSeconds;
    if (recovery) {
      if (noVisibleWords) _initialRecoveryAttemptsWithoutWords++;
      _lastRecoveryAudioEnd = _audioEndSeconds;
      _nextRecoveryContextSeconds = 28;
    }
    try {
      final report = await _channel.invokeMapMethod<String, dynamic>(
        'preview',
        recovery ? {'recovery': true, 'contextSeconds': contextSeconds} : null,
      );
      if (!_active || generation != _generation || (recovery && _stopping)) {
        return;
      }
      _snapshotRequestedAtUnixMs = null;
      final transcript = report == null && !recovery
          ? ''
          : _readReport(
              report,
              isRecovery: recovery,
              recoveryContextSeconds: contextSeconds,
            );
      // The response identifies the captured audio end at actual dispatch.
      if (recovery) _lastRecoveryAudioEnd = _audioEndSeconds;
      _onResult?.call(transcript, false);
    } on PlatformException catch (error) {
      if (_stopping && error.code == 'preview_cancelled') return;
      _fail(generation, error.code);
    } on FormatException catch (error) {
      debugPrint('Quran ASR preview rejected: $error');
      _fail(generation, 'quran_asr_invalid_result');
    }
  }

  @override
  Future<void> stop() {
    if (_finalizing != null) return _finalizing!;
    if (!_active) return Future.value();
    return _finalizing = _finish().whenComplete(() => _finalizing = null);
  }

  Future<void> _finish() async {
    final generation = _generation;
    _stopping = true;
    _poll?.cancel();
    try {
      // Stop the microphone immediately, even when a preview is still computing.
      await _channel.invokeMethod<void>('finishCapture');
      await _inFlight;
      if (!_active || generation != _generation) return;
      await _previewTail(generation);
      if (!_active || generation != _generation) return;
      final report = await _channel.invokeMapMethod<String, dynamic>('check');
      if (!_active || generation != _generation) return;
      final transcript = _readReport(report, isFinal: true);
      _active = false;
      _onResult?.call(transcript, true);
    } on PlatformException catch (error) {
      _fail(generation, error.code);
    } on FormatException catch (error) {
      debugPrint('Quran ASR final result rejected: $error');
      _fail(generation, 'quran_asr_invalid_result');
    } finally {
      if (generation == _generation) _stopping = false;
    }
  }

  /// Live previews can miss the last seconds before stop, and long final
  /// transcripts can truncate, so decode the trailing window once.
  Future<void> _previewTail(int generation) async {
    try {
      final report = await _channel.invokeMapMethod<String, dynamic>(
        'tailPreview',
        {'afterSeconds': _audioEndSeconds},
      );
      if (report == null || !_active || generation != _generation) return;
      _onResult?.call(_readReport(report), false);
    } on PlatformException catch (error) {
      debugPrint('Quran ASR tail preview skipped: ${error.code}');
    } on MissingPluginException {
      // Older native builds have no tail preview.
    } on FormatException {
      // An empty tail adds nothing before the final check.
    }
  }

  void _fail(int generation, String code) {
    if (generation != _generation) return;
    _active = false;
    _poll?.cancel();
    debugPrint('Quran ASR speech input failed: $code');
    _onError?.call(code);
  }

  @override
  Future<void> cancel() async {
    ++_generation;
    _active = false;
    _stopping = false;
    _poll?.cancel();
    _onResult = null;
    _onError = null;
    _channel.setMethodCallHandler(null);
    if (!quranAsrExperimentEnabled) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No registered lab engine has no recording to cancel.
    }
    await _inFlight;
    await _finalizing;
  }

  String _readReport(
    Map<String, dynamic>? report, {
    bool isFinal = false,
    bool isRecovery = false,
    int recoveryContextSeconds = 12,
  }) {
    if (report == null) {
      throw const FormatException('Missing Quran ASR report.');
    }
    final transcript = report['transcript'];
    final duration = report['durationSeconds'];
    final inference = report['inferenceSeconds'];
    final start = report['windowStartSeconds'];
    if (transcript is! String ||
        transcript.trim().isEmpty ||
        duration is! num ||
        !duration.isFinite ||
        duration <= 0 ||
        duration > 30 ||
        inference is! num ||
        !inference.isFinite ||
        inference < 0 ||
        start is! num ||
        !start.isFinite ||
        start < 0 ||
        (!isFinal &&
            (isRecovery
                ? report['recovery'] != true ||
                      report['contextSeconds'] is! int ||
                      report['contextSeconds'] != recoveryContextSeconds ||
                      duration > recoveryContextSeconds ||
                      !(start + duration).isFinite ||
                      start + duration + 0.5 / 16000 < _audioEndSeconds
                : (report['recovery'] != null && report['recovery'] != false) ||
                      report['contextSeconds'] != null ||
                      start < _ordinaryWindowStartSeconds))) {
      throw const FormatException('Invalid Quran ASR report.');
    }
    _windowStartSeconds = start.toDouble();
    _lastDurationSeconds = duration.toDouble();
    if (!isFinal) {
      final requestedAt = report['snapshotRequestedAtUnixMs'];
      if (requestedAt is num && requestedAt.isFinite && requestedAt > 0) {
        _snapshotRequestedAtUnixMs = requestedAt.toDouble();
      }
      if (!isRecovery) _ordinaryWindowStartSeconds = start.toDouble();
      final end = (start + duration).toDouble();
      if (end > _audioEndSeconds) _audioEndSeconds = end;
    }
    return transcript.trim();
  }
}
