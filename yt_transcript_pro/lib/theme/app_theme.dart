import 'package:flutter/material.dart';

/// Neomorphic Design System for YT Transcript Pro
/// Based on PRD specifications with glassmorphism and soft shadows

class AppTheme {
  // === Color Palette (from PRD) ===
  static const primary = Color(0xFF6366F1); // Indigo
  static const success = Color(0xFF10B981); // Emerald
  static const warning = Color(0xFFF59E0B); // Amber
  static const error = Color(0xFFEF4444); // Red
  
  static const backgroundLight = Color(0xFFF5F7FA);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF1F2937);
  static const shadowLight = Color(0xFFFFFFFF);
  static const shadowDark = Color(0xFFD1D1D1);

  // Dark mode colors
  static const backgroundDark = Color(0xFF1A1A2E);
  static const surfaceDark = Color(0xFF16213E);
  static const textLight = Color(0xFFE5E7EB);

  // === Shadow Configurations ===
  static List<BoxShadow> neuShadows({
    bool pressed = false,
    bool dark = false,
  }) {
    if (pressed) {
      return [
        BoxShadow(
          color: dark ? Colors.black26 : shadowDark.withOpacity(0.3),
          offset: const Offset(2, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: dark ? Colors.white10 : shadowLight.withOpacity(0.7),
          offset: const Offset(-2, -2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: dark ? Colors.black38 : shadowDark.withOpacity(0.5),
        offset: const Offset(8, 8),
        blurRadius: 16,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: dark ? Colors.white10 : shadowLight,
        offset: const Offset(-8, -8),
        blurRadius: 16,
        spreadRadius: 0,
      ),
    ];
  }

  // === ThemeData ===
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: success,
      error: error,
      surface: surfaceLight,
      onPrimary: Colors.white,
      onSurface: textDark,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textDark),
      bodyLarge: TextStyle(fontSize: 16, color: textDark),
      bodyMedium: TextStyle(fontSize: 14, color: textDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: surfaceLight,
        foregroundColor: textDark,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primary,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: success,
      error: error,
      surface: surfaceDark,
      onPrimary: Colors.white,
      onSurface: textLight,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textLight),
      bodyLarge: TextStyle(fontSize: 16, color: textLight),
      bodyMedium: TextStyle(fontSize: 14, color: textLight),
    ),
  );
}
