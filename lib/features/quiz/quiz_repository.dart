import 'dart:math';

import '../../core/models/tajweed_models.dart';
import '../rules/rule_example_highlight.dart';
import '../rules/rules_repository.dart';
import '../rules/waqf_symbols.dart';

enum QuizLevel { beginner, intermediate, advanced }

class QuizLevelDefinition {
  final QuizLevel level;
  final String titleKey;
  final String subtitleKey;
  final List<TajweedRule> rules;

  const QuizLevelDefinition({
    required this.level,
    required this.titleKey,
    required this.subtitleKey,
    required this.rules,
  });
}

/// Generates a balanced quiz bank from known tajweed rules.
class QuizRepository {
  static const int passPercentage = 70;
  static final List<QuizQuestion> all = _buildQuestions();

  static const List<QuizLevelDefinition> levels = [
    QuizLevelDefinition(
      level: QuizLevel.beginner,
      titleKey: 'quiz_level_beginner',
      subtitleKey: 'quiz_level_beginner_subtitle',
      rules: [
        TajweedRule.ghunnah,
        TajweedRule.maddTabeei,
        TajweedRule.shaddah,
        TajweedRule.qalqalah,
        TajweedRule.waqf,
      ],
    ),
    QuizLevelDefinition(
      level: QuizLevel.intermediate,
      titleKey: 'quiz_level_intermediate',
      subtitleKey: 'quiz_level_intermediate_subtitle',
      rules: [
        TajweedRule.ikhfa,
        TajweedRule.iqlab,
        TajweedRule.izhar,
        TajweedRule.idghamWithGhunnah,
        TajweedRule.idghamWithoutGhunnah,
        TajweedRule.hamzatWasl,
        TajweedRule.hamzatQat,
        TajweedRule.laamShamsiyah,
      ],
    ),
    QuizLevelDefinition(
      level: QuizLevel.advanced,
      titleKey: 'quiz_level_advanced',
      subtitleKey: 'quiz_level_advanced_subtitle',
      rules: [
        TajweedRule.maddMuttasil,
        TajweedRule.maddMunfasil,
        TajweedRule.maddLazimKalimiMuthaqqal,
        TajweedRule.maddLazimKalimiMukhaffaf,
        TajweedRule.maddLazimHarfiMuthaqqal,
        TajweedRule.maddLazimHarfiMukhaffaf,
        TajweedRule.maddAridLissukun,
        TajweedRule.maddLin,
        TajweedRule.maddSilahSughra,
        TajweedRule.maddSilahKubra,
        TajweedRule.idghamShafawi,
        TajweedRule.idghamMutajanisayn,
        TajweedRule.ikhfaShafawi,
        TajweedRule.sajdah,
        TajweedRule.silent,
      ],
    ),
  ];

  static QuizLevelDefinition definitionFor(QuizLevel level) =>
      levels.firstWhere((entry) => entry.level == level);

  static QuizLevel? nextLevelAfter(QuizLevel level) {
    final nextIndex = level.index + 1;
    if (nextIndex >= QuizLevel.values.length) return null;
    return QuizLevel.values[nextIndex];
  }

  static List<QuizQuestion> randomizedUnique({QuizLevel? level}) {
    final filtered = level == null
        ? all
        : all
              .where((question) => questionLevel(question.rule) == level)
              .toList();
    final shuffled = [...filtered]..shuffle(Random());
    final unique = <QuizQuestion>[];
    final seen = <String>{};

    for (final q in shuffled) {
      final correctNameEn = q.options[q.correctIndex]['en'] ?? '';
      final key = '${q.arabicText}|$correctNameEn';
      if (seen.add(key)) {
        unique.add(q);
      }
    }

    return unique;
  }

  static QuizLevel questionLevel(TajweedRule rule) {
    for (final level in levels) {
      if (level.rules.contains(rule)) {
        return level.level;
      }
    }
    return QuizLevel.beginner;
  }

  static List<QuizQuestion> _buildQuestions() {
    final rules = RulesRepository.all;
    final questions = <QuizQuestion>[];

    for (int ri = 0; ri < rules.length; ri++) {
      if (rules[ri].rule == TajweedRule.waqf) {
        questions.addAll(_buildWaqfQuestions());
        continue;
      }
      if (rules[ri].rule == TajweedRule.sajdah) {
        questions.add(_buildSajdahQuestion(rules[ri]));
        continue;
      }
      for (int variant = 0; variant < 5; variant++) {
        questions.add(_buildQuestionForRule(rules, ri, variant));
      }
    }

    return questions;
  }

  static QuizQuestion _buildQuestionForRule(
    List<TajweedRuleDefinition> rules,
    int ruleIndex,
    int variant,
  ) {
    final target = rules[ruleIndex];
    final wrong1 = rules[(ruleIndex + variant + 1) % rules.length];
    final wrong2 = rules[(ruleIndex + variant + 3) % rules.length];
    final wrong3 = rules[(ruleIndex + variant + 5) % rules.length];

    final correctOption = _nameMap(target);
    final wrongOptions = [_nameMap(wrong1), _nameMap(wrong2), _nameMap(wrong3)];

    final correctIndex = (ruleIndex + variant) % 4;
    final options = <Map<String, String>>[];
    int wrongCursor = 0;
    for (int i = 0; i < 4; i++) {
      if (i == correctIndex) {
        options.add(correctOption);
      } else {
        options.add(wrongOptions[wrongCursor]);
        wrongCursor++;
      }
    }

    final arabic = target.exampleArabic.isEmpty
        ? target.triggerLetters.join('')
        : target.exampleArabic[variant % target.exampleArabic.length];
    final highlight = _highlightRange(
      target.rule,
      arabic,
      variant % target.exampleArabic.length,
    );

    return QuizQuestion(
      rule: target.rule,
      arabicText: arabic,
      highlightRanges: [
        QuizHighlightRange(start: highlight.start, end: highlight.end),
      ],
      questionText: _questionTemplate(variant),
      options: options,
      correctIndex: correctIndex,
      explanation: _explanationTemplate(target, variant),
    );
  }

  static List<QuizQuestion> _buildWaqfQuestions() {
    return [
      for (final example in WaqfSymbols.examples) _buildWaqfQuestion(example),
    ];
  }

  static QuizQuestion _buildWaqfQuestion(WaqfSymbolExample example) {
    final correctIndex = example.index % 4;
    final wrongIndexes = [
      (example.index + 1) % WaqfSymbols.examples.length,
      (example.index + 3) % WaqfSymbols.examples.length,
      (example.index + 5) % WaqfSymbols.examples.length,
    ];
    final options = <Map<String, String>>[];
    var wrongCursor = 0;

    for (var index = 0; index < 4; index++) {
      options.add(
        _waqfStringMap(
          'name_${index == correctIndex ? example.index : wrongIndexes[wrongCursor++]}',
        ),
      );
    }

    return QuizQuestion(
      rule: TajweedRule.waqf,
      arabicText: example.arabicText,
      highlightRanges: _rangesForSymbol(
        example.arabicText,
        example.quranSymbol,
      ),
      questionText: _waqfQuestionTemplate,
      options: options,
      correctIndex: correctIndex,
      explanation: {
        for (final langCode in _supportedLanguageCodes)
          langCode:
              '${WaqfRuleStrings(langCode).text('name_${example.index}')}: '
              '${WaqfRuleStrings(langCode).text('description_${example.index}')}',
      },
    );
  }

  /// The sajdah glyph is a mushaf notation marker, not a pronunciation
  /// ruling, so it gets a dedicated prompt (mirroring the Waqf treatment)
  /// with notation-style distractors instead of tajweed rule names.
  static QuizQuestion _buildSajdahQuestion(TajweedRuleDefinition def) {
    final arabic = def.exampleArabic.isEmpty
        ? _sajdahSymbol
        : def.exampleArabic.first;
    final highlight = _highlightRange(TajweedRule.sajdah, arabic, 0);

    return QuizQuestion(
      rule: TajweedRule.sajdah,
      arabicText: arabic,
      highlightRanges: [
        QuizHighlightRange(start: highlight.start, end: highlight.end),
      ],
      questionText: _sajdahQuestionTemplate,
      options: _sajdahOptions,
      correctIndex: _sajdahCorrectIndex,
      explanation: _sajdahExplanation,
    );
  }

  static List<QuizHighlightRange> _rangesForSymbol(String text, String symbol) {
    final ranges = <QuizHighlightRange>[];
    var start = text.indexOf(symbol);
    while (start >= 0) {
      ranges.add(QuizHighlightRange(start: start, end: start + symbol.length));
      start = text.indexOf(symbol, start + symbol.length);
    }
    if (ranges.isEmpty) {
      throw StateError('Waqf symbol "$symbol" was not found in "$text"');
    }
    return ranges;
  }

  static Map<String, String> _waqfStringMap(String key) => {
    for (final langCode in _supportedLanguageCodes)
      langCode: WaqfRuleStrings(langCode).text(key),
  };

  static const _supportedLanguageCodes = [
    'en',
    'ar',
    'ur',
    'tr',
    'fr',
    'id',
    'de',
    'es',
  ];

  static const _waqfQuestionTemplate = {
    'en': 'What does the highlighted Waqf sign indicate?',
    'ar': 'ماذا تدل علامة الوقف الملوّنة؟',
    'ur': 'نمایاں وقف کی علامت کیا بتاتی ہے؟',
    'tr': 'Vurgulanan vakıf işareti neyi belirtir?',
    'fr': 'Que signifie le signe de waqf surligné ?',
    'id': 'Apa arti tanda waqaf yang disorot?',
    'de': 'Was bedeutet das hervorgehobene Waqf-Zeichen?',
    'es': '¿Qué indica el signo de waqf resaltado?',
  };

  static const _sajdahSymbol = '۩';

  static const _sajdahCorrectIndex = 2;

  static const _sajdahQuestionTemplate = {
    'en': 'What does the highlighted sign indicate?',
    'ar': 'ماذا تدل العلامة الملوّنة؟',
    'ur': 'نمایاں علامت کیا بتاتی ہے؟',
    'tr': 'Vurgulanan işaret neyi belirtir?',
    'fr': 'Que signifie le signe surligné ?',
    'id': 'Apa arti tanda yang disorot?',
    'de': 'Was bedeutet das hervorgehobene Zeichen?',
    'es': '¿Qué indica el signo resaltado?',
  };

  /// All four options are mushaf notation markers so the answer cannot be
  /// found by elimination against unrelated pronunciation rules.
  static const _sajdahOptions = <Map<String, String>>[
    {
      'en': 'Obligatory stop',
      'ar': 'وقف لازم',
      'ur': 'وقف لازم',
      'tr': 'Zorunlu durak',
      'fr': 'Arrêt obligatoire',
      'id': 'Berhenti wajib',
      'de': 'Verpflichtender Halt',
      'es': 'Pausa obligatoria',
    },
    {
      'en': 'End of hizb',
      'ar': 'نهاية الحزب',
      'ur': 'حزب کا اختتام',
      'tr': 'Hizb sonu',
      'fr': 'Fin du hizb',
      'id': 'Akhir hizb',
      'de': 'Ende des Hizb',
      'es': 'Fin del hizb',
    },
    {
      'en': 'Place of recitation prostration',
      'ar': 'موضع سجود التلاوة',
      'ur': 'سجدۂ تلاوت کا مقام',
      'tr': 'Tilavet secdesi yeri',
      'fr': 'Lieu de prosternation de récitation',
      'id': 'Tempat sujud tilawah',
      'de': 'Ort der Rezitationsniederwerfung',
      'es': 'Lugar de postración de recitación',
    },
    {
      'en': 'Juz marker',
      'ar': 'علامة الجزء',
      'ur': 'پارے کی علامت',
      'tr': 'Cüz işareti',
      'fr': 'Marque de juz',
      'id': 'Tanda juz',
      'de': 'Juz-Markierung',
      'es': 'Marcador de yuz',
    },
  ];

  static const _sajdahExplanation = {
    'en':
        'Sajdah sign: ۩ marks a place of recitation prostration. It is a '
        'mushaf notation marker, not a pronunciation rule.',
    'ar':
        'علامة السجدة: ۩ تدل على موضع سجود التلاوة، وهي علامة كتابية في المصحف '
        'وليست حكمًا في النطق.',
    'ur':
        'علامتِ سجدہ: ۩ سجدۂ تلاوت کے مقام کو ظاہر کرتی ہے۔ یہ مصحف کی کتابتی '
        'علامت ہے، تلفظ کا حکم نہیں۔',
    'tr':
        'Secde işareti: ۩ tilavet secdesi yerini gösterir. Bu bir mushaf yazım '
        'işaretidir, telaffuz kuralı değildir.',
    'fr':
        'Signe de sajdah : ۩ indique un lieu de prosternation de récitation. '
        'C’est une marque de notation du mushaf, non une règle de prononciation.',
    'id':
        'Tanda sajdah: ۩ menandai tempat sujud tilawah. Ini adalah tanda '
        'notasi mushaf, bukan hukum pelafalan.',
    'de':
        'Sajdah-Zeichen: ۩ markiert einen Ort der Rezitationsniederwerfung. Es '
        'ist ein Notationszeichen im Mushaf, keine Ausspracheregel.',
    'es':
        'Signo de sajdah: ۩ marca un lugar de postración de recitación. Es una '
        'marca de notación del mushaf, no una regla de pronunciación.',
  };

  static Map<String, String> _nameMap(TajweedRuleDefinition def) => {
    'en': def.names['en'] ?? '',
    'ar': def.names['ar'] ?? '',
    'ur': def.names['ur'] ?? '',
    'tr': def.names['tr'] ?? '',
    'fr': def.names['fr'] ?? '',
    'id': def.names['id'] ?? '',
    'de': def.names['de'] ?? '',
    'es': def.names['es'] ?? def.names['en'] ?? '',
  };

  static Map<String, String> _questionTemplate(int _) => const {
    'en': 'Which tajweed rule applies to the highlighted part?',
    'ar': 'ما حكم التجويد في الجزء الملوّن؟',
    'ur': 'نمایاں کیے گئے حصے پر کون سا تجویدی حکم لاگو ہوتا ہے؟',
    'tr': 'Renkle vurgulanan bölümde hangi tecvid kuralı uygulanır?',
    'fr': 'Quelle règle de tajwid s’applique à la partie surlignée ?',
    'id': 'Hukum tajwid apa yang berlaku pada bagian berwarna?',
    'de': 'Welche Tajweed-Regel gilt für die farblich markierte Stelle?',
    'es': '¿Qué regla de Tajweed se aplica a la parte resaltada?',
  };

  static ({int start, int end}) _highlightRange(
    TajweedRule rule,
    String arabic,
    int exampleIndex,
  ) {
    final fragment = RuleExampleHighlight.fragmentFor(rule, exampleIndex);
    if (fragment == null) {
      throw StateError('No quiz highlight fragments defined for ${rule.name}');
    }
    final range = RuleExampleHighlight.rangeIn(rule, arabic, exampleIndex);
    if (range == null) {
      throw StateError(
        'Quiz highlight "$fragment" was not found in "$arabic" for ${rule.name}',
      );
    }
    return range;
  }


  static Map<String, String> _explanationTemplate(
    TajweedRuleDefinition def,
    int variant,
  ) {
    final letters = def.triggerLetters.join(' ');
    final en = def.descriptions['en'] ?? '';
    final ar = def.descriptions['ar'] ?? '';
    final ur = def.descriptions['ur'] ?? '';
    final tr = def.descriptions['tr'] ?? '';
    final fr = def.descriptions['fr'] ?? '';
    final id = def.descriptions['id'] ?? '';
    final de = def.descriptions['de'] ?? '';
    final es = def.descriptions['es'];

    if (variant.isEven) {
      final explanations = {
        'en': '${def.names['en']}: $en',
        'ar': '${def.names['ar']}: $ar',
        'ur': '${def.names['ur']}: $ur',
        'tr': '${def.names['tr']}: $tr',
        'fr': '${def.names['fr']}: $fr',
        'id': '${def.names['id']}: $id',
        'de': '${def.names['de']}: $de',
      };
      if (es != null) {
        explanations['es'] = '${def.names['es'] ?? def.names['en']}: $es';
      }
      return explanations;
    }

    final explanations = {
      'en': 'Trigger letters: $letters. $en',
      'ar': 'حروف السبب: $letters. $ar',
      'ur': 'حروفِ سبب: $letters۔ $ur',
      'tr': 'Tetikleyici harfler: $letters. $tr',
      'fr': 'Lettres déclencheuses: $letters. $fr',
      'id': 'Huruf pemicu: $letters. $id',
      'de': 'Auslöser-Buchstaben: $letters. $de',
    };
    if (es != null) {
      explanations['es'] = 'Letras clave: $letters. $es';
    }
    return explanations;
  }
}
