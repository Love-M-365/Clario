import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme_data.dart';

class ThemeProvider with ChangeNotifier {
  AppThemeType _currentTheme = AppThemeType.calm;
  
  AppThemeType get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  void setTheme(AppThemeType theme) async {
    _currentTheme = theme;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme.toString());
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme');
    
    if (themeString != null) {
      _currentTheme = AppThemeType.values.firstWhere(
        (theme) => theme.toString() == themeString,
        orElse: () => AppThemeType.calm,
      );
      notifyListeners();
    }
  }

  String getThemeName(AppThemeType theme) {
    switch (theme) {
      case AppThemeType.calm:
        return 'Calm Blue';
      case AppThemeType.energetic:
        return 'Energetic Orange';
      case AppThemeType.peaceful:
        return 'Peaceful Teal';
      case AppThemeType.focused:
        return 'Focused Purple';
      case AppThemeType.creative:
        return 'Creative Pink';
    }
  }

  String getThemeDescription(AppThemeType theme) {
    switch (theme) {
      case AppThemeType.calm:
        return 'Promotes relaxation and reduces anxiety';
      case AppThemeType.energetic:
        return 'Boosts motivation and positive energy';
      case AppThemeType.peaceful:
        return 'Encourages tranquility and balance';
      case AppThemeType.focused:
        return 'Enhances concentration and clarity';
      case AppThemeType.creative:
        return 'Stimulates imagination and creativity';
    }
  }
}