import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';

void main() {
  test(
    'canonicalizes shaddah before short vowels across multiple patterns',
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
            {'char_type_name': 'word', 'text_uthmani': testCase.input},
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
    },
  );

  test('preserves Quran-specific glyph forms instead of replacing them', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '7:8',
      'page_number': 151,
      'text_uthmani': 'مَوَٲزِينُهُ',
      'words': const [
        {'char_type_name': 'word', 'text_uthmani': 'مَوَٲزِينُهُ'},
      ],
    });

    expect(ayah.arabic, 'مَوَٲزِينُهُ');
    expect(ayah.words.first.arabic, 'مَوَٲزِينُهُ');
  });

  test('maps Mushaf division metadata', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '18:1',
      'page_number': 293,
      'juz_number': 15,
      'hizb_number': 30,
      'rub_el_hizb_number': 119,
      'sajdah_number': 4,
      'text_uthmani': 'نَصٌّ',
      'words': const [
        {'char_type_name': 'word', 'text_uthmani': 'نَصٌّ', 'line_number': 10},
        {'char_type_name': 'end', 'text_uthmani': '١', 'line_number': 11},
      ],
    });

    expect(ayah.juzNumber, 15);
    expect(ayah.hizbNumber, 30);
    expect(ayah.rubElHizbNumber, 119);
    expect(ayah.sajdahNumber, 4);
    expect(ayah.endLineNumber, 11);
  });

  test('applies the same normalization when mapping a verse list', () {
    final ayahs = AyahMapper.fromApiList([
      {
        'verse_key': '7:122',
        'page_number': 165,
        'text_uthmani': 'رَبِّ مُوسَىٰ',
        'words': [
          {'char_type_name': 'word', 'text_uthmani': 'رَبِّ'},
          {'char_type_name': 'word', 'text_uthmani': 'مُوسَىٰ'},
        ],
      },
      {
        'verse_key': '1:2',
        'page_number': 1,
        'text_uthmani': 'رَبَّ ٱلْعَٰلَمِينَ',
        'words': [
          {'char_type_name': 'word', 'text_uthmani': 'رَبَّ'},
        ],
      },
    ]);

    expect(ayahs, hasLength(2));
    expect(
      ayahs[0].words.first.arabic.indexOf('\u0650'),
      lessThan(ayahs[0].words.first.arabic.indexOf('\u0651')),
    );
    expect(ayahs[0].words.first.arabic.endsWith('\u0651'), isTrue);
    expect(
      ayahs[1].words.first.arabic.indexOf('\u064E'),
      lessThan(ayahs[1].words.first.arabic.indexOf('\u0651')),
    );
    expect(ayahs[1].words.first.arabic.endsWith('\u0651'), isTrue);
  });

  test('handles cache-shaped dynamic maps without cast errors', () {
    final fromCacheLike = <String, dynamic>{
      'verse_key': '7:122',
      'page_number': 165,
      'text_uthmani': 'رَبِّ مُوسَىٰ',
      'words': [
        <dynamic, dynamic>{'char_type_name': 'word', 'text_uthmani': 'رَبِّ'},
        <dynamic, dynamic>{'char_type_name': 'word', 'text_uthmani': 'مُوسَىٰ'},
      ],
      'translations': [
        <dynamic, dynamic>{'resource_id': 85, 'text': '<p>Lord of Moses</p>'},
      ],
    };

    final ayah = AyahMapper.fromApi(fromCacheLike);
    expect(ayah.words, hasLength(2));
    expect(ayah.translations['en'], 'Lord of Moses');
    expect(
      ayah.words.first.arabic.indexOf('\u0650'),
      lessThan(ayah.words.first.arabic.indexOf('\u0651')),
    );
  });

  test('does not present concatenated word glosses as a verse translation', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '1:1',
      'text_uthmani': 'بِسْمِ ٱللَّهِ',
      'words': const [
        {
          'char_type_name': 'word',
          'text_uthmani': 'بِسْمِ',
          'translation': {'text': 'In (the) name'},
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'ٱللَّهِ',
          'translation': {'text': '(of) Allah'},
        },
      ],
    }, requestedLangCode: 'ar');

    expect(ayah.translations, isEmpty);
    expect(ayah.translation('ar'), isEmpty);
  });

  test(
    'Arabic interface falls back to the requested English verse translation',
    () {
      final ayah = AyahMapper.fromApi({
        'verse_key': '1:1',
        'text_uthmani': 'بِسْمِ ٱللَّهِ',
        'translations': const [
          {
            'resource_id': 85,
            'text':
                'In the name of God, the Lord of Mercy, the Giver of Mercy!',
          },
        ],
        'words': const [],
      }, requestedLangCode: 'ar');

      expect(
        ayah.translation('ar'),
        'In the name of God, the Lord of Mercy, the Giver of Mercy!',
      );
    },
  );

  test('classifies madd silah sughra in Al-Kahf 18:5', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '18:5',
      'page_number': 294,
      'text_uthmani': 'مَا لَهُم بِهِۦ مِنْ عِلْمٍ',
      'words': const [
        {'char_type_name': 'word', 'text_uthmani': 'بِهِۦ', 'line_number': 7},
        {'char_type_name': 'word', 'text_uthmani': 'مِنْ'},
      ],
    });

    expect(
      ayah.words.first.spans.any(
        (span) => span.rule == TajweedRule.maddSilahSughra,
      ),
      isTrue,
    );
    expect(ayah.words.first.lineNumber, 7);
  });

  test('classifies madd silah kubra before hamza', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '2:255',
      'page_number': 42,
      'text_uthmani': 'عِندَهُۥٓ إِلَّا',
      'words': const [
        {'char_type_name': 'word', 'text_uthmani': 'عِندَهُۥٓ'},
        {'char_type_name': 'word', 'text_uthmani': 'إِلَّا'},
      ],
    });

    expect(
      ayah.words.first.spans.any(
        (span) => span.rule == TajweedRule.maddSilahKubra,
      ),
      isTrue,
    );
  });

  test(
    'aligns Madd Muttasil with the tagged occurrence in Al-Baqarah 2:170',
    () {
      final ayah = AyahMapper.fromApi({
        'verse_key': '2:170',
        'page_number': 26,
        'text_uthmani': 'ءَابَآءَنَآ',
        'words': const [
          {
            'char_type_name': 'word',
            'text_uthmani': 'ءَابَآءَنَآ',
            'text_uthmani_tajweed':
                'ءَاب<rule class=madda_obligatory_mottasel>َا</rule>ٓءَن'
                '<rule class=madda_obligatory_monfasel>َآ</rule>',
          },
        ],
      });

      final word = ayah.words.single;
      final muttasil = word.spans.singleWhere(
        (span) => span.rule == TajweedRule.maddMuttasil,
      );

      // The span must start on the alif itself, not on the fatha that renders
      // on the preceding ba — highlighting that fatha tints a letter outside
      // the rule (the same defect that coloured the dad in الضآلين).
      const alifMaddah = '\u0627\u0653';
      expect(word.arabic.substring(muttasil.start, muttasil.end), alifMaddah);
      expect(muttasil.start, word.arabic.indexOf(alifMaddah));
      expect(
        word.arabic.codeUnitAt(muttasil.start - 1),
        0x064E,
        reason: 'the excluded fatha renders on the preceding ba',
      );
      expect(
        muttasil.start,
        greaterThan(word.arabic.indexOf('ءَا')),
        reason: 'the initial Madd Badal must not be mislabeled as Muttasil',
      );
    },
  );

  test('corrects cross-word Madd in Al-Kahf 18:21 to Munfasil', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '18:21',
      'page_number': 296,
      'text_uthmani': 'لِيَعْلَمُوٓا۟ أَنَّ',
      'words': const [
        {
          'char_type_name': 'word',
          'text_uthmani': 'لِيَعْلَمُوٓا۟',
          'text_uthmani_tajweed':
              'لِيَعۡلَم<rule class=madda_obligatory_mottasel>ُوٓ</rule>'
              '<rule class=slnt>اۡ</rule>',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'أَنَّ',
          'text_uthmani_tajweed': 'أَ<rule class=ghunnah>نّ</rule>َ',
        },
      ],
    });

    final maddSpans = ayah.words.first.spans.where(
      (span) =>
          span.rule == TajweedRule.maddMuttasil ||
          span.rule == TajweedRule.maddMunfasil,
    );

    expect(maddSpans, hasLength(1));
    expect(maddSpans.single.rule, TajweedRule.maddMunfasil);
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
    expect(ayah.words.first.arabic, anyOf('وَوَٰعَدْنَا', 'وَوٰعَدۡنَا'));
    expect(
      ayah.words.first.spans,
      isNotEmpty,
      reason: 'word-level spans prevent fallback to verse-level segment text',
    );
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

  test(
    'ghunnah span found when short vowel sits between consonant and shadda',
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
      expect(
        spans.any((s) => s.rule.name == 'ikhfa'),
        isTrue,
        reason: 'ikhfa on ف should be found',
      );
      expect(
        spans.any((s) => s.rule.name == 'ghunnah'),
        isTrue,
        reason: 'ghunnah on مّ must be found via flexible match',
      );
    },
  );

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
    final ghSpan = spans.firstWhere((s) => s.rule.name == 'idghamWithGhunnah');
    expect(
      ghSpan.end,
      equals(ayah.words.first.arabic.length),
      reason: 'span end should reach end of word including trailing ۭ',
    );
  });

  test('does not shift tajweed when end token is clean (Case 1)', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '1:3',
      'page_number': 1,
      'text_uthmani': 'أ ب',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'أ',
          'text_uthmani_tajweed': 'أ',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'ب',
          'text_uthmani_tajweed': 'ب',
        },
        {
          'char_type_name': 'end',
          'text': '٣',
          'text_uthmani': '٣',
          'text_uthmani_tajweed': '٣',
        },
      ],
    });

    expect(ayah.words, hasLength(2));
    expect(ayah.words.map((w) => w.arabic).toList(), ['أ', 'ب']);
  });

  test(
    'does not shift clean production words when end text is a QCF glyph',
    () {
      final ayah = AyahMapper.fromApi({
        'verse_key': '112:1',
        'page_number': 604,
        'text_uthmani': 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
        'words': [
          {
            'char_type_name': 'word',
            'text': 'ﱁ',
            'text_uthmani': 'قُلْ',
            'text_uthmani_tajweed': 'قُلۡ',
          },
          {
            'char_type_name': 'word',
            'text': 'ﱂ',
            'text_uthmani': 'هُوَ',
            'text_uthmani_tajweed': 'هُوَ',
          },
          {
            'char_type_name': 'word',
            'text': 'ﱃ',
            'text_uthmani': 'ٱللَّهُ',
            'text_uthmani_tajweed': 'ٱللَّهُ',
          },
          {
            'char_type_name': 'word',
            'text': 'ﱄ',
            'text_uthmani': 'أَحَدٌ',
            'text_uthmani_tajweed': 'أَحَدٌ',
          },
          {
            'char_type_name': 'end',
            'text': 'ﱅ',
            'text_uthmani': '١',
            'text_uthmani_tajweed': '١',
          },
        ],
      });

      expect(ayah.words.map((word) => word.arabic).toList(), [
        'قُلۡ',
        'هُوَ',
        'ٱللَّهُ',
        'أَحَدٌ',
      ]);
    },
  );

  test('realigns word tajweed from end token in shifted Case 2', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '8:6',
      'page_number': 177,
      'text_uthmani': 'أ ب',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'أ',
          'text_uthmani_tajweed': 'x',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'ب',
          'text_uthmani_tajweed': 'أ',
        },
        {
          'char_type_name': 'end',
          'text': '٦',
          'text_uthmani': '٦',
          'text_uthmani_tajweed': 'ب',
        },
      ],
    });

    expect(
      ayah.words,
      hasLength(2),
      reason: 'end token should not render as a word',
    );
    expect(ayah.words.map((w) => w.arabic).toList(), ['أ', 'ب']);
  });

  test('does not over-apply shift across clean multi-word ayah', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '2:10',
      'page_number': 2,
      'text_uthmani': 'alpha beta gamma',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'alpha',
          'text_uthmani_tajweed': 'alpha',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'beta',
          'text_uthmani_tajweed': 'beta',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'gamma',
          'text_uthmani_tajweed': 'gamma',
        },
        {
          'char_type_name': 'end',
          'text': '١٠',
          'text_uthmani': '١٠',
          'text_uthmani_tajweed': '١٠',
        },
      ],
    });

    expect(ayah.words, hasLength(3));
    expect(
      ayah.words.map((w) => w.arabic).toList(),
      ['alpha', 'beta', 'gamma'],
      reason: 'Clean end token must not trigger reassignment.',
    );
  });

  test('shifted case reassigns each word from next token through last word', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '8:6',
      'page_number': 177,
      'text_uthmani': 'w1 w2 w3 w4',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'w1',
          'text_uthmani_tajweed': 'junk',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'w2',
          'text_uthmani_tajweed': 'A',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'w3',
          'text_uthmani_tajweed': 'B',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'w4',
          'text_uthmani_tajweed': 'C',
        },
        {
          'char_type_name': 'end',
          'text': '٦',
          'text_uthmani': '٦',
          'text_uthmani_tajweed': 'D',
        },
      ],
    });

    expect(
      ayah.words,
      hasLength(4),
      reason: 'End token should never be rendered as a word.',
    );
    expect(
      ayah.words.map((w) => w.arabic).toList(),
      ['A', 'B', 'C', 'D'],
      reason:
          'Word tajweed text must shift one position and end token fills last real word.',
    );
  });

  test(
    'preserves sajdah end marker word when end token carries sajdah glyph',
    () {
      final ayah = AyahMapper.fromApi({
        'verse_key': '7:206',
        'page_number': 176,
        'text_uthmani': 'واسجد۩',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'واسجد',
            'text_uthmani_tajweed': 'واسجد',
          },
          {
            'char_type_name': 'end',
            'text': '۩',
            'text_uthmani': '۩',
            // Simulates shifted/corrupted tajweed payload on end token.
            'text_uthmani_tajweed': 'payload-from-previous-word',
          },
        ],
      });

      expect(
        ayah.words,
        hasLength(2),
        reason: 'Sajdah end marker should be preserved as a renderable token.',
      );
      expect(ayah.words.last.arabic.contains('\u06E9'), isTrue);
      expect(
        ayah.words.last.spans.any((s) => s.rule.name == 'sajdah'),
        isTrue,
        reason: 'Sajdah glyph should be annotated with TajweedRule.sajdah.',
      );
    },
  );

  test(
    'deduplicates sajdah marker when both word and end token contain it',
    () {
      final ayah = AyahMapper.fromApi({
        'verse_key': '7:206',
        'page_number': 176,
        'text_uthmani': 'واسجد۩',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'واسجد۩',
            'text_uthmani_tajweed': 'واسجد۩',
          },
          {
            'char_type_name': 'end',
            'text': '۩',
            'text_uthmani': '۩',
            'text_uthmani_tajweed': '۩',
          },
        ],
      });

      expect(
        ayah.words,
        hasLength(1),
        reason: 'Duplicate end-token sajdah should be dropped.',
      );
      expect(
        ayah.words
            .expand((w) => w.arabic.runes)
            .where((r) => r == 0x06E9)
            .length,
        equals(1),
        reason: 'Mapped words should contain exactly one sajdah glyph.',
      );
      expect(
        ayah.words.first.spans.any((s) => s.rule.name == 'sajdah'),
        isTrue,
        reason: 'The remaining sajdah glyph should remain annotated.',
      );
    },
  );

  test('does not drop first word on sajdah end-token marker (16:50)', () {
    final ayah = AyahMapper.fromApi({
      'verse_key': '16:50',
      'page_number': 272,
      'text_uthmani': 'يَخَافُونَ رَبَّهُم مِّن فَوْقِهِمْ',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'يَخَافُونَ',
          'text_uthmani_tajweed': 'يَخَافُونَ',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'رَبَّهُم',
          'text_uthmani_tajweed': 'رَبَّهُم',
        },
        {
          'char_type_name': 'word',
          'text_uthmani': 'مِّن',
          'text_uthmani_tajweed': 'مِّن',
        },
        {
          'char_type_name': 'end',
          'text': '٥٠',
          'text_uthmani': '٥٠',
          'text_uthmani_tajweed': '۩',
        },
      ],
    });

    expect(ayah.words, isNotEmpty);
    expect(
      ayah.words.first.arabic,
      'يَخَافُونَ',
      reason:
          'Sajdah end-token markers must not trigger shift-fix and hide the first word.',
    );
  });

  test(
    'all sajdah ayahs preserve first word with sajdah end marker payload',
    () {
      const sajdahKeys = [
        '7:206',
        '13:15',
        '16:50',
        '17:109',
        '19:58',
        '22:18',
        '22:77',
        '25:60',
        '27:26',
        '32:15',
        '38:24',
        '41:38',
        '53:62',
        '84:21',
        '96:19',
      ];

      for (final key in sajdahKeys) {
        final firstWord = 'WORD_${key.replaceAll(':', '_')}';
        final ayah = AyahMapper.fromApi({
          'verse_key': key,
          'page_number': 1,
          'text_uthmani': '$firstWord باقي',
          'words': [
            {
              'char_type_name': 'word',
              'text_uthmani': firstWord,
              'text_uthmani_tajweed': firstWord,
            },
            {
              'char_type_name': 'word',
              'text_uthmani': 'باقي',
              'text_uthmani_tajweed': 'باقي',
            },
            {
              'char_type_name': 'end',
              'text': '١',
              'text_uthmani': '١',
              // Simulates sajdah marker-based end token payload pattern.
              'text_uthmani_tajweed': '۩',
            },
          ],
        });

        expect(
          ayah.words.first.arabic,
          firstWord,
          reason: 'First word must remain intact for sajdah ayah $key',
        );
      }
    },
  );

  test('15:72 يعمهون highlights only the waw as madd arid lissukun', () {
    // Upstream marks this span as `madda_permissible` and starts it on the
    // dammah, which belongs to the preceding ha. The span must be trimmed to
    // cover the waw alone, and classified as madd arid lissukun (not tabeei).
    final ayah = AyahMapper.fromApi({
      'verse_key': '15:72',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'يَعْمَهُونَ',
          'text_uthmani_tajweed':
              'يَعْمَه<rule class=madda_permissible>ُو</rule>نَ',
        },
      ],
    });

    final word = ayah.words.first;
    final spans = word.spans
        .where((s) => s.rule == TajweedRule.maddAridLissukun)
        .toList();

    expect(spans, hasLength(1));
    expect(
      word.arabic.substring(spans.first.start, spans.first.end),
      '\u0648',
      reason: 'Only the waw may be highlighted, never the preceding ha',
    );
    expect(
      word.spans.any((s) => s.rule == TajweedRule.maddTabeei),
      isFalse,
      reason: 'madda_permissible must no longer map to madd tabeei',
    );
  });

  test('106:1 قريش is classified as madd lin, not madd arid lissukun', () {
    // Same upstream class, but a fatha before a sakin ya means madd lin.
    final ayah = AyahMapper.fromApi({
      'verse_key': '106:1',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': 'قُرَيْشٍ',
          'text_uthmani_tajweed':
              'قُرَ<rule class=madda_permissible>يْ</rule>شٍ',
        },
      ],
    });

    final rules = ayah.words.first.spans.map((s) => s.rule).toSet();
    expect(rules, contains(TajweedRule.maddLin));
    expect(rules, isNot(contains(TajweedRule.maddAridLissukun)));
  });

  test('1:7 الضالين does not colour the dad letter', () {
    // Upstream opens the madda_necessary span on the fatha, which renders on
    // the preceding dad. Reported visually as "the dad letter is coloured too".
    final ayah = AyahMapper.fromApi({
      'verse_key': '1:7',
      'words': [
        {
          'char_type_name': 'word',
          'text_uthmani': '\u0627\u0644\u0636\u0651\u064e\u0627\u0653\u0644\u0651\u0650\u064a\u0646\u064e',
          'text_uthmani_tajweed':
              '<rule class=ham_wasl>\u0671</rule><rule class=laam_shamsiyah>\u0644</rule>\u0636\u0651'
              '<rule class=madda_necessary>\u064e\u0627</rule>\u0653\u0644\u0651'
              '<rule class=madda_permissible>\u0650\u064a</rule>\u0646\u064e',
        },
      ],
    });

    final word = ayah.words.first;
    final dadIndex = word.arabic.indexOf('\u0636');
    expect(dadIndex, isNonNegative);

    for (final span in word.spans) {
      expect(
        span.start,
        isNot(equals(dadIndex + 1)),
        reason:
            '${span.rule} starts on the fatha carried by the dad, which '
            'tints the dad itself',
      );
      expect(
        word.arabic.codeUnitAt(span.start),
        isNot(anyOf(0x064E, 0x064F, 0x0650)),
        reason: '${span.rule} must not start on a short vowel',
      );
    }
  });

  // Madd Lazim splits into four classical types. The classifier works from the
  // text alone (no surah table), so it behaves identically in the ayah-by-ayah
  // and Mushaf page views, which both render spans produced by AyahMapper.
  //
  // Fixtures are the real upstream markup for each verse. Arabic is written as
  // explicit escapes because text_uthmani_tajweed uses decomposed forms that
  // look identical to precomposed ones in a failure message.
  group('madd lazim four-way classification', () {
    test('1:7 -> maddLazimKalimiMuthaqqal', () {
      // kalimi muthaqqal: madd letter then shaddah in-word
      final ayah = AyahMapper.fromApi({
        'verse_key': '1:7',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': '\u0671\u0644\u0636\u0651\u064e\u0627\u0653\u0644\u0651\u0650\u064a\u0646\u064e',
            'text_uthmani_tajweed': '<rule class=ham_wasl>\u0671</rule><rule class=laam_shamsiyah>\u0644</rule>\u0636\u0651<rule class=madda_necessary>\u064e\u0627</rule>\u0653\u0644\u0651<rule class=madda_permissible>\u0650\u064a</rule>\u0646\u064e',
          },
        ],
      });

      final lazim = ayah.words.first.spans
          .where((s) => s.rule.name.startsWith('maddLazim'))
          .toList();

      expect(lazim, isNotEmpty, reason: 'expected a madd lazim span');
      expect(
        lazim.map((s) => s.rule),
        contains(TajweedRule.maddLazimKalimiMuthaqqal),
      );
    });

    test('10:51 -> maddLazimKalimiMukhaffaf', () {
      // kalimi mukhaffaf: one of only two in the Quran
      final ayah = AyahMapper.fromApi({
        'verse_key': '10:51',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': '\u0621\u064e\u0627\u0653\u0644\u0652\u0640\u0654\u064e\u0640\u0670\u0646\u064e',
            'text_uthmani_tajweed': '\u0621\u064e<rule class=madda_necessary>\u0627</rule>\u0653\u0644\u0652\u0640\u0654\u064e<rule class=madda_normal>\u0640\u0670</rule>\u0646\u064e',
          },
        ],
      });

      final lazim = ayah.words.first.spans
          .where((s) => s.rule.name.startsWith('maddLazim'))
          .toList();

      expect(lazim, isNotEmpty, reason: 'expected a madd lazim span');
      expect(
        lazim.map((s) => s.rule),
        contains(TajweedRule.maddLazimKalimiMukhaffaf),
      );
    });

    test('2:1 -> maddLazimHarfiMuthaqqal', () {
      // harfi muthaqqal: lam of alif-lam-meem merges into meem
      final ayah = AyahMapper.fromApi({
        'verse_key': '2:1',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': '\u0627\u0644\u0653\u0645\u0653',
            'text_uthmani_tajweed': '\u0627<rule class=madda_necessary>\u0644\u0653</rule><rule class=madda_necessary>\u0645\u0653</rule>',
          },
        ],
      });

      final lazim = ayah.words.first.spans
          .where((s) => s.rule.name.startsWith('maddLazim'))
          .toList();

      expect(lazim, isNotEmpty, reason: 'expected a madd lazim span');
      expect(
        lazim.map((s) => s.rule),
        contains(TajweedRule.maddLazimHarfiMuthaqqal),
      );
    });

    test('68:1 -> maddLazimHarfiMukhaffaf', () {
      // harfi mukhaffaf: nun with nothing to merge into
      final ayah = AyahMapper.fromApi({
        'verse_key': '68:1',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': '\u0646\u0653\u200c\u06da',
            'text_uthmani_tajweed': '<rule class=madda_necessary>\u0646\u0653</rule>\u200c\u06da',
          },
        ],
      });

      final lazim = ayah.words.first.spans
          .where((s) => s.rule.name.startsWith('maddLazim'))
          .toList();

      expect(lazim, isNotEmpty, reason: 'expected a madd lazim span');
      expect(
        lazim.map((s) => s.rule),
        contains(TajweedRule.maddLazimHarfiMukhaffaf),
      );
    });

    test('2:1 alif-lam-meem splits into muthaqqal then mukhaffaf', () {
      // The lam merges into the following meem (muthaqqal); the trailing meem
      // has nothing after it in the word, so it stays mukhaffaf. The alif is
      // never part of either span.
      final ayah = AyahMapper.fromApi({
        'verse_key': '2:1',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': '\u0627\u0644\u0653\u0645\u0653',
            'text_uthmani_tajweed':
                '\u0627<rule class=madda_necessary>\u0644\u0653</rule>'
                '<rule class=madda_necessary>\u0645\u0653</rule>',
          },
        ],
      });

      final word = ayah.words.first;
      final lazim = word.spans
          .where((s) => s.rule.name.startsWith('maddLazim'))
          .toList();

      expect(lazim, hasLength(2));
      expect(lazim[0].rule, TajweedRule.maddLazimHarfiMuthaqqal);
      expect(lazim[1].rule, TajweedRule.maddLazimHarfiMukhaffaf);
      expect(
        lazim.every((s) => s.start > 0),
        isTrue,
        reason: 'the alif must never be highlighted',
      );
    });
  });

}
