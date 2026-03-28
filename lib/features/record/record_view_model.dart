import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/providers/recitation_provider.dart';
import '../../core/services/tarteel_service.dart';

/// ViewModel for the Record screen — manages microphone permissions,
/// audio recording lifecycle, and Tarteel AI evaluation.
class RecordViewModel extends ChangeNotifier {
  final RecitationProvider _recitationProvider;
  final TarteelService _tarteel = TarteelService();
  final AudioRecorder _recorder = AudioRecorder();

  int _selectedSurah = 67;
  int _selectedAyah = 1;
  String? _recordingPath;

  RecordViewModel(this._recitationProvider);

  // ── Public getters ────────────────────────────────────────────────────────

  int get selectedSurah => _selectedSurah;
  int get selectedAyah => _selectedAyah;

  // ── Actions ───────────────────────────────────────────────────────────────

  void selectAyah(int surah, int ayah) {
    _selectedSurah = surah;
    _selectedAyah = ayah;
    notifyListeners();
  }

  /// Request microphone permission and start recording.
  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _recitationProvider.setError('Microphone permission is required');
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${dir.path}/recitation_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );
      _recitationProvider.startRecording();
    } catch (e) {
      _recitationProvider.setError('Failed to start recording: $e');
    }
  }

  /// Stop recording and send to Tarteel AI for evaluation.
  Future<void> stopAndEvaluate() async {
    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        _recitationProvider.setError('Recording failed — no audio captured');
        return;
      }

      _recordingPath = path;
      _recitationProvider.stopRecording(path);

      // Send to Tarteel AI
      final feedback = await _tarteel.evaluateRecitation(
        audioPath: path,
        surahNumber: _selectedSurah,
        ayahNumber: _selectedAyah,
      );

      _recitationProvider.setFeedback(feedback);
    } on TarteelException catch (e) {
      _recitationProvider.setError(e.message);
    } catch (e) {
      _recitationProvider.setError('Evaluation failed: $e');
    }
  }

  /// Cancel a recording without evaluation.
  Future<void> cancelRecording() async {
    await _recorder.stop();
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (file.existsSync()) file.deleteSync();
    }
    _recitationProvider.reset();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
