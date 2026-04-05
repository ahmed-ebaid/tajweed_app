import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class RecitationProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _reciterIdKey = 'reciter_id';
  static const _defaultReciterId = 1;
  static const Set<int> supportedReciterIds = {
    1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12,
  };

  late int _selectedReciterId;

  RecitationProvider() {
    final box = Hive.box(_boxKey);
    final savedId = box.get(_reciterIdKey, defaultValue: _defaultReciterId) as int;
    _selectedReciterId = supportedReciterIds.contains(savedId)
        ? savedId
        : _defaultReciterId;
    if (_selectedReciterId != savedId) {
      box.put(_reciterIdKey, _selectedReciterId);
    }
  }

  int get selectedReciterId => _selectedReciterId;

  Future<void> setReciter(int id) async {
    if (!supportedReciterIds.contains(id)) {
      id = _defaultReciterId;
    }
    _selectedReciterId = id;
    final box = Hive.box(_boxKey);
    await box.put(_reciterIdKey, id);
    notifyListeners();
  }
}
