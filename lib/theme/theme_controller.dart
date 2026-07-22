import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeController extends ChangeNotifier {
  static const _storageKey = 'themeMode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  /// Must be called once after the Hive box is opened, before the widget tree
  /// reads [themeMode].
  void init() {
    _loadSavedTheme();
  }

  void _loadSavedTheme() {
    final saved = Hive.box('myStore').get(_storageKey) as String?;
    switch (saved) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await Hive.box('myStore').put(_storageKey, mode.name);
    notifyListeners();
  }

  Future<void> toggleLightDark() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final themeController = ThemeController();
