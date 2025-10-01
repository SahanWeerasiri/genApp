import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      AppLogger.info('Theme loaded: ${_themeMode.name}');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading theme: $e');
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    try {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDark);
      AppLogger.info('Theme changed to: ${_themeMode.name}');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error saving theme: $e');
    }
  }
}
