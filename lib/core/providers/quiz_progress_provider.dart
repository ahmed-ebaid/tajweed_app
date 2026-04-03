import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/quiz/quiz_repository.dart';

class QuizProgressProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _highestUnlockedLevelKey = 'quiz_highest_unlocked_level';
  static const _bestPercentagesKey = 'quiz_best_percentages';

  int _highestUnlockedIndex = 0;
  Map<int, int> _bestPercentages = const {};

  QuizProgressProvider() {
    _load();
  }

  QuizLevel get highestUnlockedLevel => QuizLevel.values[_highestUnlockedIndex];

  bool isUnlocked(QuizLevel level) => level.index <= _highestUnlockedIndex;

  int bestPercentageFor(QuizLevel level) => _bestPercentages[level.index] ?? 0;

  QuizLevel get recommendedLevel {
    for (final level in QuizLevel.values) {
      if (isUnlocked(level) && bestPercentageFor(level) < QuizRepository.passPercentage) {
        return level;
      }
    }
    return highestUnlockedLevel;
  }

  Future<bool> recordLevelResult({
    required QuizLevel level,
    required int percentage,
  }) async {
    final nextLevel = QuizRepository.nextLevelAfter(level);
    var changed = false;
    var unlockedNext = false;

    final currentBest = _bestPercentages[level.index] ?? 0;
    if (percentage > currentBest) {
      _bestPercentages = Map<int, int>.from(_bestPercentages)
        ..[level.index] = percentage;
      changed = true;
    }

    if (percentage >= QuizRepository.passPercentage &&
        nextLevel != null &&
        nextLevel.index > _highestUnlockedIndex) {
      _highestUnlockedIndex = nextLevel.index;
      changed = true;
      unlockedNext = true;
    }

    if (!changed) return unlockedNext;

    await _persist();
    notifyListeners();
    return unlockedNext;
  }

  void _load() {
    final box = Hive.box(_boxKey);
    _highestUnlockedIndex = box.get(_highestUnlockedLevelKey, defaultValue: 0) as int;
    final rawMap = box.get(_bestPercentagesKey, defaultValue: <String, int>{});
    if (rawMap is Map) {
      _bestPercentages = rawMap.map(
        (key, value) => MapEntry(
          int.tryParse(key.toString()) ?? 0,
          (value as num).toInt(),
        ),
      );
    } else {
      _bestPercentages = const {};
    }
    final maxIndex = QuizLevel.values.length - 1;
    _highestUnlockedIndex = _highestUnlockedIndex.clamp(0, maxIndex);
  }

  Future<void> _persist() async {
    final box = Hive.box(_boxKey);
    await box.put(_highestUnlockedLevelKey, _highestUnlockedIndex);
    await box.put(
      _bestPercentagesKey,
      _bestPercentages.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}