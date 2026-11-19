import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/l10n/app_localizations.dart';
import 'package:tajweed_practice/core/l10n/memorization_localizations.dart';
import 'package:tajweed_practice/core/services/ayah_mapper.dart';
import 'package:tajweed_practice/core/services/speech_comparison_service.dart';

void main() {
  final comparison = SpeechComparisonService();

  test(
    '2:255 ASR spelling recovery requires the word and its continuation',
    () {
      const expected = 'ولا يئوده حفظهما وهو العلي العظيم';
      const alternate = 'ولا يأوده حفظهما وهو العلي العظيم';

      bool matches(
        String spoken, {
        String key = '2:255',
        bool corrections = true,
      }) => comparison
          .checkEntireAyah(
            expectedImlaei: expected,
            expectedVerseKey: key,
            spokenText: spoken,
            allowWrittenOpenings: true,
            allowAsrCorrections: corrections,
          )
          .matched;

      expect(matches(alternate), isTrue);
      expect(matches(alternate, corrections: false), isFalse);
      // يؤده is itself a Quran word (3:75), so it is a substitution, not ASR.
      expect(matches('ولا يؤده حفظهما وهو العلي العظيم'), isFalse);
      expect(matches('ولا حفظهما وهو العلي العظيم'), isFalse);
      expect(matches('ولا يأوده وهو العلي العظيم'), isFalse);
    },
  );

  bool ayahMatches(String key, String expected, String spoken) => comparison
      .checkEntireAyah(
        expectedImlaei: expected,
        expectedVerseKey: key,
        spokenText: spoken,
        allowWrittenOpenings: true,
      )
      .matched;

  test('non-Quran ASR near misses need two right anchors and no omission', () {
    const expected =
        'يا بني إسرائيل اذكروا نعمتي التي أنعمت عليكم وأوفوا بعهدي أوف بعهدكم وإياي فارهبون';
    expect(
      ayahMatches(
        '2:40',
        expected,
        expected.replaceFirst('إسرائيل', 'السرائيل'),
      ),
      isTrue,
    );
    expect(
      ayahMatches('2:40', expected, expected.replaceFirst('إسرائيل ', '')),
      isFalse,
    );
    expect(
      ayahMatches('2:40', expected, expected.replaceFirst('وإياي', 'وإيياي')),
      isFalse,
      reason: 'a near miss needs two following words',
    );
  });

  test(
    'split final consonant recovery is display-only and needs two anchors',
    () {
      const expected = 'وليستعفف الذين لا يجدون نكاحا';
      const split = 'وليستعف في الذين لا يجدون نكاحا';
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: [expected],
          expectedVerseKeys: ['24:33'],
          spokenText: split,
          allowWrittenOpenings: true,
        ),
        [0],
      );
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: [expected],
          expectedVerseKeys: ['24:33'],
          spokenText: split,
          allowWrittenOpenings: true,
          allowDisplayOnlyCorrections: true,
        ),
        [1],
      );
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: expected,
              expectedVerseKey: '24:33',
              spokenText: split,
              allowWrittenOpenings: true,
            )
            .matched,
        isFalse,
      );
      for (final unsafeSplit in [
        'وليستعف في الذين نكاحا',
        'وليستعف في زيادة الذين لا يجدون نكاحا',
        'وليستعف في الذين زيادة يجدون نكاحا',
      ]) {
        expect(
          comparison.matchingPrefixWordCounts(
            expectedAyahs: [expected],
            expectedVerseKeys: ['24:33'],
            spokenText: unsafeSplit,
            allowWrittenOpenings: true,
            allowDisplayOnlyCorrections: true,
          ),
          [0],
          reason: unsafeSplit,
        );
      }
    },
  );

  test('joined and split Imlaei spellings must account for every letter', () {
    const expected =
        'ضرب لكم مثلا من أنفسكم هل لكم من ما ملكت أيمانكم من شركاء في ما رزقناكم فأنتم فيه سواء تخافونهم كخيفتكم أنفسكم كذلك نفصل الآيات لقوم يعقلون';
    final joined = expected
        .replaceFirst('من ما', 'مما')
        .replaceFirst('في ما', 'فيما');
    expect(ayahMatches('30:28', expected, joined), isTrue);
    expect(
      ayahMatches('30:28', expected, joined.replaceFirst('مما ', 'من ')),
      isFalse,
    );
    expect(
      ayahMatches('30:28', expected, joined.replaceFirst('فيما', 'في')),
      isFalse,
    );
  });

  test('a retained prefix covering the ayah ignores trailing audio', () {
    const expected = 'والله على كل شيء قدير';
    for (final (retained, words) in [(expected, 5), ('والله على كل', 3)]) {
      final joined = comparison.joinRecitationSegment(
        retainedPrefix: retained,
        spokenText: 'يسلط رسله على من يشاء',
        expectedAyahs: const [expected],
        expectedVerseKeys: const ['59:6'],
        allowWrittenOpenings: true,
      );
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: const [expected],
          expectedVerseKeys: const ['59:6'],
          spokenText: joined,
          allowWrittenOpenings: true,
        ),
        [words],
        reason: retained,
      );
    }
  });

  test('a window over a covered ayah may be cut only at its edges', () {
    const key = '3:156';
    const expected =
        'يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَكُونُوا كَالَّذِينَ كَفَرُوا '
        'وَقَالُوا لِإِخْوَانِهِمْ إِذَا ضَرَبُوا فِي الْأَرْضِ أَوْ كَانُوا '
        'غُزًّى لَّوْ كَانُوا عِندَنَا مَا مَاتُوا وَمَا قُتِلُوا';
    final retained = comparison.recitationWords(expected).join(' ');
    String join(String spoken) => comparison.joinRecitationSegment(
      retainedPrefix: retained,
      spokenText: spoken,
      expectedAyahs: const [expected],
      expectedVerseKeys: const [key],
      allowWrittenOpenings: true,
    );
    for (final spoken in [
      'قالوا لإخوانهم إذا ضربوا في الأرض أو كانوا غزا لو كانوا عندنا ما ماتوا وما قتلوا',
      'إذا ضربوا في الأرض أو كا',
    ]) {
      expect(join(spoken), retained, reason: spoken);
    }
    for (final spoken in [
      'لهم لإخوانهم إذا ضربوا في الأرض',
      'قالوا لإخوانهم إذا ضربوا في السماء أو كانوا',
      'قالوا لإخوانهم إذا ضربوا الأرض أو كانوا',
    ]) {
      expect(join(spoken), isNot(retained), reason: spoken);
    }
  });

  int joinedWords(String key, String expected, int kept, String spoken) {
    final retained = comparison.recitationWords(expected).take(kept).join(' ');
    final joined = comparison.joinRecitationSegment(
      retainedPrefix: retained,
      spokenText: spoken,
      expectedAyahs: [expected],
      expectedVerseKeys: [key],
      allowWrittenOpenings: true,
    );
    return comparison
        .matchingPrefixWordCounts(
          expectedAyahs: [expected],
          expectedVerseKeys: [key],
          spokenText: joined,
          allowWrittenOpenings: true,
        )
        .single;
  }

  test('live windows rejoin at the verified cursor, never past a gap', () {
    const fear =
        'واتقوا يوما لا تجزي نفس عن نفس شيئا ولا يقبل منها عدل ولا تنفعها شفاعة ولا هم ينصرون';
    expect(
      joinedWords('2:123', fear, 12, 'ولا تنفعها شفاعة ولا هم ينصرون'),
      18,
    );
    expect(
      joinedWords('2:123', fear, 12, 'منها عدل ولا تنفعها شفاعة ولا هم ينصرون'),
      18,
    );
    expect(joinedWords('2:123', fear, 12, 'ولا شفاعة ولا هم ينصرون'), 13);
    expect(joinedWords('2:123', fear, 9, 'ولا تنفعها شفاعة ولا هم ينصرون'), 9);

    const spend =
        'ها أنتم هؤلاء تدعون لتنفقوا في سبيل الله فمنكم من يبخل ومن يبخل فإنما يبخل عن نفسه والله الغني وأنتم الفقراء وإن تتولوا يستبدل قوما غيركم ثم لا يكونوا أمثالكم';
    expect(
      joinedWords('47:38', spend, 28, 'غيركم ثم لا يكونوا أمثالكم مسلمين'),
      30,
      reason: 'a hallucinated word after the ayah is dropped',
    );
    expect(
      joinedWords('47:38', spend, 26, 'لا يكونوا أمثالكم مسلمين'),
      lessThan(30),
    );
  });

  test('folded or resegmented ASR spellings keep every expected letter', () {
    const tied =
        'وقالت اليهود يد الله مغلولة غلت أيديهم ولعنوا بما قالوا بل يداه مبسوطتان';
    expect(
      ayahMatches('5:64', tied, tied.replaceFirst('مغلولة', 'مغلوله')),
      isTrue,
    );
    expect(
      ayahMatches('5:64', tied, tied.replaceFirst('مغلولة غلت', 'مغلوله')),
      isFalse,
    );
    const usury =
        'الذين يأكلون الربا لا يقومون إلا كما يقوم الذي يتخبطه الشيطان من المس';
    expect(
      ayahMatches(
        '2:275',
        usury,
        usury.replaceFirst('الربا لا يقومون', 'الربال ايقومون'),
      ),
      isTrue,
    );
    for (final wrong in ['الربال يقومون', 'الربال ايقوم']) {
      expect(
        ayahMatches(
          '2:275',
          usury,
          usury.replaceFirst('الربا لا يقومون', wrong),
        ),
        isFalse,
        reason: wrong,
      );
    }
  });

  test('verified verse spelling variants require two following words', () {
    for (final fixture in [
      (
        key: '2:196',
        expected: 'وأتموا الحج والعمرة لله',
        spoken: 'وأتم الحج والعمرة لله',
      ),
      (
        key: '2:286',
        expected: 'إن نسينا أو أخطأنا ربنا',
        spoken: 'إن سينا أو أخطأنا ربنا',
      ),
      (
        key: '9:36',
        expected: 'منها اثنا عشر شهرا في',
        spoken: 'منها اثنى عشر شهرا في',
      ),
      (
        key: '24:35',
        expected: 'نوره كمشكاة فيها مصباح المصباح',
        spoken: 'نوره كمشكات فيها مصباح المصباح',
      ),
      (
        key: '48:25',
        expected: 'الهدي أن يبلغ محله ولولا رجال',
        spoken: 'الهدي أن يبلغ محلة ولولا رجال',
      ),
    ]) {
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: fixture.expected,
              expectedVerseKey: fixture.key,
              spokenText: fixture.spoken,
              allowWrittenOpenings: true,
            )
            .matched,
        isTrue,
        reason: fixture.key,
      );
      final words = comparison.recitationWords(fixture.spoken);
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: fixture.expected,
              expectedVerseKey: fixture.key,
              spokenText: words.take(words.length - 1).join(' '),
              allowWrittenOpenings: true,
            )
            .matched,
        isFalse,
        reason: '${fixture.key} needs its second right anchor',
      );
    }
  });

  test(
    'rolling ASR can resume at the exact hidden cursor after noisy context',
    () {
      const expected =
          'لا تقربوا الصلاة وأنتم سكارى حتى تعلموا ما تقولون ولا جنبا';
      final retained = comparison.recitationWords(expected).take(6).join(' ');
      final joined = comparison.joinRecitationSegment(
        retainedPrefix: retained,
        spokenText: 'وأمسكا راحتا تعلموا ما تقولون ولا جنبا',
        expectedAyahs: const [expected],
        expectedVerseKeys: const ['4:43'],
        allowWrittenOpenings: true,
      );

      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: const [expected],
          expectedVerseKeys: const ['4:43'],
          spokenText: joined,
          allowWrittenOpenings: true,
        ),
        [11],
      );
      final missingCursor = comparison.joinRecitationSegment(
        retainedPrefix: retained,
        spokenText: 'وأمسكا راحتا ما تقولون ولا جنبا',
        expectedAyahs: const [expected],
        expectedVerseKeys: const ['4:43'],
        allowWrittenOpenings: true,
      );
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: const [expected],
          expectedVerseKeys: const ['4:43'],
          spokenText: missingCursor,
          allowWrittenOpenings: true,
        ),
        [6],
      );
    },
  );

  test('rolling ASR requires both remaining terminal words after noise', () {
    const expected = 'والله على كل شيء قدير';
    const retained = 'والله على كل';
    final joined = comparison.joinRecitationSegment(
      retainedPrefix: retained,
      spokenText: 'يسلت رسله شيء قدير',
      expectedAyahs: const [expected],
      expectedVerseKeys: const ['59:6'],
      allowWrittenOpenings: true,
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: const [expected],
        expectedVerseKeys: const ['59:6'],
        spokenText: joined,
        allowWrittenOpenings: true,
      ),
      [5],
    );
    final missing = comparison.joinRecitationSegment(
      retainedPrefix: retained,
      spokenText: 'يسلت رسله قدير',
      expectedAyahs: const [expected],
      expectedVerseKeys: const ['59:6'],
      allowWrittenOpenings: true,
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: const [expected],
        expectedVerseKeys: const ['59:6'],
        spokenText: missing,
        allowWrittenOpenings: true,
      ),
      [3],
    );
  });

  test('rolling ASR confirms the last word with its retained predecessor', () {
    const expected = 'والله على كل شيء قدير';
    const retained = 'والله على كل شيء';
    final joined = comparison.joinRecitationSegment(
      retainedPrefix: retained,
      spokenText: 'ولكن الله يسلط رسله على كل شيء قدير',
      expectedAyahs: const [expected],
      expectedVerseKeys: const ['59:6'],
      allowWrittenOpenings: true,
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: const [expected],
        expectedVerseKeys: const ['59:6'],
        spokenText: joined,
        allowWrittenOpenings: true,
      ),
      [5],
    );
    final missingPredecessor = comparison.joinRecitationSegment(
      retainedPrefix: retained,
      spokenText: 'ولكن الله يسلط رسله قدير',
      expectedAyahs: const [expected],
      expectedVerseKeys: const ['59:6'],
      allowWrittenOpenings: true,
    );
    expect(
      comparison.matchingPrefixWordCounts(
        expectedAyahs: const [expected],
        expectedVerseKeys: const ['59:6'],
        spokenText: missingPredecessor,
        allowWrittenOpenings: true,
      ),
      [4],
    );
  });

  test('Hifz does not advance past an ambiguous Alif Lam Meem', () {
    const strict = SpeechComparisonService(requireExplicitAlifLamMeem: true);
    const ayahs = ['الم', 'ذلك الكتاب'];
    const keys = ['2:1', '2:2'];
    for (final opening in ['ألف لام', 'الٓمٓ']) {
      final text = '$opening ذلك الكتاب';
      expect(
        strict.matchingPrefixWordCounts(
          expectedAyahs: ayahs,
          expectedVerseKeys: keys,
          spokenText: text,
          allowWrittenOpenings: true,
        ),
        [0],
      );
      expect(
        strict
            .checkSequence(
              expectedAyahs: ayahs,
              expectedVerseKeys: keys,
              spokenText: text,
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        0,
      );
    }

    final joined = strict.joinRecitationSegment(
      retainedPrefix: 'ألف لام',
      spokenText: 'ميم ذلك الكتاب',
      expectedAyahs: ayahs,
      expectedVerseKeys: keys,
      allowWrittenOpenings: true,
    );
    expect(
      strict
          .checkSequence(
            expectedAyahs: ayahs,
            expectedVerseKeys: keys,
            spokenText: joined,
            allowWrittenOpenings: true,
          )
          .completedAyahs,
      2,
    );
  });
  const expected = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

  test(
    'Quran ASR joins exact split words without adding or removing letters',
    () {
      for (final (reference, transcript) in [
        ('فمن بدله بعدما سمعه', 'فمن بدله بعد ما سمعه'),
        ('فمن بدله بعدما', 'فمن بدله بعد ما'),
        ('وكذلك أنزلناه حكما عربيا', 'وك ذلك أنزلناه حكما عربيا'),
      ]) {
        expect(
          comparison
              .checkEntireAyah(
                expectedImlaei: reference,
                expectedVerseKey: '2:181',
                spokenText: transcript,
                allowWrittenOpenings: true,
              )
              .matched,
          isTrue,
          reason: transcript,
        );
        expect(
          comparison.matchingPrefixWordCounts(
            expectedAyahs: [reference],
            expectedVerseKeys: ['2:181'],
            spokenText: transcript,
            allowWrittenOpenings: true,
          ),
          [comparison.recitationWords(reference).length],
        );
        for (final literal in [true, false]) {
          expect(
            comparison
                .checkEntireAyah(
                  expectedImlaei: reference,
                  expectedVerseKey: '2:181',
                  spokenText: transcript,
                  allowWrittenOpenings: literal,
                  allowAsrCorrections: !literal,
                )
                .matched,
            isFalse,
            reason: 'Literal and platform matching remain unchanged',
          );
        }
        expect(
          comparison.literalAyahEvidence(
            expectedAyahs: [reference],
            expectedVerseKeys: ['2:181'],
            spokenText: transcript,
          ),
          [false],
        );
      }
    },
  );

  test('split-word recovery cannot bridge missing, wrong, or extra words', () {
    for (final transcript in [
      'فمن بدله بعد سمعه',
      'فمن بدله بعد نا سمعه',
      'فمن بدله بعد خطأ ما سمعه',
      'فمن بدله بعد ماا سمعه',
      'فمن بدله بعد ما سمعه خطأ',
    ]) {
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: 'فمن بدله بعدما سمعه',
              expectedVerseKey: '2:181',
              spokenText: transcript,
              allowWrittenOpenings: true,
            )
            .matched,
        isFalse,
        reason: transcript,
      );
    }
  });

  test(
    'literal ASR verification rejects corrections used for display recovery',
    () {
      const text = 'من بعد ما جاءتهم البينة';
      const spoken = 'من بعد ما جاءتون البينة';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [text],
              expectedVerseKeys: ['98:4'],
              spokenText: spoken,
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );
      final strict = comparison.checkSequence(
        expectedAyahs: [text],
        expectedVerseKeys: ['98:4'],
        spokenText: spoken,
        allowWrittenOpenings: true,
        allowAsrCorrections: false,
      );
      expect(strict.completedAyahs, 0);
      expect(strict.wordIndex, 3);
      expect(strict.mismatch, isTrue);
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: text,
              expectedVerseKey: '98:4',
              spokenText: spoken,
              allowWrittenOpenings: true,
              allowAsrCorrections: false,
            )
            .matched,
        isFalse,
      );
    },
  );

  test(
    'literal ASR verification supports written and spoken disconnected letters',
    () {
      for (final opening in ['الم', 'ألف لام ميم']) {
        expect(
          comparison
              .checkEntireAyah(
                expectedImlaei: 'الم',
                expectedVerseKey: '2:1',
                spokenText: opening,
                allowWrittenOpenings: true,
                allowAsrCorrections: false,
              )
              .matched,
          isTrue,
        );
      }
      expect(
        comparison
            .checkSequence(
              expectedAyahs: ['من بعد ما جاءتهم البينة', 'الم'],
              expectedVerseKeys: ['98:4', '2:1'],
              spokenText: 'من بعد ما جاءتهم البينة الم',
              allowWrittenOpenings: true,
              allowAsrCorrections: false,
            )
            .completedAyahs,
        2,
      );
    },
  );

  test(
    'literal evidence finds later exact ayahs without correcting earlier ones',
    () {
      expect(
        comparison.literalAyahEvidence(
          expectedAyahs: ['من بعد ما جاءتهم البينة', 'الحمد لله رب العالمين'],
          expectedVerseKeys: ['98:4', '1:2'],
          spokenText: 'من بعد ما جاءتون البينة الحمد لله رب العالمين',
        ),
        [false, true],
      );
      expect(
        comparison.literalAyahEvidence(
          expectedAyahs: ['الحمد لله رب العالمين', 'بسم الله الرحمن الرحيم'],
          expectedVerseKeys: ['1:2', '1:1'],
          spokenText: 'بسم الله الرحمن الرحيم الحمد لله رب العالمين',
        ),
        [true, false],
      );
    },
  );

  test('literal evidence consumes repeated ayahs only once', () {
    expect(
      comparison.literalAyahEvidence(
        expectedAyahs: ['ولا أنتم عابدون ما أعبد', 'ولا أنتم عابدون ما أعبد'],
        expectedVerseKeys: ['109:3', '109:5'],
        spokenText: 'ولا أنتم عابدون ما أعبد',
      ),
      [true, false],
    );
    for (final opening in ['الم', 'ألف لام ميم']) {
      expect(
        comparison.literalAyahEvidence(
          expectedAyahs: ['الم', 'الحمد لله رب العالمين'],
          expectedVerseKeys: ['2:1', '1:2'],
          spokenText: '$opening الحمد لله رب العالمين',
        ),
        [true, true],
      );
    }
  });

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

  test(
    'sliding window overlap skips up to four clipped boundary tokens when anchored by a suffix',
    () {
      const baqarah83 =
          'وإذ أخذنا ميثاق بني إسرائيل لا تعبدون إلا الله وبالوالدين إحسانا وذي القربى واليتامى والمساكين وقولوا للناس حسنا وأقيموا الصلاة وآتوا الزكاة ثم توليتم إلا قليلا منكم وأنتم معرضون';
      const clippedFinalWindow =
          'والناس حسنا وقولوا للناس حسنا وأقيموا الصلاة وآتوا الزكاة ثم توليتم إلا قليلا منكم وأنتم معرضون';
      final joined = comparison.joinRecitationSegment(
        retainedPrefix: baqarah83,
        spokenText: clippedFinalWindow,
        expectedAyahs: [baqarah83],
        expectedVerseKeys: ['2:83'],
        allowWrittenOpenings: true,
      );
      expect(
        comparison
            .checkEntireAyah(
              expectedImlaei: baqarah83,
              expectedVerseKey: '2:83',
              spokenText: joined,
              allowWrittenOpenings: true,
            )
            .matched,
        isTrue,
      );
    },
  );

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

  test(
    'recovers multi-reciter boundary consonant shifts, split/merged overlaps, and window-cut third anchor without skipping omitted words',
    () {
      // 2:228: ثلاثة قروء -> ثلاث تقروا / ثلاث تقروع
      const baqarah228Prefix = 'والمطلقات يتربصن بأنفسهن ثلاثة قروء ولا يحل لهن';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [baqarah228Prefix],
              expectedVerseKeys: ['2:228'],
              spokenText: 'والمطلقات يتربصن بأنفسهن ثلاث تقروا ولا يحل لهن',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [baqarah228Prefix],
              expectedVerseKeys: ['2:228'],
              spokenText: 'والمطلقات يتربصن بأنفسهن ثلاث ولا يحل لهن',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        0,
      );

      // 5:12: وبعثنا منهم اثني عشر نقيبا -> وبعثنا منه مثني عشر نقيبا
      const maidah12Clause = 'وبعثنا منهم اثني عشر نقيبا وقال الله إني معكم';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [maidah12Clause],
              expectedVerseKeys: ['5:12'],
              spokenText: 'وبعثنا منه مثني عشر نقيبا وقال الله إني معكم',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // 47:4: فإذا لقيتم الذين كفروا فضرب الرقاب -> فضربر رقاب
      const muhammad4Clause =
          'فإذا لقيتم الذين كفروا فضرب الرقاب حتى إذا أثخنتموهم';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [muhammad4Clause],
              expectedVerseKeys: ['47:4'],
              spokenText: 'فإذا لقيتم الذين كفروا فضربر رقاب حتى إذا أثخنتموهم',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // 4:23: window-cut 3rd confirmation word ('اللات' prefix of 'اللاتي') advances the 2 exact words
      const nisa23Clause =
          'وأمهات نسائكم وربائبكم اللاتي في حجوركم من نسائكم اللاتي دخلتم بهن';
      final joinedNisa23 = comparison.joinRecitationSegment(
        retainedPrefix: 'وأمهات',
        spokenText: 'وأمهات نسائكم وربائبكم اللات',
        expectedAyahs: [nisa23Clause],
        expectedVerseKeys: ['4:23'],
        allowWrittenOpenings: true,
      );
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: [nisa23Clause],
          expectedVerseKeys: ['4:23'],
          spokenText: joinedNisa23,
          allowWrittenOpenings: true,
        ),
        [3],
      );
    },
  );

  test(
    'recovers Pass 3 split-ya overlap, taa-marbuta syllable shift, and wasl merges without accepting omissions',
    () {
      // 24:33: retained 'وليستعفف' advances across 'وليستعف في الذين لا يجدون'
      const nur33Clause = 'وليستعفف الذين لا يجدون نكاحا حتى يغنيهم الله';
      final joinedNur33 = comparison.joinRecitationSegment(
        retainedPrefix: 'وليستعفف',
        spokenText: 'وليستعف في الذين لا يجدون نكاحا حتى يغنيهم الله',
        expectedAyahs: [nur33Clause],
        expectedVerseKeys: ['24:33'],
        allowWrittenOpenings: true,
      );
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: [nur33Clause],
          expectedVerseKeys: ['24:33'],
          spokenText: joinedNur33,
          allowWrittenOpenings: true,
        ),
        [8],
      );

      // 2:264: والأذى كالذي -> والأذاك الذي
      const baqarah264Clause = 'لا تبطلوا صدقاتكم بالمن والأذى كالذي ينفق ماله';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [baqarah264Clause],
              expectedVerseKeys: ['2:264'],
              spokenText: 'لا تبطلوا صدقاتكم بالمن والأذاك الذي ينفق ماله',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // 5:54: لومة لائم -> لو متلائم
      const maidah54Clause = 'ولا يخافون لومة لائم ذلك فضل الله';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [maidah54Clause],
              expectedVerseKeys: ['5:54'],
              spokenText: 'ولا يخافون لو متلائم ذلك فضل الله',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // 6:71 & 6:144: الهدى ائتنا -> الهدأتنا, الإبل اثنين -> الإبلسنين
      const anam71Clause = 'أصحابهم إلى الهدى ائتنا قل إن هدى الله';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [anam71Clause],
              expectedVerseKeys: ['6:71'],
              spokenText: 'أصحابهم إلى الهدأتنا قل إن هدى الله',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );
      const anam144Clause = 'ومن الإبل اثنين ومن البقر اثنين قل آلذكرين';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [anam144Clause],
              expectedVerseKeys: ['6:144'],
              spokenText: 'ومن الإبلسنين ومن البقرسنين قل آلذكرين',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // Negative check: omitted word still fails
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [anam144Clause],
              expectedVerseKeys: ['6:144'],
              spokenText: 'ومن الإبل ومن البقرسنين قل آلذكرين',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        0,
      );
    },
  );

  test(
    'Pass 4 recovers boundary consonant shifts and 2-to-3 phonetic splits without weakening strict checks',
    () {
      // 48:29: الزراع ليغيظ -> الزرى علي غيظ (2-to-3 phonetic split)
      const fath29Clause = 'يعجب الزراع ليغيظ بهم الكفار وعد الله';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [fath29Clause],
              expectedVerseKeys: ['48:29'],
              spokenText: 'يعجب الزرى علي غيظ بهم الكفار وعد الله',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // 23:47: أنؤمن لبشرين -> أنؤمنن بشرين (initial ل shifted as ن across boundary)
      const muminun47Clause = 'فقالوا أنؤمن لبشرين مثلنا وقومهما لنا عابدون';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [muminun47Clause],
              expectedVerseKeys: ['23:47'],
              spokenText: 'فقالوا أنؤمنن بشرين مثلنا وقومهما لنا عابدون',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // 13:11: من وال -> من والوال (final 3-letter token reduplication)
      const rad11Clause = 'وماله من دونه من وال';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [rad11Clause],
              expectedVerseKeys: ['13:11'],
              spokenText: 'وماله من دونه من والوال',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // Negative check: omitted word still fails
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [fath29Clause],
              expectedVerseKeys: ['48:29'],
              spokenText: 'يعجب الزرى بهم الكفار وعد الله',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        0,
      );
    },
  );

  test(
    'Pass 5 recovers hamza-folded splits and 24:35 Light Verse phonetic shifts without allowing omissions',
    () {
      // 24:35: الزجاجة كأنها كوكب دري يوقد من شجرة
      const nur35Clause = 'المصباح في زجاجة الزجاجة كأنها كوكب دري يوقد من شجرة';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [nur35Clause],
              expectedVerseKeys: ['24:35'],
              spokenText: 'المصباح في زجاجة أز زجاجتك أنها كوكب ذري يوقد من شجرة',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // 2:221: ولعبد مؤمن -> ولعبدوا انمؤمن (boundary shift)
      const baqarah221Clause = 'حتى يؤمنوا ولعبد مؤمن خير من مشرك';
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [baqarah221Clause],
              expectedVerseKeys: ['2:221'],
              spokenText: 'حتى يؤمنوا ولعبدوا انمؤمن خير من مشرك',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        1,
      );

      // Negative check: omitting كوكب still fails
      expect(
        comparison
            .checkSequence(
              expectedAyahs: [nur35Clause],
              expectedVerseKeys: ['24:35'],
              spokenText: 'المصباح في زجاجة أز زجاجتك أنها ذري يوقد من شجرة',
              allowWrittenOpenings: true,
            )
            .completedAyahs,
        0,
      );
    },
  );

  test(
    'a right word followed by a wrong word never auto-completes or advances via retained prefix',
    () {
      // 2:12 (cloud bundle 2_1_d0f2090c): 6 of 7 words retained, followed by
      // an unanchored or wrong 2-word window ('يشعرون يعلمون' or 'لا يعلمون')
      // must not auto-complete the final word 'يشعرون'.
      const baqarah12 = 'ألا إنهم هم المفسدون ولكن لا يشعرون';
      const baqarah12Retained = 'ألا إنهم هم المفسدون ولكن لا';
      for (final window in [
        'يشعرون يعلمون',
        'لا يعلمون',
        'ولكن لا يعلمون',
        'لا يشعروهم يعلمون',
      ]) {
        final joined = comparison.joinRecitationSegment(
          retainedPrefix: baqarah12Retained,
          spokenText: window,
          expectedAyahs: [baqarah12],
          expectedVerseKeys: ['2:12'],
          allowWrittenOpenings: true,
        );
        expect(
          comparison.matchingPrefixWordCounts(
            expectedAyahs: [baqarah12],
            expectedVerseKeys: ['2:12'],
            spokenText: joined,
            allowWrittenOpenings: true,
          ),
          [6],
          reason: 'Window "$window" should not auto-complete 2:12',
        );
        expect(
          comparison
              .checkSequence(
                expectedAyahs: [baqarah12],
                expectedVerseKeys: ['2:12'],
                spokenText: joined,
                allowWrittenOpenings: true,
              )
              .completedAyahs,
          0,
          reason: 'Window "$window" should not complete 2:12',
        );
      }

      // 2:17 (cloud bundle 2_18_f34ad969): 8 of 17 words retained ('... ما'),
      // followed by a 2-word window ('حوله غلط', 'ما غلط', or 'أضاءت ما غلط')
      // must not advance the revealed prefix past word 8.
      const baqarah17 =
          'مثلهم كمثل الذي استوقد نارا فلما أضاءت ما حوله ذهب الله بنورهم وتركهم في ظلمات لا يبصرون';
      const baqarah17Retained8 = 'مثلهم كمثل الذي استوقد نارا فلما أضاءت ما';
      for (final window in [
        'حوله غلط',
        'ما غلط',
        'أضاءت ما غلط',
      ]) {
        final joined = comparison.joinRecitationSegment(
          retainedPrefix: baqarah17Retained8,
          spokenText: window,
          expectedAyahs: [baqarah17],
          expectedVerseKeys: ['2:17'],
          allowWrittenOpenings: true,
        );
        expect(
          comparison.matchingPrefixWordCounts(
            expectedAyahs: [baqarah17],
            expectedVerseKeys: ['2:17'],
            spokenText: joined,
            allowWrittenOpenings: true,
          ),
          [8],
          reason: 'Window "$window" should keep 2:17 at 8 words',
        );
      }

      // Multi-ayah repeated opening anchor (e.g., 2:11 'وإذا قيل لهم لا ...'
      // and 2:13 'وإذا قيل لهم آمنوا ...'): when retained ends at the repeated
      // 2-word opening of 2:11 ('وإذا قيل'), a 2-word window from a wrong/later
      // verse ('وإذا قيل غلط') must not false-anchor or advance 2:11.
      const baqarah11 = 'وإذا قيل لهم لا تفسدوا في الأرض قالوا إنما نحن مصلحون';
      const baqarah13 = 'وإذا قيل لهم آمنوا كما آمن الناس';
      final joinedRepeatedAnchor = comparison.joinRecitationSegment(
        retainedPrefix: 'وإذا قيل',
        spokenText: 'وإذا قيل آمنوا',
        expectedAyahs: [baqarah11, baqarah13],
        expectedVerseKeys: ['2:11', '2:13'],
        allowWrittenOpenings: true,
      );
      expect(
        comparison.matchingPrefixWordCounts(
          expectedAyahs: [baqarah11, baqarah13],
          expectedVerseKeys: ['2:11', '2:13'],
          spokenText: joinedRepeatedAnchor,
          allowWrittenOpenings: true,
        ),
        [2],
      );
    },
  );
}
