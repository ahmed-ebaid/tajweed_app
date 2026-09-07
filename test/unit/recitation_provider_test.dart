import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tajweed_practice/core/providers/recitation_provider.dart';

/// Al-Husary (Muallim) — the teaching recitation used for ayah and surah
/// playback, and already the reciter behind the rules and article examples.
const _husaryMuallim = 12;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'recitation_provider_test_',
    );
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('defaults to Al-Husary (Muallim) when no reciter has been chosen', () {
    expect(RecitationProvider().selectedReciterId, _husaryMuallim);
  });

  test('preserves an explicitly chosen reciter', () async {
    await Hive.box('settings').put('reciter_id', 6);

    expect(RecitationProvider().selectedReciterId, 6);
  });

  test('replaces an unsupported saved reciter with the default', () async {
    await Hive.box('settings').put('reciter_id', 99);

    expect(RecitationProvider().selectedReciterId, _husaryMuallim);
    expect(Hive.box('settings').get('reciter_id'), _husaryMuallim);
  });

  test('the default reciter is one the app can actually play', () {
    expect(RecitationProvider.supportedReciterIds, contains(_husaryMuallim));
  });

  test('setReciter persists the choice', () async {
    final provider = RecitationProvider();

    await provider.setReciter(3);

    expect(provider.selectedReciterId, 3);
    expect(Hive.box('settings').get('reciter_id'), 3);
  });
}
