import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quranlab_tajweedformer/quranlab_tajweedformer.dart';
import 'package:record/record.dart';

import '../models/tajweed_models.dart';
import 'memorization_speech_service.dart';
import 'quran_asr_speech_input.dart';
import 'quranlab_sdk.dart';
import 'speech_comparison_service.dart';
import 'tajweed_recitation_aligner.dart';

/// The on-device recognizer for memorization. `tajweedformer` (default) uses
/// Quran Lab's TajweedFormer; `whisper` reverts to the Whisper lab engine:
/// `--dart-define=QURAN_ASR_ENGINE=whisper`.
const quranAsrEngine = String.fromEnvironment(
  'QURAN_ASR_ENGINE',
  defaultValue: 'tajweedformer',
);
const quranAsrUsesTajweedFormer = quranAsrEngine != 'whisper';

/// Test builds (`QURAN_ASR_RETAIN_DEBUG_AUDIO`) may upload TajweedFormer
/// takes, but only after the tester agrees in the sharing prompt.
const tajweedFormerTakeSharingAvailable =
    quranAsrUsesTajweedFormer && quranAsrRetainDebugAudio;

/// A speech input that needs the ayahs the learner is expected to recite.
abstract interface class ExpectedRecitationSpeechInput
    implements MemorizationSpeechInput {
  void expect(List<Ayah> ayahs);
}

/// Memorization input on TajweedFormer: the SDK hears the recitation and
/// reports phonetic units; they are aligned to the expected ayahs and given
/// to the screen as recitation words, which the app's comparison judges.
class TajweedFormerSpeechInput
    implements WindowedMemorizationSpeechInput, ExpectedRecitationSpeechInput {
  static const _maxExpectedAyahs = 40;
  static const _maxExpectedWords = 900;
  static const _sampleRate = 16000;
  static const _slotBytes = _sampleRate * 2 * 28;
  static const _maxSlots = 6;
  static const _settingsBox = 'settings';
  static const _sharingKey = 'tajweedformer_take_sharing';

  static Future<TajweedModel>? _model;
  static Future<void>? _referenceReady;
  static final _units = <String, List<List<int>>>{};
  static const _comparison = SpeechComparisonService();

  TajweedFormerSpeechInput() {
    unawaited(loadModel().then<void>((_) {}, onError: (_) {}));
  }

  /// Downloads the model ahead of the first take; safe at every launch.
  static Future<void> prefetch() async {
    try {
      final client = await QuranLabSdk.client();
      await client.prefetch();
    } catch (error) {
      debugPrint('TajweedFormer prefetch skipped: $error');
    }
  }

  /// The tester's answer to the sharing prompt; null before they answer.
  static bool? get takeSharing {
    if (!tajweedFormerTakeSharingAvailable || !Hive.isBoxOpen(_settingsBox)) {
      return null;
    }
    final value = Hive.box(_settingsBox).get(_sharingKey);
    return value is bool ? value : null;
  }

  static Future<void> setTakeSharing(bool share) async {
    if (!Hive.isBoxOpen(_settingsBox)) return;
    await Hive.box(_settingsBox).put(_sharingKey, share);
  }

  @visibleForTesting
  static Future<TajweedModel> loadModel() {
    return _model ??=
        () async {
          final client = await QuranLabSdk.client();
          return client.model();
        }().catchError((Object error, StackTrace stackTrace) {
          _model = null;
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  List<Ayah> _expected = const [];
  TajweedSession? _session;
  TajweedRecitationAligner? _aligner;
  StreamSubscription<TajweedChunk>? _chunks;
  StreamSubscription<TajweedEvent>? _events;
  Future<void>? _finishing;
  void Function(String, bool)? _onResult;
  void Function(String)? _onError;
  TajweedDecoded? _lastDecoded;
  String? _lastText;
  bool _finalEmitted = false;
  var _generation = 0;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audio;
  Completer<void>? _audioDone;
  Future<void> _pushing = Future.value();
  int? _carry;
  final _take = <Uint8List>[];
  var _takeBytes = 0;
  var _droppedBytes = 0;
  _SharedTake? _lastTake;

  @override
  double get windowStartSeconds => 0;

  @override
  void expect(List<Ayah> ayahs) {
    final expected = <Ayah>[];
    var words = 0;
    for (final ayah in ayahs) {
      if (expected.length >= _maxExpectedAyahs ||
          (expected.isNotEmpty && words >= _maxExpectedWords)) {
        break;
      }
      expected.add(ayah);
      words += ayah.words.length;
    }
    _expected = expected;
  }

  @override
  Future<void> start({
    required void Function(String, bool) onResult,
    required void Function() onDone,
    required void Function(String) onError,
  }) async {
    if (_session != null || _finishing != null) {
      throw const MemorizationSpeechException('tajweedformer_busy');
    }
    if (_expected.isEmpty) {
      throw const MemorizationSpeechException('tajweedformer_no_ayahs');
    }
    final generation = ++_generation;
    _onResult = onResult;
    _onError = onError;
    _lastDecoded = null;
    _lastText = null;
    _finalEmitted = false;
    try {
      final model = await loadModel();
      final aligner = await alignerFor(model, _expected);
      if (generation != _generation) return;
      final keepTake = takeSharing == true;
      final session = keepTake
          ? await _openRecordedSession(model, generation)
          : await model.listen();
      if (session == null) return;
      if (generation != _generation) {
        unawaited(session.cancel().catchError((_) {}));
        unawaited(_stopRecorder());
        return;
      }
      _session = session;
      _aligner = aligner;
      _chunks = session.chunks.listen(
        (chunk) => _onChunk(generation, chunk.decoded),
      );
      _events = session.events.listen((event) {
        if (event is TajweedEnded && event.error != null) {
          _fail(generation, event.error!.code);
        }
      });
    } on TajweedError catch (error) {
      debugPrint('TajweedFormer start failed: ${error.code} ${error.message}');
      throw MemorizationSpeechException('tajweedformer_${error.code}');
    } on MemorizationSpeechException {
      unawaited(_stopRecorder());
      rethrow;
    } catch (error) {
      unawaited(_stopRecorder());
      debugPrint('TajweedFormer start failed: $error');
      throw const MemorizationSpeechException('tajweedformer_unavailable');
    }
  }

  /// A take the app records itself so it can be shared: the microphone's
  /// 16 kHz samples go to an SDK push session and into the kept take.
  Future<TajweedSession?> _openRecordedSession(
    TajweedModel model,
    int generation,
  ) async {
    final recorder = AudioRecorder();
    _recorder = recorder;
    _take.clear();
    _takeBytes = 0;
    _droppedBytes = 0;
    _carry = null;
    _pushing = Future.value();
    _lastTake = null;
    if (!await recorder.hasPermission()) {
      throw const MemorizationSpeechException(
        'tajweedformer_microphone_denied',
      );
    }
    if (generation != _generation) {
      await _stopRecorder();
      return null;
    }
    final session = await model.session();
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
        iosConfig: IosRecordConfig(
          allowHapticsAndSystemSoundsDuringRecording: true,
        ),
      ),
    );
    final done = _audioDone = Completer<void>();
    _audio = stream.listen(
      (bytes) => _onAudio(session, generation, bytes),
      onError: (Object error) => debugPrint('TajweedFormer audio: $error'),
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    return session;
  }

  void _onAudio(TajweedSession session, int generation, Uint8List bytes) {
    if (generation != _generation) return;
    final carry = _carry;
    final data = carry == null
        ? bytes
        : (Uint8List(bytes.length + 1)
            ..[0] = carry
            ..setRange(1, bytes.length + 1, bytes));
    final even = data.length & ~1;
    _carry = even < data.length ? data[even] : null;
    if (even == 0) return;
    final pcm = Uint8List.sublistView(data, 0, even).sublist(0);
    _take.add(pcm);
    _takeBytes += pcm.length;
    while (_takeBytes > _slotBytes * _maxSlots && _take.length > 1) {
      final dropped = _take.removeAt(0);
      _takeBytes -= dropped.length;
      _droppedBytes += dropped.length;
    }
    final samples = pcm.buffer.asInt16List(0, pcm.length ~/ 2);
    _pushing = _pushing.then((_) => session.pushInt16(samples)).catchError((
      Object error,
    ) {
      debugPrint('TajweedFormer push: $error');
    });
  }

  /// Stops the app's microphone and waits until every sample reached the SDK.
  Future<void> _stopRecorder() async {
    final recorder = _recorder;
    if (recorder == null) return;
    _recorder = null;
    try {
      await recorder.stop();
    } catch (error) {
      debugPrint('TajweedFormer recorder stop: $error');
    }
    await _audioDone?.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () {},
    );
    await _audio?.cancel();
    _audio = null;
    _audioDone = null;
    await _pushing;
    unawaited(recorder.dispose().catchError((_) {}));
  }

  void _keepTake(TajweedDecoded? decoded, String? text) {
    if (_take.isEmpty) return;
    final pcm = BytesBuilder(copy: false);
    for (final chunk in _take) {
      pcm.add(chunk);
    }
    _lastTake = _SharedTake(
      pcm: pcm.takeBytes(),
      startSeconds: _droppedBytes / (_sampleRate * 2),
      expected: [
        for (final ayah in _expected) '${ayah.surahNumber}:${ayah.ayahNumber}',
      ],
      text: text ?? '',
      tokens: decoded?.tokens ?? const [],
    );
    _take.clear();
    _takeBytes = 0;
  }

  @visibleForTesting
  static List<Map<String, Object>> takeSnapshots(
    Uint8List pcm, {
    double startSeconds = 0,
    String text = '',
  }) => _SharedTake(
    pcm: pcm,
    startSeconds: startSeconds,
    expected: const [],
    text: text,
    tokens: const [],
  ).snapshots();

  /// Sends the last take the tester agreed to share; false when there is
  /// none or the upload failed.
  Future<bool> uploadSharedTake({required String verseKey}) async {
    final take = _lastTake;
    _lastTake = null;
    if (take == null || takeSharing != true) return false;
    return QuranAsrSpeechInput.uploadBundleToCloud(
      id: take.id,
      verseKey: verseKey,
      diagnosticsJsonl: take.diagnosticsJsonl,
      snapshots: take.snapshots(),
    );
  }

  @visibleForTesting
  static Future<TajweedRecitationAligner> alignerFor(
    TajweedModel model,
    List<Ayah> ayahs,
  ) async {
    final reference = model.reference;
    if (reference == null) {
      throw const MemorizationSpeechException('tajweedformer_no_reference');
    }
    await (_referenceReady ??= reference.fetch().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _referenceReady = null;
      Error.throwWithStackTrace(error, stackTrace);
    }));
    final wordBar = model.tokens.wordBar ?? TajweedRecitationAligner.wordBar;
    final expected = await Future.wait([
      for (final ayah in ayahs)
        () async {
          final key = '${ayah.surahNumber}:${ayah.ayahNumber}';
          final words = _units[key] ??= await () async {
            final units = await reference.units(
              ayah.surahNumber,
              ayah.ayahNumber,
            );
            return TajweedExpectedAyah.splitUnits(
              units.units,
              units.wordStarts,
              wordBar: wordBar,
            );
          }();
          return TajweedExpectedAyah(
            referenceWords: words,
            textWords: _comparison.recitationWords(ayah.imlaei ?? ''),
          );
        }(),
    ]);
    return TajweedRecitationAligner(expected);
  }

  void _onChunk(int generation, TajweedDecoded decoded) {
    if (generation != _generation || _finalEmitted) return;
    _lastDecoded = decoded;
    if (decoded.isFinal) {
      if (!_finalEmitted) _keepTake(decoded, _align(decoded, isFinal: true));
      _emitFinal(decoded);
      return;
    }
    final text = _align(decoded, isFinal: false);
    if (text == _lastText) return;
    _lastText = text;
    _onResult?.call(text, false);
  }

  String _align(TajweedDecoded decoded, {required bool isFinal}) {
    final aligner = _aligner;
    if (aligner == null) return '';
    return alignDecoded(aligner, decoded, isFinal: isFinal);
  }

  /// The take so far as the expected ayahs' words.
  @visibleForTesting
  static String alignDecoded(
    TajweedRecitationAligner aligner,
    TajweedDecoded decoded, {
    required bool isFinal,
  }) {
    final heard = <int>[];
    var settledUnits = 0;
    for (var i = 0; i < decoded.tokens.length; i++) {
      final id = decoded.tokens[i].id;
      if (id == TajweedRecitationAligner.blank ||
          id == TajweedRecitationAligner.wordBar) {
        continue;
      }
      heard.add(id);
      if (i < decoded.settled) settledUnits = heard.length;
    }
    return aligner.align(heard, isFinal: isFinal, settledUnits: settledUnits);
  }

  void _emitFinal(TajweedDecoded decoded) {
    if (_finalEmitted) return;
    _finalEmitted = true;
    _onResult?.call(_align(decoded, isFinal: true), true);
  }

  void _fail(int generation, String code) {
    if (generation != _generation || _finalEmitted) return;
    _finalEmitted = true;
    _onError?.call('tajweedformer_$code');
    unawaited(cancel());
  }

  @override
  Future<void> stop() {
    if (_finishing != null) return _finishing!;
    final session = _session;
    if (session == null) return Future.value();
    final generation = _generation;
    return _finishing = () async {
      try {
        await _stopRecorder();
        final heads = await session.finish();
        if (generation != _generation) return;
        TajweedDecoded? decoded;
        try {
          decoded = heads.decoded();
        } on TajweedError {
          decoded = _lastDecoded;
        }
        if (decoded != null) {
          _keepTake(decoded, _align(decoded, isFinal: true));
          _emitFinal(decoded);
        } else if (!_finalEmitted) {
          _finalEmitted = true;
          _onResult?.call('', true);
        }
      } on TajweedError catch (error) {
        if (_lastDecoded != null && generation == _generation) {
          _keepTake(_lastDecoded, _lastText);
          _emitFinal(_lastDecoded!);
        } else {
          _fail(generation, error.code);
        }
      } finally {
        if (generation == _generation) _release();
      }
    }().whenComplete(() => _finishing = null);
  }

  @override
  Future<void> cancel() async {
    _generation++;
    final session = _session;
    final recorded = _recorder != null;
    await _stopRecorder();
    if (recorded && _lastTake == null) _keepTake(_lastDecoded, _lastText);
    _release();
    if (session != null) {
      try {
        await session.cancel();
      } on TajweedError catch (error) {
        debugPrint('TajweedFormer cancel: ${error.code}');
      }
    }
  }

  void _release() {
    unawaited(_chunks?.cancel());
    unawaited(_events?.cancel());
    _chunks = null;
    _events = null;
    _session = null;
    _aligner = null;
  }
}

/// A take kept for sharing: the last 168 s at most, as six 28 s WAV slots.
class _SharedTake {
  _SharedTake({
    required this.pcm,
    required this.startSeconds,
    required this.expected,
    required this.text,
    required this.tokens,
  }) : id = _uuid();

  final String id;
  final Uint8List pcm;
  final double startSeconds;
  final List<String> expected;
  final String text;
  final List<TajweedToken> tokens;

  static String _uuid() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  double get seconds => pcm.length / 32000;

  String get diagnosticsJsonl =>
      '${jsonEncode({
        'event': 'tajweedformer_take',
        'expected': expected,
        'startSeconds': startSeconds,
        'durationSeconds': seconds,
        'text': text,
        'units': tokens.map((t) => t.name).join(' '),
        'tokens': [
          for (final t in tokens) {'id': t.id, 'name': t.name, 'firstMs': t.firstMs, 'lastMs': t.lastMs},
        ],
      })}\n';

  List<Map<String, Object>> snapshots() {
    const slotBytes = 16000 * 2 * 28;
    final result = <Map<String, Object>>[];
    for (var slot = 0; slot * slotBytes < pcm.length && slot < 6; slot++) {
      final start = slot * slotBytes;
      final end = min(start + slotBytes, pcm.length);
      final windowStart = startSeconds + start / 32000;
      final windowEnd = startSeconds + end / 32000;
      final heard = [
        for (final t in tokens)
          if (t.firstMs >= windowStart * 1000 && t.firstMs < windowEnd * 1000)
            t.name,
      ];
      result.add({
        'slot': slot,
        'json': jsonEncode({
          'engine': 'tajweedformer',
          'windowStart': windowStart,
          'durationSeconds': (end - start) / 32000,
          'report': {'transcript': text, 'units': heard.join(' ')},
        }),
        'wav_base64': base64Encode(
          _wav(Uint8List.sublistView(pcm, start, end)),
        ),
      });
    }
    return result;
  }

  static Uint8List _wav(Uint8List pcm) {
    final header = ByteData(44);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 32000, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return (BytesBuilder()
          ..add(header.buffer.asUint8List())
          ..add(pcm))
        .takeBytes();
  }
}
