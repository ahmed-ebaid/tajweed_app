import 'package:flutter_test/flutter_test.dart';
import 'package:tajweed_practice/core/models/tajweed_models.dart';
import 'package:tajweed_practice/features/quiz/quiz_repository.dart';
import 'package:tajweed_practice/features/rules/rule_example_references.dart';
import 'package:tajweed_practice/features/rules/rules_repository.dart';
import 'package:tajweed_practice/features/rules/tajweed_articles_repository.dart';
import 'package:tajweed_practice/features/rules/waqf_symbols.dart';
import 'package:tajweed_practice/features/rules/widgets/sukoon_comparison.dart';

void main() {
  test('izhar quiz preserves the separate Quranic hamza and its highlight', () {
    final definition = RulesRepository.findByRule(TajweedRule.izhar)!;
    expect(definition.exampleArabic.first, 'مَنۡ ءَامَنَ');
    final questions = QuizRepository.all.where(
      (question) =>
          question.rule == TajweedRule.izhar &&
          question.arabicText == definition.exampleArabic.first,
    );
    expect(questions, isNotEmpty);
    expect(
      QuizRepository.questionLevel(TajweedRule.izhar),
      QuizLevel.intermediate,
    );
    for (final question in questions) {
      expect(question.options[question.correctIndex], definition.names);
      final range = question.highlightRanges.single;
      expect(question.arabicText.substring(range.start, range.end), 'نۡ ءَ');
      expect(question.arabicText, isNot(contains('آ')));
      expect(question.arabicText, isNot(contains('\u0653')));
    }
  });

  test('opening-letter madd guidance reaches every locale and quiz', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
    for (final rule in [
      TajweedRule.maddTabeei,
      TajweedRule.maddLazimHarfiMuthaqqal,
      TajweedRule.maddLazimHarfiMukhaffaf,
    ]) {
      final definition = RulesRepository.findByRule(rule)!;
      for (final languageCode in languageCodes) {
        final description = definition.descriptions[languageCode]!;
        expect(description, contains('حي طهر'));
        expect(description, contains('حمٓ'));
        if (rule != TajweedRule.maddTabeei) {
          expect(description, contains('ن ق ص س ل ك م'));
          expect(description, contains('الٓمٓ'));
          expect(description, contains(languageCode == 'ar' ? 'العين' : 'ع'));
        }
        for (final question in QuizRepository.all.where(
          (q) => q.rule == rule,
        )) {
          expect(question.explanation[languageCode], contains(description));
        }
      }
    }
    final arabic = RulesRepository.findByRule(
      TajweedRule.maddLazimHarfiMukhaffaf,
    )!.description('ar');
    expect(arabic, contains('٤ أو ٦'));
    expect(arabic, contains('الألف لا تمد'));
    expect(arabic, contains('الحاء حركتان، والميم ٦ حركات'));
  });

  test('silent-letter guidance scopes rounded zero to marked ا و ي', () {
    const languages = {
      'en': 'it does not make every',
      'ar': 'وليس معنى ذلك أن كل',
      'ur': 'یہ نہیں کہ ہر',
      'tr': 'her ا، و، ي harfinin okunmadığı anlamına gelmez',
      'fr': 'il ne rend pas muettes toutes',
      'id': 'bukan berarti semua',
      'de': 'es macht nicht alle',
      'es': 'no vuelve mudas todas',
    };
    final definition = RulesRepository.findByRule(TajweedRule.silent)!;
    for (final entry in languages.entries) {
      final description = definition.description(entry.key);
      expect(description, contains('ا'));
      expect(description, contains('و'));
      expect(description, contains('ي'));
      expect(
        description,
        contains(entry.value),
        reason:
            '${entry.key} must clarify that unmarked letters are not silent',
      );
      expect(
        SukoonComparison.labels[entry.key]![2],
        contains('ا، و، ي'),
        reason: '${entry.key} comparison must scope the rounded-zero mark',
      );
    }
  });

  test('rules repository covers every tajweed rule exactly once', () {
    final definedRules = RulesRepository.all
        .map((definition) => definition.rule)
        .toList();

    expect(definedRules, hasLength(TajweedRule.values.length));
    expect(definedRules.toSet(), equals(TajweedRule.values.toSet()));
  });

  test('every tajweed rule has an example ayah reference', () {
    for (final rule in TajweedRule.values) {
      final ref = RuleExampleReferences.referenceFor(rule);
      expect(ref, isNotNull, reason: 'Missing example ayah for ${rule.name}');
      expect(ref!.surah, inInclusiveRange(1, 114));
      expect(ref.ayah, greaterThan(0));
    }
  });

  test('shaddah uses the simple rabb example from Al-Fatiha 1:2', () {
    final ref = RuleExampleReferences.referenceFor(TajweedRule.shaddah);

    expect(ref, isNotNull);
    expect(ref!.surah, 1);
    expect(ref.ayah, 2);
    expect(
      RuleExampleReferences.forcedHighlightWordIndices[TajweedRule.shaddah],
      {2},
    );
  });

  test('hamzat al-qat uses the clear iyyaka example from Al-Fatiha 1:5', () {
    final ref = RuleExampleReferences.referenceFor(TajweedRule.hamzatQat);

    expect(ref, isNotNull);
    expect(ref!.surah, 1);
    expect(ref.ayah, 5);
    expect(
      RuleExampleReferences.forcedHighlightWordIndices[TajweedRule.hamzatQat],
      {0, 2},
    );
  });

  test('hamzat wasl and qat Quran examples are included in their quizzes', () {
    for (final rule in [TajweedRule.hamzatWasl, TajweedRule.hamzatQat]) {
      final definition = RulesRepository.findByRule(rule)!;
      final quizExamples = QuizRepository.all
          .where((question) => question.rule == rule)
          .map((question) => question.arabicText)
          .toSet();

      expect(
        quizExamples,
        containsAll(definition.exampleArabic),
        reason: 'Missing Quran quiz examples for ${rule.name}',
      );
    }
  });

  test('both hamza rules are localized in every supported language', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];

    for (final rule in [TajweedRule.hamzatWasl, TajweedRule.hamzatQat]) {
      final definition = RulesRepository.findByRule(rule)!;
      for (final languageCode in languageCodes) {
        expect(
          definition.names[languageCode],
          isNotEmpty,
          reason: 'Missing $languageCode name for ${rule.name}',
        );
        expect(
          definition.descriptions[languageCode],
          isNotEmpty,
          reason: 'Missing $languageCode description for ${rule.name}',
        );
      }
    }
  });

  test(
    'hamzat al-wasl explains how to choose its starting vowel in Arabic',
    () {
      final description = RulesRepository.findByRule(
        TajweedRule.hamzatWasl,
      )!.description('ar');

      expect(description, contains('عند البدء'));
      expect(description, contains('تُفتح'));
      expect(description, contains('تُكسر'));
      expect(description, contains('يُضم'));
      expect(description, contains('ٱلۡحَمۡدُ'));
      expect(description, contains('ٱهۡدِنَا'));
      expect(description, contains('ٱدۡخُلُوا'));
      expect(description, contains('ٱضۡرِبُوا'));
      expect(description, contains('مع عدّ الألف أولًا'));
      expect(description, contains('الضمة العارضة'));
      expect(description, contains('ٱمۡشُوا'));
      expect(description, contains('وليس لمجرد وجود لام'));
    },
  );

  test('Hamzat al-Wasl examples use small-head sukoon, never rounded zero', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
    const quranicSukoon = '\u06E1';
    const ordinaryArabicSukoon = '\u0652';
    const roundedZero = '\u06DF';
    const markedExamples = [
      'ٱهۡدِنَا',
      'ٱلۡحَمۡدُ',
      'ٱسۡتَغۡفِرُوا',
      'ٱدۡخُلُوا',
      'يَدۡخُلُ',
      'ٱضۡرِبُوا',
      'يَضۡرِبُ',
    ];
    final definition = RulesRepository.findByRule(TajweedRule.hamzatWasl)!;

    expect(definition.exampleArabic, [
      'ٱهۡدِنَا',
      'ٱلۡحَمۡدُ',
      'ٱسۡتَغۡفِرُوا',
    ]);
    for (final example in definition.exampleArabic) {
      expect(example, contains(quranicSukoon));
      expect(example, isNot(contains(ordinaryArabicSukoon)));
      expect(example, isNot(contains(roundedZero)));
    }
    for (final languageCode in languageCodes) {
      final description = definition.description(languageCode);
      for (final example in markedExamples) {
        expect(
          description,
          contains(example),
          reason: '$languageCode is missing $example',
        );
      }
      expect(description, isNot(contains(ordinaryArabicSukoon)));
      expect(description, isNot(contains(roundedZero)));
    }
  });

  test('all rule and quiz examples use Quranic small-head sukoon', () {
    for (final definition in RulesRepository.all) {
      for (final example in definition.exampleArabic) {
        expect(
          example,
          isNot(contains('\u0652')),
          reason: definition.rule.name,
        );
      }
    }
    for (final question in QuizRepository.all) {
      expect(
        question.arabicText,
        isNot(contains('\u0652')),
        reason: question.rule.name,
      );
      for (final range in question.highlightRanges) {
        expect(range.start, greaterThanOrEqualTo(0));
        expect(range.end, lessThanOrEqualTo(question.arabicText.length));
        expect(range.end, greaterThan(range.start));
      }
    }
    expect(RulesRepository.findByRule(TajweedRule.qalqalah)!.exampleArabic, [
      'قَدۡ',
      'يَبۡسُطُ',
      'تَجۡرِى',
    ]);
    expect(
      RulesRepository.findByRule(TajweedRule.silent)!.exampleArabic,
      everyElement(contains('\u06DF')),
    );
  });

  test('ghunnah articulation and wasl steps reach all quiz locales', () {
    const languages = {
      'en': ['tip of the tongue', 'two lips', 'not the articulation point'],
      'ar': ['طرف اللسان', 'الشفتين', 'مخرج الغنة فقط'],
      'ur': ['زبان کی نوک', 'ہونٹوں', 'خیشوم'],
      'tr': ['dil ucunun', 'iki dudakla', 'kendi mahreci değildir'],
      'fr': ['pointe de la langue', 'deux lèvres', 'et non'],
      'id': ['ujung lidah', 'kedua bibir', 'bukan makhraj'],
      'de': ['Zungenspitze', 'beiden Lippen', 'nicht die Artikulationsstelle'],
      'es': ['punta de la lengua', 'ambos labios', 'no el punto'],
    };
    for (final entry in languages.entries) {
      final ghunnah = RulesRepository.findByRule(TajweedRule.ghunnah)!;
      for (final phrase in entry.value) {
        expect(ghunnah.description(entry.key), contains(phrase));
      }
      final wasl = RulesRepository.findByRule(TajweedRule.hamzatWasl)!;
      expect(wasl.description(entry.key).split('\n'), hasLength(5));
      for (final example in ['ٱلۡحَمۡدُ', 'ٱدۡخُلُوا', 'ٱمۡشُوا', 'اِمۡشِ']) {
        expect(wasl.description(entry.key), contains(example));
      }
      for (final rule in [ghunnah, wasl]) {
        for (final question in QuizRepository.all.where(
          (question) => question.rule == rule.rule,
        )) {
          expect(
            question.explanation[entry.key],
            contains(rule.description(entry.key)),
          );
        }
      }
    }
  });

  test(
    'tafkhim pairs every degree with the same-letter example in all locales',
    () {
      final article = TajweedArticlesRepository.all.singleWhere(
        (a) => a.id == 'tafkhim',
      );
      for (final language in TajweedArticlesRepository.supportedLanguageCodes) {
        final body = article.bodies[language]!;
        final degrees = body.split('\n\n')[1];
        final examples = ['قَالَ', 'قَتَلَ', 'قُلۡ', 'يَقۡطَعُونَ', 'قِيلَ'];
        var previous = -1;
        for (final example in examples) {
          final index = degrees.indexOf(example);
          expect(index, greaterThan(previous), reason: '$language: $example');
          previous = index;
        }
        expect(degrees, isNot(contains('\u0652')));
      }
    },
  );

  test(
    'silent-letter rule distinguishes rounded zero from ordinary sukoon',
    () {
      const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
      final definition = RulesRepository.findByRule(TajweedRule.silent)!;

      expect(TajweedRule.silent.arabicName, 'حَرْف زَائِد لَا يُنْطَق');
      expect(TajweedRule.silent.arabicName, isNot('حَرْف سَاكِن'));
      expect(definition.description('ar'), contains('الصفر المستدير'));
      expect(definition.description('ar'), contains('۟'));
      expect(definition.description('ar'), contains('ۡ'));

      for (final languageCode in languageCodes) {
        expect(
          definition.names[languageCode],
          isNotEmpty,
          reason: 'Missing $languageCode name for ${definition.rule.name}',
        );
        expect(
          definition.descriptions[languageCode],
          contains('۟'),
          reason: 'Missing rounded-zero explanation for $languageCode',
        );
        expect(
          definition.descriptions[languageCode],
          contains('ۡ'),
          reason: 'Missing ordinary-sukoon distinction for $languageCode',
        );
      }
    },
  );

  test('waqf uses an ayah with a clear obligatory-stop marker', () {
    final ref = RuleExampleReferences.referenceFor(TajweedRule.waqf);

    expect(ref, isNotNull);
    expect(ref!.surah, 6);
    expect(ref.ayah, 36);
    expect(
      RuleExampleReferences.forcedMarkersAfterWordIndices[TajweedRule.waqf],
      {3: 'ۘ'},
    );
  });

  test('waqf symbol guidance is localized in every supported language', () {
    const languageCodes = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
    final keys = <String>['title'];
    for (var index = 0; index < 7; index++) {
      keys
        ..add('name_$index')
        ..add('description_$index');
    }

    for (final languageCode in languageCodes) {
      final strings = WaqfRuleStrings(languageCode);
      for (final key in keys) {
        expect(
          strings.text(key),
          isNot(key),
          reason: 'Missing $key for $languageCode',
        );
      }
    }
  });

  test('every Waqf sign section has a Quran example containing its mark', () {
    expect(WaqfSymbols.examples, hasLength(7));
    for (final example in WaqfSymbols.examples) {
      expect(example.displaySymbol.trim(), isNotEmpty);
      expect(example.arabicText, contains(example.quranSymbol));
      expect(
        example.arabicText.length,
        greaterThan(example.quranSymbol.length),
      );
    }
  });

  test('shared Waqf text lists every sign with its meaning and example', () {
    final lines = WaqfSymbols.shareLines('en', examplesLabel: 'Example');

    for (final example in WaqfSymbols.examples) {
      expect(
        lines,
        contains(
          '${example.displaySymbol} — '
          '${WaqfRuleStrings('en').text('name_${example.index}')}',
        ),
      );
      expect(lines, contains('Example: ${example.arabicText}'));
    }
    expect(lines, isNot(contains('How to Pronounce')));
  });

  test(
    'qalqalah Arabic description says kubra at the end and sughra in the middle',
    () {
      final description = RulesRepository.findByRule(
        TajweedRule.qalqalah,
      )!.description('ar');

      expect(description, contains('صغرى'));
      expect(description, contains('كبرى'));
      expect(description, contains('وسط الكلمة'));
      expect(description, contains('آخر الكلمة'));
    },
  );

  test(
    'every rule has a substantial description in all supported languages',
    () {
      const langs = ['en', 'ar', 'ur', 'tr', 'fr', 'id', 'de', 'es'];
      for (final rule in TajweedRule.values) {
        final def = RulesRepository.findByRule(rule)!;
        for (final lang in langs) {
          expect(
            def.names[lang]?.trim(),
            isNotEmpty,
            reason: '${rule.name} has no $lang name',
          );
          final text = def.description(lang);
          expect(
            text.trim().length,
            greaterThanOrEqualTo(40),
            reason: '${rule.name} / $lang is too short: "$text"',
          );
        }
      }
    },
  );

  test('madd rules state which harakah must precede the madd letter', () {
    const fatha =
        '\u0627\u0644\u0645\u0641\u062a\u0648\u062d \u0645\u0627 \u0642\u0628\u0644\u0647\u0627';
    const damma =
        '\u0627\u0644\u0645\u0636\u0645\u0648\u0645 \u0645\u0627 \u0642\u0628\u0644\u0647\u0627';
    const kasra =
        '\u0627\u0644\u0645\u0643\u0633\u0648\u0631 \u0645\u0627 \u0642\u0628\u0644\u0647\u0627';
    for (final rule in [TajweedRule.maddTabeei, TajweedRule.maddAridLissukun]) {
      final text = RulesRepository.findByRule(rule)!.description('ar');
      for (final condition in [fatha, damma, kasra]) {
        expect(text, contains(condition), reason: rule.name);
      }
    }
    // Madd lin is the contrast case: a sakin waw/ya preceded by a fatha.
    expect(
      RulesRepository.findByRule(TajweedRule.maddLin)!.description('ar'),
      contains(
        '\u0627\u0644\u0645\u0641\u062a\u0648\u062d \u0645\u0627 \u0642\u0628\u0644\u0647\u0627',
      ),
    );
  });

  test('Arabic madd descriptions show numeric count ranges', () {
    const expectedCounts = {
      TajweedRule.maddTabeei: '٢ حركة',
      TajweedRule.maddMuttasil: '٤–٥ حركات',
      TajweedRule.maddMunfasil: '٢–٥ حركات',
      TajweedRule.maddSilahSughra: '٢ حركة',
      TajweedRule.maddSilahKubra: '٤–٥ حركات',
      TajweedRule.maddLazimKalimiMuthaqqal: '٦ حركات',
      TajweedRule.maddLazimKalimiMukhaffaf: '٦ حركات',
      TajweedRule.maddLazimHarfiMuthaqqal: '٦ حركات',
      TajweedRule.maddLazimHarfiMukhaffaf: '٦ حركات',
    };

    for (final entry in expectedCounts.entries) {
      final description = RulesRepository.findByRule(
        entry.key,
      )!.description('ar');
      expect(description, contains(entry.value), reason: entry.key.name);
    }
  });
}
