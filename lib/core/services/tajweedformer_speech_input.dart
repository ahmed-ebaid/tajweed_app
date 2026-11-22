import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:quranlab_tajweedformer/quranlab_tajweedformer.dart';

import '../models/tajweed_models.dart';
import 'memorization_speech_service.dart';
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
      final session = await model.listen();
      if (generation != _generation) {
        unawaited(session.cancel().catchError((_) {}));
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
      rethrow;
    } catch (error) {
      debugPrint('TajweedFormer start failed: $error');
      throw const MemorizationSpeechException('tajweedformer_unavailable');
    }
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
        final heads = await session.finish();
        if (generation != _generation) return;
        TajweedDecoded? decoded;
        try {
          decoded = heads.decoded();
        } on TajweedError {
          decoded = _lastDecoded;
        }
        if (decoded != null) {
          _emitFinal(decoded);
        } else if (!_finalEmitted) {
          _finalEmitted = true;
          _onResult?.call('', true);
        }
      } on TajweedError catch (error) {
        if (_lastDecoded != null && generation == _generation) {
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
