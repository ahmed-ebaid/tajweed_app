import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

abstract class MemorizationSpeechInput {
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    required void Function(String code) onError,
  });
  Future<void> stop();
  Future<void> cancel();
}

abstract interface class WindowedMemorizationSpeechInput
    implements MemorizationSpeechInput {
  double get windowStartSeconds;
}

class MemorizationSpeechException implements Exception {
  final String code;
  const MemorizationSpeechException(this.code);
}

/// The plugin initializes once; callbacks are routed to the active session.
class MemorizationSpeechService implements MemorizationSpeechInput {
  static final instance = MemorizationSpeechService();
  MemorizationSpeechService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  void Function()? _onDone;
  void Function(String)? _onError;
  Completer<bool>? _startSignal;
  bool _sessionStarted = false;
  var _generation = 0;

  @override
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    required void Function(String code) onError,
  }) async {
    final generation = ++_generation;
    _sessionStarted = false;
    final startSignal = Completer<bool>();
    _startSignal = startSignal;
    _onDone = onDone;
    _onError = onError;
    final available = await _speech.initialize(
      options: [SpeechToText.androidNoBluetooth],
      onStatus: (status) {
        if (status == SpeechToText.listeningStatus && _onDone != null) {
          _sessionStarted = true;
          if (!(_startSignal?.isCompleted ?? true)) {
            _startSignal!.complete(true);
          }
        }
        if (status == SpeechToText.doneStatus && _sessionStarted) {
          _sessionStarted = false;
          _onDone?.call();
        }
      },
      onError: (error) {
        if (!(_startSignal?.isCompleted ?? true)) _startSignal!.complete(false);
        _onError?.call(error.errorMsg);
      },
    );
    if (generation != _generation) return;
    if (!available) {
      throw const MemorizationSpeechException('speech_unavailable');
    }
    final locales = await _speech.locales();
    if (generation != _generation) return;
    final arabic = locales.where(
      (locale) =>
          locale.localeId.replaceAll('_', '-').startsWith('ar-') ||
          locale.localeId == 'ar',
    );
    if (arabic.isEmpty) {
      throw const MemorizationSpeechException('arabic_unavailable');
    }
    final locale = arabic.firstWhere(
      (locale) => locale.localeId.replaceAll('_', '-') == 'ar-SA',
      orElse: () => arabic.first,
    );
    try {
      await _speech.listen(
        onResult: (result) {
          if (generation == _generation) {
            _sessionStarted = true;
            if (!startSignal.isCompleted) startSignal.complete(true);
            onResult(result.recognizedWords, result.finalResult);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: locale.localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
          autoPunctuation: false,
        ),
      );
    } on ListenFailedException {
      throw const MemorizationSpeechException('listen_failed');
    }
    final started = await startSignal.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
    if (generation == _generation && !started) {
      throw const MemorizationSpeechException('listen_not_started');
    }
  }

  @override
  Future<void> stop() async {
    if (!_speech.isListening) {
      final done = _onDone;
      await cancel();
      done?.call();
      return;
    }
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    ++_generation;
    _sessionStarted = false;
    if (!(_startSignal?.isCompleted ?? true)) _startSignal!.complete(false);
    _onDone = null;
    _onError = null;
    await _speech.cancel();
  }
}
