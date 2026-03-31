import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class RecitationProvider extends ChangeNotifier {
  static const _boxKey = 'settings';
  static const _reciterIdKey = 'reciter_id';

  late int _selectedReciterId;

  RecitationProvider() {
    final box = Hive.box(_boxKey);
    _selectedReciterId = box.get(_reciterIdKey, defaultValue: 1) as int;
  }

  int get selectedReciterId => _selectedReciterId;

  Future<void> setReciter(int id) async {
    _selectedReciterId = id;
    final box = Hive.box(_boxKey);
    await box.put(_reciterIdKey, id);
    notifyListeners();
  }
}
