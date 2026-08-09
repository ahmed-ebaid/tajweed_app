import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/providers/tafseer_provider.dart';

void main() {
  group('TafseerProvider.localizedTafsirName', () {
    test('returns localized names for known sources', () {
      expect(
        TafseerProvider.localizedTafsirName('ar', 16),
        'التفسير الميسر',
      );
      expect(
        TafseerProvider.localizedTafsirName('es', 169),
        'Ibn Kathir (Abreviado)',
      );
    });

    test('returns null for unknown languages, sources, and null IDs', () {
      expect(TafseerProvider.localizedTafsirName('xx', 169), isNull);
      expect(TafseerProvider.localizedTafsirName('en', 999), isNull);
      expect(TafseerProvider.localizedTafsirName('en', null), isNull);
    });
  });
}
