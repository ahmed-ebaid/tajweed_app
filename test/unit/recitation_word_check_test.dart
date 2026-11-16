import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/l10n/memorization_localizations.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/core/services/speech_comparison_service.dart';

void main() {
  final comparison = SpeechComparisonService();
  const expected = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

  test('pause marks are not counted as recitation words', () {
    expect(
      comparison.recitationWords(
        'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ',
      ),
      ['ذلك', 'الكتاب', 'لا', 'ريب', 'فيه', 'هدى', 'للمتقين'],
    );
  });

  test('public basmala recognition matches Quran reference spelling', () {
    const recognized = 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ';
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: [expected],
        expectedVerseKeys: ['1:1'],
        spokenText: recognized,
        allowWrittenOpenings: true,
      ),
      [4],
    );
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: expected,
            expectedVerseKey: '1:1',
            spokenText: recognized,
            allowWrittenOpenings: true,
          )
          .matched,
      isTrue,
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: [expected],
        expectedVerseKeys: ['1:1'],
        spokenText: 'بسم الله الرحمن العليم',
        allowWrittenOpenings: true,
      ),
      [3],
    );
  });

  test('resumed recordings can repeat an exact saved prefix or suffix', () {
    const ayah = 'صراط الذين أنعمت عليهم غير المغضوب عليهم ولا الضالين';
    for (final (retained, incoming, combined) in [
      (
        'صراط الذين',
        'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ',
        'صراط الذين أنعمت عليهم',
      ),
      (
        'صراط الذين أنعمت عليهم',
        'أنعمت عليهم غير المغضوب',
        'صراط الذين أنعمت عليهم غير المغضوب',
      ),
      ('صراط الذين أنعمت عليهم غير المغضوب', 'عليهم ولا الضالين', ayah),
    ]) {
      expect(
        comparison.joinRecitationSegment(
          retainedPrefix: retained,
          spokenText: incoming,
          expectedAyahs: [ayah],
          expectedVerseKeys: ['1:7'],
        ),
        combined,
      );
    }
  });

  test('live snapshots can restart at a completed ayah boundary', () {
    const ayahs = [
      expected,
      'الحمد لله رب العالمين',
      'الرحمن الرحيم',
      'مالك يوم الدين',
    ];
    const keys = ['1:1', '1:2', '1:3', '1:4'];
    const retained = '$expected الحمد لله رب العالمين';
    const incoming = 'الحمد لله رب العالمين الرحمن الرحيم مالك يوم الدين';

    final joined = comparison.joinRecitationSegment(
      retainedPrefix: retained,
      spokenText: incoming,
      expectedAyahs: ayahs,
      expectedVerseKeys: keys,
      allowWrittenOpenings: true,
    );
    expect(
      comparison
          .checkSequence(
            expectedAyahs: ayahs,
            expectedVerseKeys: keys,
            spokenText: joined,
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      4,
    );

    for (final invalidTail in [
      'الحمد لله رب العالمين الرحمن العليم مالك يوم الدين',
      'الحمد لله رب العالمين مالك يوم الدين',
    ]) {
      final invalid = comparison.joinRecitationSegment(
        retainedPrefix: retained,
        spokenText: invalidTail,
        expectedAyahs: ayahs,
        expectedVerseKeys: keys,
        allowWrittenOpenings: true,
      );
      final check = comparison.checkSequence(
        expectedAyahs: ayahs,
        expectedVerseKeys: keys,
        spokenText: invalid,
        allowWrittenOpenings: true,
      );
      expect(check.completedAyahs, 2);
      expect(check.mismatch, isTrue);
    }
  });

  test('resume overlap cannot discard a wrong or repeated new word', () {
    for (final incoming in ['الله الكريم الرحيم', 'الله الله الرحمن الرحيم']) {
      final joined = comparison.joinRecitationSegment(
        retainedPrefix: 'بسم الله',
        spokenText: incoming,
        expectedAyahs: [expected],
        expectedVerseKeys: ['1:1'],
      );
      final check = comparison.checkSequence(
        expectedAyahs: [expected],
        expectedVerseKeys: ['1:1'],
        spokenText: joined,
      );
      expect(check.mismatch, isTrue);
      expect(check.completedAyahs, 0);
      expect(check.matchedPrefixText, 'بسم الله');
    }
  });

  test('resume overlap recognizes printed openings only when opted in', () {
    for (final enabled in [false, true]) {
      final joined = comparison.joinRecitationSegment(
        retainedPrefix: 'ألف لام را تلك',
        spokenText: 'الر تلك آيات الكتاب الحكيم',
        expectedAyahs: ['الر تلك آيات الكتاب الحكيم'],
        expectedVerseKeys: ['10:1'],
        allowWrittenOpenings: enabled,
      );
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: 'الر تلك آيات الكتاب الحكيم',
              expectedVerseKey: '10:1',
              spokenText: joined,
            )
            .matched,
        enabled,
      );
    }
  });

  test('mismatches expose only an exact prefix for blocked-word recovery', () {
    for (final spoken in [
      'بسم الله الكريم الرحيم',
      'بسم الله الرحيم',
      'بسم الله زيادة الرحمن الرحيم',
      'بسم الله الله الرحمن الرحيم',
    ]) {
      final check = comparison.checkSequence(
        expectedAyahs: [expected],
        expectedVerseKeys: ['1:1'],
        spokenText: spoken,
      );
      expect(check.mismatch, isTrue);
      expect(check.completedAyahs, 0);
      expect(check.remainingText, isEmpty);
      expect(check.matchedPrefixText, 'بسم الله');
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [expected],
              expectedVerseKeys: ['1:1'],
              spokenText: '${check.matchedPrefixText} الرحمن الرحيم',
            )
            .completedAyahs,
        1,
      );
    }
  });

  test('unfinished prefix is scoped to the first incomplete ayah', () {
    final check = comparison.checkSequence(
      expectedAyahs: [expected, 'الحمد لله رب العالمين'],
      expectedVerseKeys: ['1:1', '1:2'],
      spokenText: 'بسم الله الرحمن الرحيم الحمد زيادة رب العالمين',
    );
    expect(check.completedAyahs, 1);
    expect(check.matchedPrefixText, 'الحمد');
    expect(check.wordIndex, 1);
  });

  test('extra final words do not expose a newly accepted final prefix', () {
    final check = comparison.checkSequence(
      expectedAyahs: [expected],
      expectedVerseKeys: ['1:1'],
      spokenText: 'بسم الله الرحمن الرحيم زيادة',
    );
    expect(check.completedAyahs, 0);
    expect(check.mismatch, isTrue);
    expect(check.matchedPrefixText, isEmpty);
  });

  const openings = {
    '2:1': ('الم', 'ألف لام ميم'),
    '3:1': ('الم', 'ألف لام ميم'),
    '7:1': ('المص', 'ألف لام ميم صاد'),
    '10:1': ('الر تلك آيات الكتاب الحكيم', 'ألف لام را تلك آيات الكتاب الحكيم'),
    '11:1': ('الر', 'ألف لام را'),
    '12:1': ('الر', 'ألف لام را'),
    '13:1': ('المر', 'ألف لام ميم را'),
    '14:1': ('الر', 'ألف لام را'),
    '15:1': ('الر', 'ألف لام را'),
    '19:1': ('كهيعص', 'كاف ها يا عين صاد'),
    '20:1': ('طه', 'طا ها'),
    '26:1': ('طسم', 'طا سين ميم'),
    '27:1': ('طس', 'طا سين'),
    '28:1': ('طسم', 'طا سين ميم'),
    '29:1': ('الم', 'ألف لام ميم'),
    '30:1': ('الم', 'ألف لام ميم'),
    '31:1': ('الم', 'ألف لام ميم'),
    '32:1': ('الم', 'ألف لام ميم'),
    '36:1': ('يس', 'يا سين'),
    '38:1': ('ص والقرآن ذي الذكر', 'صاد والقرآن ذي الذكر'),
    '40:1': ('حم', 'حا ميم'),
    '41:1': ('حم', 'حا ميم'),
    '42:1': ('حم', 'حا ميم'),
    '42:2': ('عسق', 'عين سين قاف'),
    '43:1': ('حم', 'حا ميم'),
    '44:1': ('حم', 'حا ميم'),
    '45:1': ('حم', 'حا ميم'),
    '46:1': ('حم', 'حا ميم'),
    '50:1': ('ق والقرآن المجيد', 'قاف والقرآن المجيد'),
    '68:1': ('ن والقلم وما يسطرون', 'نون والقلم وما يسطرون'),
  };
  for (final entry in openings.entries) {
    test('lab accepts Quran model written opening at ${entry.key}', () {
      final written = entry.value.$1;
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: written,
              expectedVerseKey: entry.key,
              spokenText: written,
              allowWrittenOpenings: true,
            )
            .matched,
        isTrue,
      );
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [written],
              expectedVerseKeys: [entry.key],
              spokenText: written,
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: [written],
          expectedVerseKeys: [entry.key],
          spokenText: written,
          allowWrittenOpenings: true,
        ),
        [written.split(' ').length],
      );
    });
    test('matches spoken disconnected letters at ${entry.key}', () {
      final (written, spoken) = entry.value;
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: written,
              expectedVerseKey: entry.key,
              spokenText: spoken,
            )
            .matched,
        isTrue,
      );
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [written],
              expectedVerseKeys: [entry.key],
              spokenText: spoken,
            )
            .completedAyahs,
        1,
      );
    });
  }

  test('written openings never bypass surrounding errors or extra words', () {
    for (final spoken in [
      'الم ذلك الكلام',
      'الم الم ذلك الكتاب',
      'الم ذلك الكتاب زيادة',
      'لام ألف ميم ذلك الكتاب',
      'ألف لام ذلك الكتاب',
    ]) {
      expect(
        comparison
            .checkSequence(
              expectedAyahs: ['الم', 'ذلك الكتاب'],
              expectedVerseKeys: ['2:1', '2:2'],
              spokenText: spoken,
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        lessThan(2),
      );
    }
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'ألف لام ميم',
            expectedVerseKey: '2:2',
            spokenText: 'الم',
            allowWrittenOpenings: true,
          )
          .matched,
      isFalse,
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: ['الم', 'ذلك الكتاب'],
        expectedVerseKeys: ['2:1', '2:2'],
        spokenText: 'الٓمٓ ذلك الكلام',
        allowWrittenOpenings: true,
      ),
      [1, 1],
    );
  });

  for (final alif in ['الف', 'ألف', '1000', '١٠٠٠', '۱۰۰۰']) {
    test('accepts scoped Alif recognition variant $alif', () {
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: 'الٓمٓ',
              expectedVerseKey: '2:1',
              spokenText: '$alif لام ميم',
            )
            .matched,
        isTrue,
      );
    });
  }

  test('accepts long letter-name spellings', () {
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'كهيعص',
            expectedVerseKey: '19:1',
            spokenText: 'كاف هاء ياء عين صاد',
          )
          .matched,
      isTrue,
    );
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'طه',
            expectedVerseKey: '20:1',
            spokenText: 'طاء هاء',
          )
          .matched,
      isTrue,
    );
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'حم',
            expectedVerseKey: '40:1',
            spokenText: 'حاء ميم',
          )
          .matched,
      isTrue,
    );
  });

  test('aliases never apply outside exact known openings', () {
    for (final key in [null, '2:2', '1:1']) {
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: 'الم',
              expectedVerseKey: key,
              spokenText: '1000 لام ميم',
            )
            .matched,
        isFalse,
      );
    }
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'ألف',
            expectedVerseKey: '2:1',
            spokenText: '1000',
          )
          .matched,
      isFalse,
    );
  });

  test('opening still rejects missing reordered or extra spoken letters', () {
    for (final spoken in ['ألف لام', 'لام ألف ميم', 'ألف لام ميم ميم', 'الم']) {
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: 'الم',
              expectedVerseKey: '2:1',
              spokenText: spoken,
            )
            .matched,
        isFalse,
      );
    }
  });

  test('continuous segments retain a partial spoken opening for Resume', () {
    final first = comparison.checkSequence(
      expectedAyahs: ['الم', 'ذلك الكتاب'],
      expectedVerseKeys: ['2:1', '2:2'],
      spokenText: '1000 لام',
    );
    expect(first.completedAyahs, 0);
    expect(first.remainingText, '1000 لام');
    expect(first.mismatch, isFalse);
    final resumed = comparison.checkSequence(
      expectedAyahs: ['الم', 'ذلك الكتاب'],
      expectedVerseKeys: ['2:1', '2:2'],
      spokenText: '${first.remainingText} ميم ذلك الكتاب',
    );
    expect(resumed.completedAyahs, 2);
    expect(resumed.mismatch, isFalse);
  });

  test('continuous opening cannot bypass incorrect ordinary verse words', () {
    final result = comparison.checkSequence(
      expectedAyahs: ['الم', 'ذلك الكتاب'],
      expectedVerseKeys: ['2:1', '2:2'],
      spokenText: 'ألف لام ميم ذلك الكلام',
    );
    expect(result.completedAyahs, 1);
    expect(result.mismatch, isTrue);
    expect(result.wordIndex, 1);
    expect(
      () => comparison.checkSequence(
        expectedAyahs: ['الم'],
        expectedVerseKeys: [],
        spokenText: 'ألف لام ميم',
      ),
      throwsArgumentError,
    );
  });

  test('live word preview returns only a complete ordered prefix', () {
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: [expected, 'الحمد لله رب العالمين'],
        expectedVerseKeys: ['1:1', '1:2'],
        spokenText: 'بسم الله الرحمن الرحيم الحمد لل',
      ),
      [4, 1],
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: [expected],
        expectedVerseKeys: ['1:1'],
        spokenText: 'بسم الله الكريم الرحيم',
      ),
      [2],
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: ['الم'],
        expectedVerseKeys: ['2:1'],
        spokenText: 'ألف لام ميم',
      ),
      [1],
    );
  });

  test('normalizes marks and punctuation without changing letters', () {
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: expected,
            spokenText: 'بسم الله، الرحمن الرحيم.',
          )
          .matched,
      isTrue,
    );
  });

  for (final spoken in [
    '',
    'بسم',
    'بسم الله الرحمن',
    'بسم الرحمن الرحيم',
    'بسم الله الرحمن الرحيم الرحيم',
    'بسم الله الله الرحمن الرحيم',
    'بسم الله الرحيم الرحمن',
    'بسم الله الرحمن الكريم',
    'start بسم الله الرحمن الرحيم',
    'بسم الله الرحمن الرحيم stop',
  ]) {
    test(
      'does not complete partial, skipped, reordered or extra words: $spoken',
      () {
        expect(
          comparison
              .checkEntireAyah(expectedImlaei: expected, spokenText: spoken)
              .matched,
          isFalse,
        );
      },
    );
  }

  test('empty reference cannot pass', () {
    expect(
      comparison.checkEntireAyah(expectedImlaei: '', spokenText: '').matched,
      isFalse,
    );
  });

  test('does not conflate different hamzas or similar words', () {
    expect(
      comparison
          .checkEntireAyah(expectedImlaei: 'سأل', spokenText: 'سال')
          .matched,
      isFalse,
    );
    expect(
      comparison
          .checkEntireAyah(expectedImlaei: 'الرحيم', spokenText: 'الرحمن')
          .matched,
      isFalse,
    );
  });

  test('reports first ordered mismatch', () {
    final result = comparison.checkEntireAyah(
      expectedImlaei: expected,
      spokenText: 'بسم الله الكريم الرحيم',
    );
    expect(result.firstMismatch, 2);
    expect(result.wordsExpected, 4);
    expect(result.wordsSpoken, 4);
  });

  test('wasla and directional marks do not block a word match', () {
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'ٱللَّهِ',
            spokenText: '\u200fالله\u2060',
          )
          .matched,
      isTrue,
    );
  });

  test(
    'maps ordinary spelling separately from authoritative display glyphs',
    () {
      final ayah = AyahMapper.fromApi({
        'verse_key': '1:4',
        'text_uthmani': 'مَٰلِكِ',
        'words': [
          {
            'char_type_name': 'word',
            'text_uthmani': 'مَٰلِكِ',
            'text_imlaei': 'مَالِكِ',
          },
          {'char_type_name': 'end', 'text_imlaei': '٤'},
        ],
      });
      expect(ayah.arabic, 'مَٰلِكِ');
      expect(ayah.imlaei, 'مَالِكِ');
      expect(
        comparison
            .checkEntireAyah(expectedImlaei: ayah.imlaei!, spokenText: 'مالك')
            .matched,
        isTrue,
      );
      expect(
        comparison
            .checkEntireAyah(expectedImlaei: ayah.imlaei!, spokenText: 'ملك')
            .matched,
        isFalse,
      );
    },
  );

  test(
    'missing word reference fails closed instead of grading incomplete text',
    () {
      final ayah = AyahMapper.fromApi({
        'verse_key': '1:1',
        'words': [
          {'char_type_name': 'word', 'text_imlaei': 'بسم'},
          {'char_type_name': 'word', 'text_uthmani': 'الله'},
        ],
      });
      expect(ayah.imlaei, isNull);
    },
  );

  test('all supported locales contain every memorization message', () {
    final keys = memorizationTranslations['en']!.keys.toSet();
    for (final locale in AppLocalizations.supportedLocales) {
      final translations = memorizationTranslations[locale.languageCode]!;
      expect(translations.keys.toSet(), keys);
      expect(translations.values.every((text) => text.isNotEmpty), isTrue);
    }
  });

  test('assimilated and split consonant boundaries match when confirmed by following word', () {
    const baqarah20Tail =
        'وَلَوْ شَاءَ اللَّهُ لَذَهَبَ بِسَمْعِهِمْ وَأَبْصَارِهِمْ إِنَّ اللَّهَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ';
    for (final spoken in [
      'ولو شاء الله لذهب بأبس معهم وأبصارهم إن الله على كل شيء قدير',
      'ولو شاء الله لذهب بأنبس معهم وأبصارهم إن الله على كل شيء قدير',
      'ولو شاء الله لذهب بعد سمعهم وأبصارهم إن الله على كل شيء قدير',
      'ولو شاء الله لذهبا بسمعهم وأبصارهم إن الله على كل شيء قدير',
    ]) {
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: [baqarah20Tail],
          expectedVerseKeys: ['2:20'],
          spokenText: spoken,
          allowWrittenOpenings: true,
        ),
        [12],
      );
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [baqarah20Tail],
              expectedVerseKeys: ['2:20'],
              spokenText: spoken,
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );
    }
  });

  test('joinRecitationSegment skips a single clipped leading window token when following words overlap', () {
    const ayah =
        'يَكَادُ الْبَرْقُ يَخْطَفُ أَبْصَارَهُمْ كُلَّمَا أَضَاءَ لَهُم مَّشَوْا فِيهِ وَإِذَا أَظْلَمَ عَلَيْهِمْ قَامُوا';
    final joined = comparison.joinRecitationSegment(
      retainedPrefix: 'يكاد البرق يخطف أبصارهم كلما أضاء لهم مشوا فيه وإذا أظلم',
      spokenText: 'فقاموا أظلم عليهم قاموا',
      expectedAyahs: [ayah],
      expectedVerseKeys: ['2:20'],
      allowWrittenOpenings: true,
    );
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [ayah],
            expectedVerseKeys: ['2:20'],
            spokenText: joined,
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      1,
    );
  });

  test('attached pronoun split, maqsura-to-hamza ending, and final noon assimilation match in 2:13', () {
    const baqarah13 =
        'وَإِذَا قِيلَ لَهُمْ آمِنُوا كَمَا آمَنَ النَّاسُ قَالُوا أَنُؤْمِنُ كَمَا آمَنَ السُّفَهَاءُ أَلَا إِنَّهُمْ هُمُ السُّفَهَاءُ وَلَٰكِن لَّا يَعْلَمُونَ';
    for (final spoken in [
      'وإذا قيل لهم آمنوا كما آمن الناس قالوا أنؤمنك ما آمن السفهاء ألا إنهم هم السفهاء ولكن لا يعلمون',
      'وإذا قيل لهم آمنوا كما آمن الناس قالوا أنؤمن كما آمن السفهى ألا إنهم هم السفهاء ولكم لا يعلمون',
    ]) {
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [baqarah13],
              expectedVerseKeys: ['2:13'],
              spokenText: spoken,
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );
    }
  });

  test('confusable consonant and medial alif elision match in 2:24 when confirmed by following word', () {
    const baqarah24 =
        'فَإِن لَّمْ تَفْعَلُوا وَلَن تَفْعَلُوا فَاتَّقُوا النَّارَ الَّتِي وَقُودُهَا النَّاسُ وَالْحِجَارَةُ أُعِدَّتْ لِلْكَافِرِينَ';
    for (final spoken in [
      'فإن لم تفعلوا ولن تفعلوا فاتكوا النار التي وقودها الناس والحجارة أعدت للكافرين',
      'فإن لم تفعلوا ولن تفعلوا فاتقوا النار التي وقودها الناس والحجرة أعدت للكافرين',
    ]) {
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [baqarah24],
              expectedVerseKeys: ['2:24'],
              spokenText: spoken,
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );
    }
  });

  test('matches Uthmani short-alif iyyaka, connected-speech alif elision, and initial sibilant assimilation in 1:5-1:7', () {
    const fatihah5 = 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ';
    const fatihah6 = 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ';
    const fatihah7 =
        'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ';

    expect(
      comparison
          .checkSequence(
            expectedAyahs: [fatihah5, fatihah6],
            expectedVerseKeys: ['1:5', '1:6'],
            spokenText:
                'إِيَكَ نَعْبُدُ وَإِيَّكَ نَسْتَعِينُ إِهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );

    expect(
      comparison
          .checkSequence(
            expectedAyahs: [fatihah5, fatihah6],
            expectedVerseKeys: ['1:5', '1:6'],
            spokenText:
                'إِيَكَ نَعْبُدُ وَإِيَّكَ نَسْتَعِيِّنَا اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );

    expect(
      comparison
          .checkSequence(
            expectedAyahs: [fatihah7],
            expectedVerseKeys: ['1:7'],
            spokenText:
                'فِرَاطَ الَّذِينَ نَعْمَتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      1,
    );

    final joined = comparison.joinRecitationSegment(
      retainedPrefix: '$fatihah5 $fatihah6 صراط الذين',
      spokenText: 'هِدْنَا السِّرَاطَ الْمُسْتَقِيمَ سِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ',
      expectedAyahs: [fatihah5, fatihah6, fatihah7],
      expectedVerseKeys: ['1:5', '1:6', '1:7'],
      allowWrittenOpenings: true,
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: [fatihah5, fatihah6, fatihah7],
        expectedVerseKeys: ['1:5', '1:6', '1:7'],
        spokenText: joined,
        allowWrittenOpenings: true,
      ),
      [4, 3, 4],
    );
  });
}
