import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _darkModeKey = 'lifecheckpoint_dark_mode_v1';
  static const String _filipinoKey = 'lifecheckpoint_filipino_lang_v1';

  bool _isDarkMode = false;
  bool _isFilipino = false;

  SettingsProvider() {
    _loadSettings();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isFilipino => _isFilipino;

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
      _isFilipino = prefs.getBool(_filipinoKey) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, _isDarkMode);
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    _isFilipino = !_isFilipino;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_filipinoKey, _isFilipino);
    } catch (_) {}
  }
}
