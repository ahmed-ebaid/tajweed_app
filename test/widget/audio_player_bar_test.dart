import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tajweed_practice/core/services/audio_service.dart';
import 'package:tajweed_practice/features/reader/widgets/audio_player_bar.dart';

/// Stands in for [AudioService] without touching platform channels.
///
/// Dart's implicit interfaces let us `implements` the concrete service, so the
/// production class stays unchanged and keeps its private [AudioPlayer].
class _FakeAudioService implements AudioService {
  final posCtrl = StreamController<Duration>.broadcast();
  final durCtrl = StreamController<Duration?>.broadcast();
  final stateCtrl = StreamController<PlayerState>.broadcast();

  final List<Duration> seekCalls = [];

  @override
  Stream<Duration> get positionStream => posCtrl.stream;
  @override
  Stream<Duration?> get durationStream => durCtrl.stream;
  @override
  Stream<PlayerState> get playerStateStream => stateCtrl.stream;

  @override
  Future<void> seekTo(Duration position) async => seekCalls.add(position);

  @override
  bool get isPlaying => false;
  @override
  Duration? get duration => null;
  @override
  Duration get position => Duration.zero;

  @override
  Future<void> playUrl(String url) async {}
  @override
  Future<void> playUrls(List<String> urls) async {}
  @override
  Future<void> playFile(String path) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  void dispose() {
    posCtrl.close();
    durCtrl.close();
    stateCtrl.close();
  }
}

void main() {
  late _FakeAudioService fake;

  setUp(() => fake = _FakeAudioService());
  tearDown(() => fake.dispose());

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AudioPlayerBar(
          audioService: fake,
          label: 'Al-Fatihah 1:1',
          onClose: () {},
        ),
      ),
    ));
  }

  Slider slider(WidgetTester tester) =>
      tester.widget<Slider>(find.byType(Slider));

  testWidgets('scrubbing seeks the player to the released position',
      (tester) async {
    await pumpBar(tester);
    fake.durCtrl.add(const Duration(minutes: 2));
    fake.posCtrl.add(const Duration(seconds: 5));
    await tester.pump();

    // Drag to 30s, then let go.
    slider(tester).onChanged!(30000);
    await tester.pump();
    slider(tester).onChangeEnd!(30000);
    await tester.pump();

    expect(fake.seekCalls, [const Duration(seconds: 30)]);
  });

  testWidgets('elapsed label follows the thumb while dragging', (tester) async {
    await pumpBar(tester);
    fake.durCtrl.add(const Duration(minutes: 2));
    fake.posCtrl.add(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('00:05'), findsOneWidget);

    slider(tester).onChanged!(45000);
    await tester.pump();
    expect(find.text('00:45'), findsOneWidget);

    // The playhead keeps ticking mid-drag; the label must not snap back to it.
    fake.posCtrl.add(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text('00:45'), findsOneWidget);
    expect(find.text('00:06'), findsNothing);
  });

  testWidgets('releasing the thumb hands control back to the playhead',
      (tester) async {
    await pumpBar(tester);
    fake.durCtrl.add(const Duration(minutes: 2));
    fake.posCtrl.add(const Duration(seconds: 5));
    await tester.pump();

    slider(tester).onChanged!(45000);
    await tester.pump();
    slider(tester).onChangeEnd!(45000);
    await tester.pump();

    fake.posCtrl.add(const Duration(seconds: 46));
    await tester.pump();
    expect(find.text('00:46'), findsOneWidget);
  });

  testWidgets('slider is inert until the duration is known', (tester) async {
    await pumpBar(tester);
    await tester.pump();

    // No duration yet, so there is nothing to seek within.
    expect(slider(tester).onChanged, isNull);
    expect(slider(tester).value, 0);

    fake.durCtrl.add(const Duration(minutes: 2));
    await tester.pump();
    await tester.pump();
    expect(slider(tester).onChanged, isNotNull);
  });
}
