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

  group('TafseerProvider source presentation', () {
    final sources = <Map<String, dynamic>>[
      for (var id = 14; id < 20; id++)
        {
          'id': id,
          'name': 'Arabic source $id',
          'language_name': 'arabic',
        },
      {
        'id': 169,
        'name': 'English source',
        'language_name': 'english',
      },
    ];

    test('uses the same language filtering as Settings', () {
      final arabic = TafseerProvider.sourcesForLanguage(sources, 'ar');
      expect(arabic, hasLength(6));
      expect(
        arabic.every((source) => source['language_name'] == 'arabic'),
        isTrue,
      );
    });

    test('falls back to English and localizes known source names', () {
      final fallback = TafseerProvider.sourcesForLanguage(sources, 'es');
      expect(fallback.map((source) => source['id']), [169]);
      expect(
        TafseerProvider.sourceDisplayName('ar', sources.first),
        'تفسير ابن كثير',
      );
    });
  });
}
