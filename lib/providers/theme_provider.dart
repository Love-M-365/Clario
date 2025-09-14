import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enum/app_theme_type.dart'; // New import for the enum
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

  // New method to get the LinearGradient for a given theme
  LinearGradient getGradient(AppThemeType theme) {
    switch (theme) {
      case AppThemeType.calm:
        return const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AppThemeType.energetic:
        return const LinearGradient(
          colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AppThemeType.peaceful:
        return const LinearGradient(
          colors: [Color(0xFF4DB6AC), Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AppThemeType.focused:
        return const LinearGradient(
          colors: [Color(0xFFBA68C8), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case AppThemeType.creative:
        return const LinearGradient(
          colors: [Color(0xFFF06292), Color(0xFFE91E63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  // Corrected availableThemes getter to return a List of Maps
  List<Map<String, dynamic>> get availableThemes {
    return [
      {
        'title': getThemeName(AppThemeType.calm),
        'type': AppThemeType.calm,
        'gradient': getGradient(AppThemeType.calm),
      },
      {
        'title': getThemeName(AppThemeType.energetic),
        'type': AppThemeType.energetic,
        'gradient': getGradient(AppThemeType.energetic),
      },
      {
        'title': getThemeName(AppThemeType.peaceful),
        'type': AppThemeType.peaceful,
        'gradient': getGradient(AppThemeType.peaceful),
      },
      {
        'title': getThemeName(AppThemeType.focused),
        'type': AppThemeType.focused,
        'gradient': getGradient(AppThemeType.focused),
      },
      {
        'title': getThemeName(AppThemeType.creative),
        'type': AppThemeType.creative,
        'gradient': getGradient(AppThemeType.creative),
      },
    ];
  }
}
