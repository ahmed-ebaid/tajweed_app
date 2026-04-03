import 'package:flutter/foundation.dart';

class ReaderNavigationRequest {
  final int surah;
  final int ayah;

  const ReaderNavigationRequest({required this.surah, required this.ayah});
}

class ReaderNavigationProvider extends ChangeNotifier {
  ReaderNavigationRequest? _pending;

  ReaderNavigationRequest? get pending => _pending;

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
