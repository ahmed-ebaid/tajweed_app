import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/tajweedformer_speech_input.dart';

void main() {
  test('a shared take becomes 28 s WAV slots the diagnostics upload accepts', () {
    // 60 s of 16 kHz mono 16-bit audio, recorded after 3 s were dropped.
    final pcm = Uint8List(60 * 32000);
    final snapshots = TajweedFormerSpeechInput.takeSnapshots(
      pcm,
      startSeconds: 3,
      text: 'الرحمن الرحيم',
    );

    expect(snapshots.map((s) => s['slot']), [0, 1, 2]);
    final starts = [
      for (final s in snapshots)
        (jsonDecode(s['json']! as String) as Map)['windowStart'],
    ];
    expect(starts, [3.0, 31.0, 59.0]);
    final report =
        (jsonDecode(snapshots.first['json']! as String) as Map)['report']
            as Map;
    expect(report['transcript'], 'الرحمن الرحيم');

    for (final (i, s) in snapshots.indexed) {
      final wav = base64Decode(s['wav_base64']! as String);
      final header = ByteData.sublistView(wav);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(header.getUint32(24, Endian.little), 16000);
      final dataBytes = header.getUint32(40, Endian.little);
      expect(dataBytes, i < 2 ? 28 * 32000 : 4 * 32000);
      expect(wav.length, 44 + dataBytes);
      // The app skips WAVs over 1,000,000 bytes and the Worker base64 over 1.4M.
      expect(wav.length, lessThanOrEqualTo(1000000));
    }
  });
}
