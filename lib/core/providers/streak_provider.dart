import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class StreakProvider extends ChangeNotifier {
  static const _boxKey = 'streak';
  static const _streakKey = 'streak_count';
  static const _lastActivityKey = 'last_activity';
  static const _completedDaysKey = 'completed_days';

  int _streakCount = 0;
  DateTime? _lastActivity;
  List<bool> _weekDots = List.filled(7, false); // Mon–Sun

  int get streakCount => _streakCount;
  DateTime? get lastActivity => _lastActivity;
  List<bool> get weekDots => _weekDots;

  StreakProvider() {
    _load();
  }

  void _load() {
    final box = Hive.box(_boxKey);
    _streakCount = box.get(_streakKey, defaultValue: 0) as int;
    final lastMs = box.get(_lastActivityKey) as int?;
    _lastActivity = lastMs != null ? DateTime.fromMillisecondsSinceEpoch(lastMs) : null;
    _weekDots = _buildWeekDots();
    _checkStreakReset();
  }

  /// Call this whenever the user completes any activity (lesson, quiz, recording).
  Future<void> recordActivity() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastActivity != null) {
      final last = DateTime(_lastActivity!.year, _lastActivity!.month, _lastActivity!.day);
      final diff = today.difference(last).inDays;
      if (diff == 0) return; // Already recorded today
      if (diff == 1) {
        _streakCount++; // Consecutive day
      } else {
        _streakCount = 1; // Streak broken, restart
      }
    } else {
      _streakCount = 1;
    }

    _lastActivity = now;
    _weekDots = _buildWeekDots();

    final box = Hive.box(_boxKey);
    await box.put(_streakKey, _streakCount);
    await box.put(_lastActivityKey, now.millisecondsSinceEpoch);
    await _saveCompletedDay(today);
    notifyListeners();
  }

  void _checkStreakReset() {
    if (_lastActivity == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(_lastActivity!.year, _lastActivity!.month, _lastActivity!.day);
    if (today.difference(last).inDays > 1) {
      _streakCount = 0;
      notifyListeners();
    }
  }

  List<bool> _buildWeekDots() {
    final now = DateTime.now();
    // Build Mon–Sun for the current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final box = Hive.box(_boxKey);
    final completed = (box.get(_completedDaysKey, defaultValue: <int>[]) as List)
        .cast<int>()
        .map((ms) {
          final d = DateTime.fromMillisecondsSinceEpoch(ms);
          return DateTime(d.year, d.month, d.day);
        })
        .toSet();

    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      return completed.contains(DateTime(day.year, day.month, day.day));
    });
  }

  Future<void> _saveCompletedDay(DateTime day) async {
    final box = Hive.box(_boxKey);
    final existing = (box.get(_completedDaysKey, defaultValue: <int>[]) as List).cast<int>();
    final dayMs = day.millisecondsSinceEpoch;
    if (!existing.contains(dayMs)) {
      existing.add(dayMs);
      await box.put(_completedDaysKey, existing);
    }
  }
}
