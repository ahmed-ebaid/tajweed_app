import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';

void main() {
  test('canonicalizes shaddah before short vowels across multiple patterns',
      () {
    final cases = [
      (
        verseKey: '7:122',
        input: 'رَبِّ',
        expected: String.fromCharCodes([
          0x0631,
          0x064E,
          0x0628,
          0x0650,
          0x0651,
        ]),
      ),
      (
        verseKey: '1:1',
        input: 'رَبَّ',
        expected: String.fromCharCodes([
          0x0631,
          0x064E,
          0x0628,
          0x064E,
          0x0651,
        ]),
      ),
      (
        verseKey: '1:2',
        input: 'تَمُّ',
        expected: String.fromCharCodes([
          0x062A,
          0x064E,
          0x0645,
          0x064F,
          0x0651,
        ]),
      ),
      (
        verseKey: '1:3',
        input: 'حَقٍّ',
        expected: String.fromCharCodes([
          0x062D,
          0x064E,
          0x0642,
          0x064D,
          0x0651,
        ]),
      ),
    ];

    for (final testCase in cases) {
      final ayah = AyahMapper.fromApi({
        'verse_key': testCase.verseKey,
        'page_number': 1,
        'text_uthmani': '${testCase.input} آيَة',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': testCase.input,
          },
        ],
      });

      expect(
        ayah.words.first.arabic,
        testCase.expected,
        reason: 'word normalization should apply to ${testCase.verseKey}',
      );
      expect(
        ayah.arabic.startsWith(testCase.expected),
        isTrue,
        reason: 'verse normalization should apply to ${testCase.verseKey}',
      );
    }
  });

  test('preserves Quran-specific glyph forms instead of replacing them', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '7:8',
      'page_number': 151,
      'text_uthmani': 'مَوَٲزِينُهُ',
      'words': const [
        {
          'char_type_name': 'word',
          'text_uthmani': 'مَوَٲزِينُهُ',
        },
      ],
    });

    expect(ayah.arabic, 'مَوَٲزِينُهُ');
    expect(ayah.words.first.arabic, 'مَوَٲزِينُهُ');
  });

  test('applies the same normalization when mapping a verse list', () {
    final ayahs = AyahMapper.fromApiList([
      {
        'verse_key': '7:122',
        'page_number': 165,
        'text_uthmani': 'رَبِّ مُوسَىٰ',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'رَبِّ',
          },
          {
            'char_type_name': 'word',
            'text_uthmani': 'مُوسَىٰ',
          },
        ],
      },
      {
        'verse_key': '1:2',
        'page_number': 1,
        'text_uthmani': 'رَبَّ ٱلْعَٰلَمِينَ',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'رَبَّ',
          },
        ],
      },
    ]);

    expect(ayahs, hasLength(2));
    expect(ayahs[0].words.first.arabic.indexOf('\u0650'),
        lessThan(ayahs[0].words.first.arabic.indexOf('\u0651')));
    expect(ayahs[0].words.first.arabic.endsWith('\u0651'), isTrue);
    expect(ayahs[1].words.first.arabic.indexOf('\u064E'),
        lessThan(ayahs[1].words.first.arabic.indexOf('\u0651')));
    expect(ayahs[1].words.first.arabic.endsWith('\u0651'), isTrue);
  });

  test('handles cache-shaped dynamic maps without cast errors', () {
    final fromCacheLike = <String, dynamic>{
      'verse_key': '7:122',
      'page_number': 165,
      'text_uthmani': 'رَبِّ مُوسَىٰ',
      'words': [
        <dynamic, dynamic>{
          'char_type_name': 'word',
          'text_uthmani': 'رَبِّ',
        },
        <dynamic, dynamic>{
          'char_type_name': 'word',
          'text_uthmani': 'مُوسَىٰ',
        },
      ],
      'translations': [
        <dynamic, dynamic>{
          'resource_id': 131,
          'text': '<p>Lord of Moses</p>',
        }
      ],
    };

    final ayah = AyahMapper.fromApi(fromCacheLike);
    expect(ayah.words, hasLength(2));
    expect(ayah.translations['en'], 'Lord of Moses');
    expect(ayah.words.first.arabic.indexOf('\u0650'),
        lessThan(ayah.words.first.arabic.indexOf('\u0651')));
  });

  test('parses word text_uthmani_tajweed rule tags for word-level coloring', () {
    final ayah = AyahMapper.fromApi(
      {
        'verse_key': '7:142',
        'page_number': 168,
        'text_uthmani': 'وَوَٰعَدْنَا',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'وَوَٰعَدْنَا',
            'text_uthmani_tajweed':
                'وَو<rule class=madda_normal><rule class=custom-alef-maksora>ٰ</rule></rule>عَ<rule class=qalaqah>دۡ</rule>نَا',
          },
        ],
      },
      tajweedHtml:
          'وَو<tajweed class=madda_normal>َٲ</tajweed>عَ<tajweed class=qalaqah>دْ</tajweed>نَا',
    );

    expect(ayah.words, hasLength(1));
    expect(
      ayah.words.first.arabic,
      anyOf('وَوَٰعَدْنَا', 'وَوٰعَدۡنَا'),
    );
    expect(ayah.words.first.spans, isNotEmpty,
        reason: 'word-level spans prevent fallback to verse-level segment text');
    expect(
      ayah.words.first.spans.first.start,
      inInclusiveRange(0, ayah.words.first.arabic.length - 1),
    );
  });

  test('matches qalqalah span when rule text uses Quranic sukun variant', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '7:142',
      'page_number': 168,
      'text_uthmani': 'وَوَٰعَدْنَا',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'وَوَٰعَدْنَا',
          // Rule text uses U+06E1 (ۡ) while source word uses U+0652 (ْ).
          'text_uthmani_tajweed':
              'وَو<rule class=madda_normal>ٰ</rule>عَ<rule class=qalaqah>دۡ</rule>نَا',
        },
      ],
    });

    expect(ayah.words, hasLength(1));
    expect(
      ayah.words.first.spans.any((s) => s.rule.name == 'qalqalah'),
      isTrue,
    );
  });

  test('ghunnah span found when short vowel sits between consonant and shadda',
      () {
    // Word text_uthmani: فَتَمَّ (7:142 word 6).
    // After _normalizeArabicText, shadda+fatha → fatha+shadda so the meem
    // cluster is م + َ + ّ. The rule text مّ (meem+shadda only) must still
    // match via the flexible pass that skips intervening diacritics.
    final ayah = AyahMapper.fromApi({
      'verse_key': '7:142',
      'page_number': 168,
      'text_uthmani': 'فَتَمَّ',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'فَتَمَّ',
          'text_uthmani_tajweed':
              '<rule class=ikhafa>ف</rule>َتَ<rule class=ghunnah>مّ</rule>َ',
        },
      ],
    });

    expect(ayah.words, hasLength(1));
    final spans = ayah.words.first.spans;
    expect(spans.any((s) => s.rule.name == 'ikhfa'), isTrue,
        reason: 'ikhfa on ف should be found');
    expect(spans.any((s) => s.rule.name == 'ghunnah'), isTrue,
        reason: 'ghunnah on مّ must be found via flexible match');
  });

  test('span extends over trailing Quranic small marks (U+06ED, U+06E2)', () {
    // لَيْلَةًۭ — the ۭ (U+06ED small low meem) sits after the tanwin and must
    // be included in the idgham_ghunnah span rather than rendered separately.
    final ayah = AyahMapper.fromApi({
      'verse_key': '7:142',
      'page_number': 168,
      'text_uthmani': 'لَيْلَةًۭ',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'لَيْلَةًۭ',
          'text_uthmani_tajweed': 'لَيۡلَ<rule class=idgham_ghunnah>ةً</rule>',
        },
      ],
    });

    expect(ayah.words, hasLength(1));
    final spans = ayah.words.first.spans;
    expect(spans.any((s) => s.rule.name == 'idghamWithGhunnah'), isTrue);
    // end must cover the ۭ (U+06ED) that follows ةً
    final ghSpan =
        spans.firstWhere((s) => s.rule.name == 'idghamWithGhunnah');
    expect(ghSpan.end, equals(ayah.words.first.arabic.length),
        reason: 'span end should reach end of word including trailing ۭ');
  });
}
