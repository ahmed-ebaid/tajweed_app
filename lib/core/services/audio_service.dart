import 'dart:async' show unawaited;

import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;
  bool get isPlaying => _player.playing;
  Duration? get duration => _player.duration;
  Duration get position => _player.position;

  /// Load and play a verse audio URL.
  Future<void> playUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _player.stop();
      await _player.setUrl(url);
      unawaited(_player.play());
    } catch (e) {
      // URL not reachable — stop gracefully
      await stop();
    }
  }

  /// Play a locally recorded file.
  Future<void> playFile(String path) async {
    await _player.setFilePath(path);
    unawaited(_player.play());
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.play();
  Future<void> stop() async => _player.stop();

  Future<void> seekTo(Duration position) async =>
      _player.seek(position);

  /// Set playback speed (0.5 = slow, 1.0 = normal, 1.25 = fast).
  Future<void> setSpeed(double speed) async =>
      _player.setSpeed(speed.clamp(0.5, 2.0));

  void dispose() => _player.dispose();
}
