import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../enum/app_theme_type.dart';

class AppTheme {
  static ThemeData getTheme(AppThemeType themeType) {
    final colorScheme = _getColorScheme(themeType);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  static ColorScheme _getColorScheme(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.calm:
        return const ColorScheme.light(
          primary: Color(0xFF6B73FF),
          secondary: Color(0xFF9C27B0),
          surface: Color(0xFFF5F7FA),
          background: Color(0xFFFFFFFF),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF2D3748),
          onBackground: Color(0xFF2D3748),
        );
      case AppThemeType.energetic:
        return const ColorScheme.light(
          primary: Color(0xFFFF6B6B),
          secondary: Color(0xFFFF9F43),
          surface: Color(0xFFFFF5F5),
          background: Color(0xFFFFFFFF),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF2D3748),
          onBackground: Color(0xFF2D3748),
        );
      case AppThemeType.peaceful:
        return const ColorScheme.light(
          primary: Color(0xFF4ECDC4),
          secondary: Color(0xFF45B7D1),
          surface: Color(0xFFF0FDFC),
          background: Color(0xFFFFFFFF),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF2D3748),
          onBackground: Color(0xFF2D3748),
        );
      case AppThemeType.focused:
        return const ColorScheme.light(
          primary: Color(0xFF667EEA),
          secondary: Color(0xFF764BA2),
          surface: Color(0xFFF7F9FC),
          background: Color(0xFFFFFFFF),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF2D3748),
          onBackground: Color(0xFF2D3748),
        );
      case AppThemeType.creative:
        return const ColorScheme.light(
          primary: Color(0xFFE056FD),
          secondary: Color(0xFFF093FB),
          surface: Color(0xFFFDF4FF),
          background: Color(0xFFFFFFFF),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF2D3748),
          onBackground: Color(0xFF2D3748),
        );
    }
  }

  static List<Color> getGradientColors(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.calm:
        return [const Color(0xFF6B73FF), const Color(0xFF9C27B0)];
      case AppThemeType.energetic:
        return [const Color(0xFFFF6B6B), const Color(0xFFFF9F43)];
      case AppThemeType.peaceful:
        return [const Color(0xFF4ECDC4), const Color(0xFF45B7D1)];
      case AppThemeType.focused:
        return [const Color(0xFF667EEA), const Color(0xFF764BA2)];
      case AppThemeType.creative:
        return [const Color(0xFFE056FD), const Color(0xFFF093FB)];
    }
  }
}
