import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/l10n/memorization_localizations.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/core/services/speech_comparison_service.dart';

void main() {
  final comparison = SpeechComparisonService();
  const expected = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

  test(
    'Bayyinah cloud variants require Quran ASR mode and a following anchor',
    () {
      for (final (key, reference, transcript) in [
        ('98:4', 'من بعد ما جاءتهم البينة', 'من بعد ما جاءتون البينة'),
        (
          '98:5',
          'مخلصين له الدين حنفاء ويقيموا',
          'مخلصين له الدين خلفاء ويقيموا',
        ),
        ('98:5', 'حنفاء ويقيموا الصلاة', 'اكل فاء ويقيموا الصلاة'),
        (
          '98:5',
          'ويؤتوا الزكاة وذلك دين القيمة',
          'ويؤتوا تكاد وذلك دين القيمة',
        ),
        (
          '98:6',
          'والمشركين في نار جهنم خالدين فيها',
          'والمشفكين في نار جهر خالدين فيها',
        ),
        ('98:6', 'في نار جهنم خالدين فيها', 'في نارج خالدين فيها'),
        ('98:6', 'أولئك هم شر البرية', 'ألئك هم شر البرية'),
        ('98:8', 'جزاؤهم عند ربهم', 'جزاءون عند ربهم'),
        ('98:8', 'رضي الله عنهم', 'فزي الله عنهم'),
        ('98:8', 'لمن خشي ربه', 'لمن خش ربه'),
      ]) {
        expect(
          comparison
              .checkEntireAyah(
                expectedImlaei: reference,
                expectedVerseKey: key,
                spokenText: transcript,
                allowWrittenOpenings: true,
              )
              .matched,
          isTrue,
          reason: transcript,
        );
        expect(
          comparison
              .checkEntireAyah(
                expectedImlaei: reference,
                expectedVerseKey: key,
                spokenText: transcript,
              )
              .matched,
          isFalse,
          reason: 'strict mode: $transcript',
        );
      }
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: 'في نار جهنم خالدين فيها',
              expectedVerseKey: '98:6',
              spokenText: 'في نارج خطأ فيها',
              allowWrittenOpenings: true,
            )
            .matched,
        isFalse,
      );
    },
  );

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

  test('matches cloud recordings for 90:4, 90:6, 109:2, and 109:3', () {
    // 90:6: يقول أهلكت مالا لبدا -> ASR: يقول أحلكت مالا لبدا
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'يَقُولُ أَهْلَكْتُ مَالًا لُّبَدًا',
            expectedVerseKey: '90:6',
            spokenText: 'يَقُولُ أَحْلَكْتُ مَالًا لُبَدًا',
            allowWrittenOpenings: true,
          )
          .matched,
      isTrue,
    );
    // 90:4: لقد خلقنا الإنسان في كبد -> ASR: ولقد خلقنا الإنسان في كبد
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'لَقَدْ خَلَقْنَا الْإِنسَانَ فِي كَبَدٍ',
            expectedVerseKey: '90:4',
            spokenText: 'وَلَقَدْ خَلَقْنَا الْإِنْسَانَ فِي كَبَدٍ',
            allowWrittenOpenings: true,
          )
          .matched,
      isTrue,
    );
    // 109:2: لا أعبد ما تعبدون -> ASR: لا أعبدوا ما تعبدون
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'لَا أَعْبُدُ مَا تَعْبُدُونَ',
            expectedVerseKey: '109:2',
            spokenText: 'لَا أَعْبُدُوا مَا تَعْبُدُونَ',
            allowWrittenOpenings: true,
          )
          .matched,
      isTrue,
    );
    // 109:3: ولا أنتم عابدون ما أعبد -> ASR: لا ولا أنتم عابدون ما أعبد
    expect(
      comparison
          .checkEntireAyah(
            expectedImlaei: 'وَلَا أَنتُمْ عَابِدُونَ مَا أَعْبُدُ',
            expectedVerseKey: '109:3',
            spokenText: 'لَا وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ',
            allowWrittenOpenings: true,
          )
          .matched,
      isTrue,
    );
  });

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

  test(
    'assimilated and split consonant boundaries match when confirmed by following word',
    () {
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
    },
  );

  test(
    'joinRecitationSegment skips a single clipped leading window token when following words overlap',
    () {
      const ayah =
          'يَكَادُ الْبَرْقُ يَخْطَفُ أَبْصَارَهُمْ كُلَّمَا أَضَاءَ لَهُم مَّشَوْا فِيهِ وَإِذَا أَظْلَمَ عَلَيْهِمْ قَامُوا';
      final joined = comparison.joinRecitationSegment(
        retainedPrefix:
            'يكاد البرق يخطف أبصارهم كلما أضاء لهم مشوا فيه وإذا أظلم',
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
    },
  );

  test(
    'attached pronoun split, maqsura-to-hamza ending, and final noon assimilation match in 2:13',
    () {
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
    },
  );

  test(
    'confusable consonant and medial alif elision match in 2:24 when confirmed by following word',
    () {
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
    },
  );

  test(
    'matches Uthmani short-alif iyyaka, connected-speech alif elision, and initial sibilant assimilation in 1:5-1:7',
    () {
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
        spokenText:
            'هِدْنَا السِّرَاطَ الْمُسْتَقِيمَ سِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ',
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
    },
  );

  test('matches cloud recordings for Surahs 90, 102, 104, 105, 106, 107, and 108', () {
    // 90:6 - أَحْلَكْتُوا مَالًا لُبَدًا
    expect(
      comparison
          .checkSequence(
            expectedAyahs: ['يَقُولُ أَهْلَكْتُ مَالًا لُّبَدًا'],
            expectedVerseKeys: ['90:6'],
            spokenText: 'يَقُولُ أَحْلَكْتُوا مَالًا لُبَدًا',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      1,
    );

    // 90:7 - أَلَّمْ (idgham of أن لم)
    expect(
      comparison
          .checkSequence(
            expectedAyahs: ['أَيَحْسَبُ أَن لَّمْ يَرَهُ أَحَدٌ'],
            expectedVerseKeys: ['90:7'],
            spokenText: 'أَيَحْسَبُ أَلَّمْ يَرَهُ أَحَدٌ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      1,
    );

    // 90:11 - فَلَا اقْطَحَ مَلْعَقَبَةٍ
    expect(
      comparison
          .checkSequence(
            expectedAyahs: ['فَلَا اقْتَحَمَ الْعَقَبَةَ'],
            expectedVerseKeys: ['90:11'],
            spokenText: 'فَلَا اقْطَحَ مَلْعَقَبَةٍ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      1,
    );

    // 90:17 - بِالسَّبْرِ وَطَوَاسَوْا بِالْمَرْحَمَةِ
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'ثُمَّ كَانَ مِنَ الَّذِينَ آمَنُوا وَتَوَاصَوْا بِالصَّبْرِ وَتَوَاصَوْا بِالْمَرْحَمَةِ',
            ],
            expectedVerseKeys: ['90:17'],
            spokenText:
                'ثُمَّ كَانَ مِنَ الَّذِينَ آمَنُوا وَتَوَاصَوْا بِالسَّبْرِ وَطَوَاسَوْا بِالْمَرْحَمَةِ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      1,
    );

    // 108:1-3 - Al-Kawthar cloud transcripts
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ',
              'فَصَلِّ لِرَبِّكَ وَانْحَرْ',
              'إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ',
            ],
            expectedVerseKeys: ['108:1', '108:2', '108:3'],
            spokenText:
                'إِنَّ عَطَيْنَاكَ الْكَوْثَرَ فَصَلِّي لِرَبِّكَ وَانْحَرْ إِنَّ شَانِعَكَ هُوَ الْأَبْتَرُ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      3,
    );

    // 105:2, 105:4, 105:5 - Al-Fil cloud transcripts
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'أَلَمْ تَرَ كَيْفَ فَعَلَ رَبُّكَ بِأَصْحَابِ الْفِيلِ',
              'أَلَمْ يَجْعَلْ كَيْدَهُمْ فِي تَضْلِيلٍ',
            ],
            expectedVerseKeys: ['105:1', '105:2'],
            spokenText:
                'أَلَمْ تَرَ كَيْفَ فَعَلَ رَبُّكَ بِأَصْحَابِ الْفِيلِ أَلَمْ يَجْعَلْ كَيْدَهُمْ فِي قَضْلِيلٍ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'تَرْمِيهِم بِحِجَارَةٍ مِّن سِجِّيلٍ',
              'فَجَعَلَهُمْ كَعَصْفٍ مَّأْكُولٍ',
            ],
            expectedVerseKeys: ['105:4', '105:5'],
            spokenText:
                'فَرْمِيهِمْ بِحِجْرَةٍ مِنْ سِجِّيلٍ فَجَعَلَهُمْ قَاصْفٍ مَأْكُولٍ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );

    // 104:8-9 - Al-Humazah cloud transcripts
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'إِنَّهَا عَلَيْهِم مُّؤْصَدَةٌ',
              'فِي عَمَدٍ مُّمَدَّدَةٍ',
            ],
            expectedVerseKeys: ['104:8', '104:9'],
            spokenText: 'إِنَّهَا عَلَيْهِمْ مُصَلَةٌ فِي عَمَدٍ مُمَدَّدَةٍ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );

    // 106:3-4 - Quraysh cloud transcript
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'فَلْيَعْبُدُوا رَبَّ هَٰذَا الْبَيْتِ',
              'الَّذِي أَطْعَمَهُم مِّن جُوعٍ وَآمَنَهُم مِّنْ خَوْفٍ',
            ],
            expectedVerseKeys: ['106:3', '106:4'],
            spokenText:
                'فَلِيَعْبُدُوا رَبَّ هَذَا الْبَيْتِ الَّذِي أَطْعَمُهُمْ مِنْ جُوعٍ وَآمَنَهُمْ مِنْ خَوْفٍ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );

    // 107:5-7 - Al-Ma'un: repeated prefix الذين هم must not skip 107:5 into 107:6
    const maun4 = 'فَوَيْلٌ لِّلْمُصَلِّينَ';
    const maun5 = 'الَّذِينَ هُمْ عَن صَلَاتِهِمْ سَاهُونَ';
    const maun6 = 'الَّذِينَ هُمْ يُرَاءُونَ';
    const maun7 = 'وَيَمْنَعُونَ الْمَاعُونَ';
    final joinedMidAyah = comparison.joinRecitationSegment(
      retainedPrefix: 'فويل للمصلين الذين هم',
      spokenText:
          'صَاتِهِمْ سَاهُونَ الَّذِينَ هُمْ يُرَاءُونَ وَيَمْنَعُونَ الْمَاعُونَ',
      expectedAyahs: [maun4, maun5, maun6, maun7],
      expectedVerseKeys: ['107:4', '107:5', '107:6', '107:7'],
      allowWrittenOpenings: true,
    );
    // Skipping 'صاتهم' when 'الذين هم' is only the 2-word prefix of 107:5 must NOT
    // truncate 107:5 to 'الذين هم ساهون'; instead 'عمصاتهم' / 'صاتهم' in full 107:5-7 matches:
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: [maun4, maun5, maun6, maun7],
        expectedVerseKeys: ['107:4', '107:5', '107:6', '107:7'],
        spokenText: joinedMidAyah,
        allowWrittenOpenings: true,
      ),
      [2, 2],
    );
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [maun4, maun5, maun6, maun7],
            expectedVerseKeys: ['107:4', '107:5', '107:6', '107:7'],
            spokenText:
                'فَوَيْلٌ لِلْمُصَلِّينَ الَّذِينَ هُمْ عَمْصَاتِهِمْ سَاهُونَ الَّذِينَ هُمْ يُرَاءُونَ وَيَمْنَعُونَ الْمَعُونَ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      4,
    );

    // 100:5 & 100:9-11 - Al-Adiyat cloud transcripts
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'فَوَسَطْنَ بِهِ جَمْعًا',
              'إِنَّ الْإِنسَانَ لِرَبِّهِ لَكَنُودٌ',
            ],
            expectedVerseKeys: ['100:5', '100:6'],
            spokenText:
                'فَاسْتَنْبِيهِ جَمْعًا إِنَّ الْإِنْسَانَ لِرَبِّهِ لَكَنُودٌ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'أَفَلَا يَعْلَمُ إِذَا بُعْثِرَ مَا فِي الْقُبُورِ',
              'وَحُصِّلَ مَا فِي الصُّدُورِ',
              'إِنَّ رَبَّهُم بِهِمْ يَوْمَئِذٍ لَّخَبِيرٌ',
            ],
            expectedVerseKeys: ['100:9', '100:10', '100:11'],
            spokenText:
                'أَفَلَا يَعْلَمُ إِذَا بُعْثِرَ مَا فِي الْقُبُورِ وَحُسُّ لَمَا فِي الصُّدُورِ إِنَّ رَبَّهُمْ بِهِمْ يَوْمَئِذٍ لَخَبِيرٌ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      3,
    );

    // 99:7-8 - Az-Zalzalah cloud transcript (شَرَّيْرَهُ)
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [
              'فَمَن يَعْمَلْ مِثْقَالَ ذَرَّةٍ خَيْرًا يَرَهُ',
              'وَمَن يَعْمَلْ مِثْقَالَ ذَرَّةٍ شَرًّا يَرَهُ',
            ],
            expectedVerseKeys: ['99:7', '99:8'],
            spokenText:
                'فَمَنْ يَعْمَلْ مِثْقَالَ ذَرَّةٍ خَيْرًا يَرَهُ وَمَنْ يَعْمَلْ مِثْقَالَ ذَرَّةٍ شَرَّيْرَهُ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );

    // 97:1-5 - Al-Qadr cloud transcripts (adjacent لَيْلَةُ الْقَدْرِ overlap, الْقَبْرِ, أَمْحٍ)
    const qadr1 = 'إِنَّا أَنزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ';
    const qadr2 = 'وَمَا أَدْرَاكَ مَا لَيْلَةُ الْقَدْرِ';
    const qadr3 = 'لَيْلَةُ الْقَدْرِ خَيْرٌ مِّنْ أَلْفِ شَهْرٍ';
    const qadr4 =
        'تَنَزَّلُ الْمَلَائِكَةُ وَالرُّوحُ فِيهَا بِإِذْنِ رَبِّهِم مِّن كُلِّ أَمْرٍ';
    const qadr5 = 'سَلَامٌ هِيَ حَتَّىٰ مَطْلَعِ الْفَجْرِ';
    final joinedQadr = comparison.joinRecitationSegment(
      retainedPrefix: '$qadr1 $qadr2',
      spokenText: 'لَيْلَةُ الْقَدْرِ خَيْرٌ مِنْ أَلْفِ شَهْرٍ',
      expectedAyahs: [qadr1, qadr2, qadr3, qadr4, qadr5],
      expectedVerseKeys: ['97:1', '97:2', '97:3', '97:4', '97:5'],
      allowWrittenOpenings: true,
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: [qadr1, qadr2, qadr3, qadr4, qadr5],
        expectedVerseKeys: ['97:1', '97:2', '97:3', '97:4', '97:5'],
        spokenText: joinedQadr,
        allowWrittenOpenings: true,
      ),
      [5, 5, 6, 0],
    );
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [qadr2, qadr3],
            expectedVerseKeys: ['97:2', '97:3'],
            spokenText:
                'وَمَا أَدْرَاكَ مَا لَيْلَةُ الْقَبْرِ خَيْرٌ مِنْ أَلْفِ شَهْرٍ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );
    expect(
      comparison
          .checkSequence(
            expectedAyahs: [qadr4, qadr5],
            expectedVerseKeys: ['97:4', '97:5'],
            spokenText:
                'تَنَزَّلُ الْمَلَائِكَةُ وَالرُّوحُ فِيهَا بِإِذْنِ رَبِّهِمْ مِنْ كُلِّ أَمْحٍ سَلَامٌ هِيَ حَتَّى مَطْلَعِ الْفَجْرِ',
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );
  });
}
