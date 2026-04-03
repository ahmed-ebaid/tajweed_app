import 'dart:math';

import '../../core/models/tajweed_models.dart';
import '../rules/rules_repository.dart';

enum QuizLevel {
  beginner,
  intermediate,
  advanced,
}

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
        TajweedRule.maddLazim,
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
        : all.where((question) => questionLevel(question.rule) == level).toList();
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

    return QuizQuestion(
      rule: target.rule,
      arabicText: arabic,
      questionText: _questionTemplate(variant),
      options: options,
      correctIndex: correctIndex,
      explanation: _explanationTemplate(target, variant),
    );
  }

  static Map<String, String> _nameMap(TajweedRuleDefinition def) => {
        'en': def.names['en'] ?? '',
        'ar': def.names['ar'] ?? '',
        'ur': def.names['ur'] ?? '',
        'tr': def.names['tr'] ?? '',
        'fr': def.names['fr'] ?? '',
        'id': def.names['id'] ?? '',
        'de': def.names['de'] ?? '',
      };

  static Map<String, String> _questionTemplate(int variant) {
    switch (variant % 5) {
      case 0:
        return {
          'en': 'Which tajweed rule is shown in this phrase?',
          'ar': 'ما قاعدة التجويد الظاهرة في هذا المثال؟',
          'ur': 'اس مثال میں کون سا تجویدی قاعدہ ہے؟',
          'tr': 'Bu ifadede hangi tecvid kuralı var?',
          'fr': 'Quelle règle de tajweed apparaît dans cette expression?',
          'id': 'Kaidah tajwid apa yang muncul pada contoh ini?',
          'de': 'Welche Tajweed-Regel erscheint in diesem Beispiel?',
        };
      case 1:
        return {
          'en': 'Identify the correct rule for this recitation pattern.',
          'ar': 'حدّد الحكم الصحيح لهذا النمط من التلاوة.',
          'ur': 'اس تلاوتی نمونے کے لیے درست حکم منتخب کریں۔',
          'tr': 'Bu okuma örüntüsü için doğru kuralı seçin.',
          'fr': 'Identifiez la règle correcte pour ce motif de récitation.',
          'id': 'Tentukan kaidah yang benar untuk pola bacaan ini.',
          'de': 'Bestimme die richtige Regel für dieses Rezitationsmuster.',
        };
      case 2:
        return {
          'en': 'What is the ruling applied in this ayah segment?',
          'ar': 'ما الحكم المطبق في هذا المقطع من الآية؟',
          'ur': 'آیت کے اس حصے میں کون سا حکم لاگو ہوتا ہے؟',
          'tr': 'Bu ayet bölümünde hangi kural uygulanır?',
          'fr': 'Quelle règle est appliquée dans ce segment du verset?',
          'id': 'Hukum apa yang diterapkan pada potongan ayat ini?',
          'de': 'Welche Regel wird in diesem Aya-Abschnitt angewandt?',
        };
      case 3:
        return {
          'en': 'Choose the tajweed rule that best matches this text.',
          'ar': 'اختر قاعدة التجويد الأنسب لهذا النص.',
          'ur': 'اس متن کے مطابق درست تجویدی قاعدہ منتخب کریں۔',
          'tr': 'Bu metne en uygun tecvid kuralını seçin.',
          'fr': 'Choisissez la règle de tajweed qui correspond à ce texte.',
          'id': 'Pilih kaidah tajwid yang paling sesuai untuk teks ini.',
          'de': 'Wähle die Tajweed-Regel, die am besten zu diesem Text passt.',
        };
      default:
        return {
          'en': 'Which rule should be observed while reading this?',
          'ar': 'أي حكم يجب مراعاته عند قراءة هذا المثال؟',
          'ur': 'اسے پڑھتے وقت کون سا حکم ملحوظ رکھا جائے؟',
          'tr': 'Bunu okurken hangi kurala dikkat edilmelidir?',
          'fr': 'Quelle règle faut-il observer en lisant ceci ?',
          'id': 'Aturan apa yang harus diperhatikan saat membacanya?',
          'de': 'Welche Regel sollte beim Lesen hiervon beachtet werden?',
        };
    }
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

    if (variant.isEven) {
      return {
        'en': '${def.names['en']}: $en',
        'ar': '${def.names['ar']}: $ar',
        'ur': '${def.names['ur']}: $ur',
        'tr': '${def.names['tr']}: $tr',
        'fr': '${def.names['fr']}: $fr',
        'id': '${def.names['id']}: $id',
        'de': '${def.names['de']}: $de',
      };
    }

    return {
      'en': 'Trigger letters: $letters. $en',
      'ar': 'حروف السبب: $letters. $ar',
      'ur': 'حروفِ سبب: $letters۔ $ur',
      'tr': 'Tetikleyici harfler: $letters. $tr',
      'fr': 'Lettres déclencheuses: $letters. $fr',
      'id': 'Huruf pemicu: $letters. $id',
      'de': 'Auslöser-Buchstaben: $letters. $de',
    };
  }
}
