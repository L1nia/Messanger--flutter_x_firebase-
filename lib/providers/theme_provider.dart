import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode;
  final SharedPreferences _prefs;

  ThemeProvider(this._prefs) : _themeMode = ThemeMode.values.byName(
          _prefs.getString('theme_mode') ?? 'system',
        );

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.window.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
} 