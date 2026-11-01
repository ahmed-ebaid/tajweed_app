import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/widgets.dart';

import '../models/tajweed_models.dart';
import '../data/surah_names.dart';
import '../../features/rules/rules_repository.dart';

class DailyLesson {
  final int surah;
  final int ayah;
  final Map<String, String> titles;
  final TajweedRule rule;
  final Set<int> wordIndices;

  const DailyLesson({
    required this.surah,
    required this.ayah,
    required this.titles,
    required this.rule,
    required this.wordIndices,
  });

  static const List<DailyLesson> _plan = [
    DailyLesson(
      surah: 67,
      ayah: 12,
      rule: TajweedRule.ghunnah,
      wordIndices: {0},
      titles: {'en': 'Ghunnah in Surah Al-Mulk', 'ar': 'غُنَّة في سورة الملك'},
    ),
    DailyLesson(
      surah: 105,
      ayah: 4,
      rule: TajweedRule.ikhfaShafawi,
      wordIndices: {0, 1},
      titles: {
        'en': 'Ikhfa Shafawi in Surah Al-Fil',
        'ar': 'إخفاء شفوي في سورة الفيل',
      },
    ),
    DailyLesson(
      surah: 36,
      ayah: 58,
      rule: TajweedRule.maddTabeei,
      wordIndices: {0},
      titles: {
        'en': 'Madd Practice in Surah Ya-Sin',
        'ar': 'تدريب المد في سورة يس',
      },
    ),
    DailyLesson(
      surah: 19,
      ayah: 61,
      rule: TajweedRule.qalqalah,
      wordIndices: {1},
      titles: {'en': 'Qalqalah in Surah Maryam', 'ar': 'قلقلة في سورة مريم'},
    ),
    DailyLesson(
      surah: 2,
      ayah: 21,
      rule: TajweedRule.ikhfa,
      wordIndices: {7, 8},
      titles: {'en': 'Ikhfa in Surah Al-Baqarah', 'ar': 'إخفاء في سورة البقرة'},
    ),
    DailyLesson(
      surah: 15,
      ayah: 87,
      rule: TajweedRule.idghamWithGhunnah,
      wordIndices: {2, 3},
      titles: {'en': 'Idgham in Surah Al-Hijr', 'ar': 'إدغام في سورة الحجر'},
    ),
    DailyLesson(
      surah: 37,
      ayah: 9,
      rule: TajweedRule.waqf,
      wordIndices: {0},
      titles: {
        'en': 'Waqf Signs in Surah As-Saffat',
        'ar': 'علامات الوقف في سورة الصافات',
      },
    ),
  ];

  static DailyLesson forDate(DateTime date) {
    final startOfYear = DateTime.utc(date.year, 1, 1);
    final dayOfYear = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(startOfYear).inDays;
    return _plan[dayOfYear % _plan.length];
  }

  String titleFor(String langCode) =>
      titles[langCode] ??
      '${RulesRepository.findByRule(rule)?.name(langCode) ?? rule.arabicName} · ${surahName(surah, langCode)}';

  bool matches(Ayah value) {
    if (value.surahNumber != surah || value.ayahNumber != ayah) return false;
    if (wordIndices.isEmpty ||
        wordIndices.any((index) => index < 0 || index >= value.words.length)) {
      debugPrint('Daily lesson example unavailable for $surah:$ayah');
      return false;
    }
    return true;
  }
}

class DailyLessonProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _dateKey = 'daily_lesson_progress_date';
  static const _surahKey = 'daily_lesson_progress_surah';
  static const _targetAyahKey = 'daily_lesson_progress_target_ayah';
  static const _maxReachedAyahKey = 'daily_lesson_progress_max_reached_ayah';
  static const _completedKey = 'daily_lesson_progress_completed';

  String _storedDateKey = '';
  int _storedSurah = -1;
  int _storedTargetAyah = -1;
  int _maxReachedAyah = 0;
  bool _completed = false;

  DailyLessonProvider() {
    _load();
  }

  DailyLesson get todayLesson => DailyLesson.forDate(DateTime.now());

  double get progressForToday {
    _ensureTodayState();
    if (_completed) return 1.0;
    if (_maxReachedAyah > 0) return 0.5;
    return 0.0;
  }

  bool get completedToday {
    _ensureTodayState();
    return _completed;
  }

  Future<bool> markReaderProgress({
    required int surah,
    required int ayah,
  }) async {
    final lesson = todayLesson;
    final changedByDate = _ensureTodayState();

    if (surah != lesson.surah) {
      if (changedByDate) {
        notifyListeners();
      }
      return false;
    }

    final normalizedAyah = ayah < 0 ? 0 : ayah;
    var changed = changedByDate;
    var completedNow = false;

    if (normalizedAyah > _maxReachedAyah) {
      _maxReachedAyah = normalizedAyah;
      changed = true;
    }

    if (!_completed && _maxReachedAyah >= lesson.ayah) {
      _completed = true;
      completedNow = true;
      changed = true;
    }

    if (!changed) return false;

    await _persist();
    notifyListeners();
    return completedNow;
  }

  void _load() {
    final box = Hive.box(_boxKey);
    _storedDateKey = box.get(_dateKey, defaultValue: '') as String;
    _storedSurah = box.get(_surahKey, defaultValue: -1) as int;
    _storedTargetAyah = box.get(_targetAyahKey, defaultValue: -1) as int;
    _maxReachedAyah = box.get(_maxReachedAyahKey, defaultValue: 0) as int;
    _completed = box.get(_completedKey, defaultValue: false) as bool;
    _ensureTodayState();
  }

  bool _ensureTodayState() {
    final lesson = todayLesson;
    final todayKey = _dateKeyFor(DateTime.now());
    final needsReset =
        _storedDateKey != todayKey ||
        _storedSurah != lesson.surah ||
        _storedTargetAyah != lesson.ayah;

    if (!needsReset) return false;

    _storedDateKey = todayKey;
    _storedSurah = lesson.surah;
    _storedTargetAyah = lesson.ayah;
    _maxReachedAyah = 0;
    _completed = false;
    _persistUnawaited();
    return true;
  }

  Future<void> _persist() async {
    final box = Hive.box(_boxKey);
    await box.put(_dateKey, _storedDateKey);
    await box.put(_surahKey, _storedSurah);
    await box.put(_targetAyahKey, _storedTargetAyah);
    await box.put(_maxReachedAyahKey, _maxReachedAyah);
    await box.put(_completedKey, _completed);
  }

  void _persistUnawaited() {
    final box = Hive.box(_boxKey);
    box.put(_dateKey, _storedDateKey);
    box.put(_surahKey, _storedSurah);
    box.put(_targetAyahKey, _storedTargetAyah);
    box.put(_maxReachedAyahKey, _maxReachedAyah);
    box.put(_completedKey, _completed);
  }

  static String _dateKeyFor(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
