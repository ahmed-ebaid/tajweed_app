import 'package:flutter/material.dart';

import '../../core/models/tajweed_models.dart';

/// ViewModel for the Quiz screen — manages question pool, scoring,
/// navigation between questions, and quiz completion state.
class QuizViewModel extends ChangeNotifier {
  final List<QuizQuestion> _questions;
  int _currentIndex = 0;
  int? _selectedOption;
  int _score = 0;
  bool _quizComplete = false;

  QuizViewModel({required List<QuizQuestion> questions})
      : _questions = List.of(questions);

  // ── Public getters ────────────────────────────────────────────────────────

  int get currentIndex => _currentIndex;
  int get totalQuestions => _questions.length;
  QuizQuestion get currentQuestion => _questions[_currentIndex];
  int? get selectedOption => _selectedOption;
  int get score => _score;
  bool get quizComplete => _quizComplete;
  bool get answered => _selectedOption != null;

  bool get isCorrect =>
      _selectedOption == _questions[_currentIndex].correctIndex;

  double get progressFraction => (_currentIndex + 1) / _questions.length;

  double get scorePercentage =>
      _questions.isEmpty ? 0 : (_score / _questions.length) * 100;

  bool get hasNext => _currentIndex < _questions.length - 1;

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Select an answer. No-op if already answered.
  void selectOption(int index) {
    if (answered) return;
    _selectedOption = index;
    if (index == _questions[_currentIndex].correctIndex) {
      _score++;
    }
    notifyListeners();
  }

  /// Advance to next question, or mark quiz complete.
  void nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      _currentIndex++;
      _selectedOption = null;
      notifyListeners();
    } else {
      _quizComplete = true;
      notifyListeners();
    }
  }

  /// Restart the quiz from the beginning.
  void restart() {
    _currentIndex = 0;
    _selectedOption = null;
    _score = 0;
    _quizComplete = false;
    notifyListeners();
  }
}
