import 'package:flutter/material.dart';

/// Neomorphic Design System for YT Transcript Pro
/// Lighter theme with enhanced soft shadows

class AppTheme {
  // === Color Palette - Lighter Theme ===
  static const primary = Color(0xFF6366F1); // Vibrant Indigo
  static const success = Color(0xFF10B981); // Emerald
  static const warning = Color(0xFFF59E0B); // Amber
  static const error = Color(0xFFEF4444); // Red

  // Lighter background colors
  static const backgroundLight = Color(0xFFFFFFFF); // Pure white
  static const surfaceLight = Color(0xFFF8F9FA); // Very light gray
  static const textDark = Color(0xFF2D3748); // Softer dark
  static const shadowLight = Color(0xFFFFFFFF);
  static const shadowDark = Color(0xFFE2E8F0); // Lighter shadow
  static const accent = Color(0xFF8B5CF6); // Purple accent

  // Dark mode colors (for system dark mode)
  static const backgroundDark = Color(0xFF1A1A2E);
  static const surfaceDark = Color(0xFF16213E);
  static const textLight = Color(0xFFE5E7EB);

  // === Enhanced Shadow Configurations for Lighter Theme ===
  static List<BoxShadow> neuShadows({bool pressed = false, bool dark = false}) {
    if (pressed) {
      // Inset shadow effect for pressed state
      return [
        BoxShadow(
          color: dark
              ? Colors.black26
              : const Color(0xFFD1D9E6).withOpacity(0.6),
          offset: const Offset(3, 3),
          blurRadius: 6,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: dark ? Colors.white10 : Colors.white.withOpacity(0.9),
          offset: const Offset(-3, -3),
          blurRadius: 6,
          spreadRadius: -2,
        ),
      ];
    }
    // Enhanced raised effect for lighter theme
    return [
      BoxShadow(
        color: dark ? Colors.black38 : const Color(0xFFD1D9E6).withOpacity(0.8),
        offset: const Offset(10, 10),
        blurRadius: 20,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: dark ? Colors.white10 : Colors.white,
        offset: const Offset(-10, -10),
        blurRadius: 20,
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
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textDark,
      ),
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
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textLight,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: textLight),
      bodyMedium: TextStyle(fontSize: 14, color: textLight),
    ),
  );
}
