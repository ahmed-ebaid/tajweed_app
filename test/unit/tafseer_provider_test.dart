import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/providers/tafseer_provider.dart';

void main() {
  group('TafseerProvider.localizedTafsirName', () {
    test('returns localized names for known sources', () {
      expect(TafseerProvider.localizedTafsirName('ar', 16), 'التفسير الميسر');
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
        {'id': id, 'name': 'Arabic source $id', 'language_name': 'arabic'},
      {'id': 169, 'name': 'English source', 'language_name': 'english'},
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

  group('TafseerProvider Arabic catalogue', () {
    const jalalayn = <String, dynamic>{
      'id': 801,
      'name': 'Arabic Jalalayn Tafseer',
      'author_name': 'Jalal ad-Din al-Mahalli',
      'language_name': 'arabic',
    };
    final arabicSeven = <Map<String, dynamic>>[
      for (final id in [14, 15, 16, 90, 91, 93, 94])
        {'id': id, 'name': 'Source $id', 'language_name': 'arabic'},
    ];

    const tanweer = <String, dynamic>{
      'id': 802,
      'name': 'Arabic Tanweer Tafseer',
      'author_name': 'Muhammad al-Tahir ibn Ashur',
      'language_name': 'arabic',
    };

    test(
      'Arabic keeps every catalogue tafsir, Jalalayn and Tanweer included',
      () {
        final arabic = TafseerProvider.sourcesForLanguage([
          ...arabicSeven,
          jalalayn,
          tanweer,
        ], 'ar');
        expect(arabic, hasLength(9));
      },
    );

    test('Jalalayn and Tanweer get localized names despite unknown IDs', () {
      expect(
        TafseerProvider.sourceDisplayName('ar', jalalayn),
        'تفسير الجلالين',
      );
      expect(
        TafseerProvider.sourceDisplayName('ar', tanweer),
        'التحرير والتنوير (ابن عاشور)',
      );
      expect(
        TafseerProvider.sourceDisplayName('tr', jalalayn),
        'Celâleyn Tefsiri',
      );
      expect(
        TafseerProvider.displayNameFor('ar', 802, 'Arabic Tanweer Tafseer'),
        'التحرير والتنوير (ابن عاشور)',
      );
    });

    test('every Arabic entry has an Arabic name', () {
      final arabicLetters = RegExp(r'^[\u0600-\u06FF\s()]+$');
      for (final source in [...arabicSeven, jalalayn, tanweer]) {
        expect(
          TafseerProvider.sourceDisplayName('ar', source),
          matches(arabicLetters),
          reason: 'id ${source['id']}',
        );
      }
    });

    test(
      'other locales get their own name, not the English catalogue name',
      () {
        expect(
          TafseerProvider.sourceDisplayName('fr', {
            'id': 900,
            'name': 'Ibn Kathir (Abridged)',
          }),
          'Ibn Kathir (Abrégé)',
        );
      },
    );

    test('persisted English names are localized for the header', () {
      expect(
        TafseerProvider.displayNameFor('ar', 93, 'Al-Tafsir al-Wasit'),
        'التفسير الوسيط (الطنطاوي)',
      );
      expect(TafseerProvider.displayNameFor('en', 999, 'Custom'), 'Custom');
    });
  });
}
