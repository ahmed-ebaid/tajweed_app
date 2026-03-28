import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/tajweed_models.dart';

enum RecordingState { idle, recording, processing, done, error }

class RecitationProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _reciterIdKey = 'reciter_id';

  RecordingState _state = RecordingState.idle;
  RecitationFeedback? _lastFeedback;
  String? _currentAudioPath;
  String? _errorMessage;
  late int _selectedReciterId;

  RecitationProvider() {
    final box = Hive.box(_boxKey);
    _selectedReciterId = box.get(_reciterIdKey, defaultValue: 1) as int;
  }

  RecordingState get state => _state;
  RecitationFeedback? get lastFeedback => _lastFeedback;
  String? get currentAudioPath => _currentAudioPath;
  String? get errorMessage => _errorMessage;
  int get selectedReciterId => _selectedReciterId;

  bool get isRecording => _state == RecordingState.recording;
  bool get isProcessing => _state == RecordingState.processing;
  bool get hasFeedback => _lastFeedback != null;

  Future<void> setReciter(int id) async {
    _selectedReciterId = id;
    final box = Hive.box(_boxKey);
    await box.put(_reciterIdKey, id);
    notifyListeners();
  }

  void startRecording() {
    _state = RecordingState.recording;
    _errorMessage = null;
    notifyListeners();
  }

  void stopRecording(String audioPath) {
    _currentAudioPath = audioPath;
    _state = RecordingState.processing;
    notifyListeners();
  }

  void setFeedback(RecitationFeedback feedback) {
    _lastFeedback = feedback;
    _state = RecordingState.done;
    notifyListeners();
  }

  void setError(String message) {
    _errorMessage = message;
    _state = RecordingState.error;
    notifyListeners();
  }

  void reset() {
    _state = RecordingState.idle;
    _currentAudioPath = null;
    _errorMessage = null;
    notifyListeners();
  }
}
