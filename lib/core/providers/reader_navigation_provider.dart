import 'package:flutter/foundation.dart';
import 'daily_lesson_provider.dart';

class ReaderNavigationRequest {
  final int surah;
  final int ayah;
  final DailyLesson? lesson;

  const ReaderNavigationRequest({
    required this.surah,
    required this.ayah,
    this.lesson,
  });
}

class ReaderNavigationProvider extends ChangeNotifier {
  ReaderNavigationRequest? _pending;

  ReaderNavigationRequest? get pending => _pending;

  void openLesson(DailyLesson lesson) {
    _pending = ReaderNavigationRequest(
      surah: lesson.surah,
      ayah: lesson.ayah,
      lesson: lesson,
    );
    notifyListeners();
  }

  void openSurahAyah({required int surah, required int ayah}) {
    _pending = ReaderNavigationRequest(surah: surah, ayah: ayah);
    notifyListeners();
  }

  ReaderNavigationRequest? consumePending() {
    final request = _pending;
    _pending = null;
    return request;
  }
}
