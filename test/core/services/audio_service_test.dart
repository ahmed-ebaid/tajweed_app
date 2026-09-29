import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tajweed_practice/core/services/audio_service.dart';

class _FailingPlayer implements AudioPlayer {
  _FailingPlayer({this.expectedStopCalls = 2});

  final int expectedStopCalls;
  final Completer<void> failedPlaybackStopped = Completer<void>();
  int stopCalls = 0;

  @override
  Future<void> play() async {
    throw PlatformException(
      code: '560557684',
      message: 'Session activation failed',
    );
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopCalls == expectedStopCalls) failedPlaybackStopped.complete();
  }

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async => const Duration(seconds: 1);

  @override
  Future<Duration?> setFilePath(
    String filePath, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async => const Duration(seconds: 1);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'session activation failure does not escape background playback',
    () async {
      final player = _FailingPlayer();
      final service = AudioService(player: player);
      final errors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await service.playUrl('https://example.com/ayah.mp3');
        await player.failedPlaybackStopped.future;
        expect(player.stopCalls, 2);
        expect(errors, hasLength(1));
        expect(errors.single.exception, isA<PlatformException>());
      } finally {
        FlutterError.onError = previousHandler;
      }
    },
  );

  test('session activation failure on resume is handled', () async {
    final player = _FailingPlayer(expectedStopCalls: 1);
    final service = AudioService(player: player);
    final errors = <FlutterErrorDetails>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await service.resume();
      expect(player.stopCalls, 1);
      expect(errors, hasLength(1));
    } finally {
      FlutterError.onError = previousHandler;
    }
  });

  test(
    'session activation failure while playing cached audio is handled',
    () async {
      final player = _FailingPlayer(expectedStopCalls: 1);
      final service = AudioService(player: player);
      final errors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await service.playFile('/tmp/ayah.mp3');
        await player.failedPlaybackStopped.future;
        expect(errors, hasLength(1));
      } finally {
        FlutterError.onError = previousHandler;
      }
    },
  );
}
