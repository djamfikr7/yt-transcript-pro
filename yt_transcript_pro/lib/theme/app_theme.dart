import 'package:flutter/material.dart';

/// True Neumorphic Design System for YT Transcript Pro
/// Based on user-provided reference image

class AppTheme {
  // === Neumorphic Color Palette ===
  static const primary = Color(0xFF6366F1); // Indigo for primary actions
  static const accent = Color(0xFFFF6B85); // Pink/Coral accent (from reference)
  static const success = Color(0xFF10B981); // Emerald
  static const warning = Color(0xFFF59E0B); // Amber
  static const error = Color(0xFFEF4444); // Red

  // Neumorphic backgrounds - soft gray tones
  static const backgroundLight = Color(0xFFE0E5EC); // Soft light gray (key!)
  static const surfaceLight = Color(
    0xFFE0E5EC,
  ); // Same as background for unified look
  static const textDark = Color(0xFF4A5568); // Muted dark text

  // Shadow colors for neumorphic effect
  static const shadowDark = Color(0xFFA3B1C6); // Darker shadow
  static const shadowLight = Color(0xFFFFFFFF); // White highlight

  // Dark mode (keeping for system compatibility)
  static const backgroundDark = Color(0xFF2D3748);
  static const surfaceDark = Color(0xFF1A202C);
  static const textLight = Color(0xFFE2E8F0);

  // === Neumorphic Shadow System ===
  static List<BoxShadow> neuShadows({bool pressed = false, bool dark = false}) {
    if (dark) {
      // Simple dark mode shadows
      return pressed
          ? [
              BoxShadow(
                color: Colors.black26,
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black38,
                offset: const Offset(8, 8),
                blurRadius: 16,
              ),
            ];
    }

    if (pressed) {
      // Inset effect - darker shadows, closer
      return [
        BoxShadow(
          color: shadowDark,
          offset: const Offset(4, 4),
          blurRadius: 8,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: shadowLight,
          offset: const Offset(-4, -4),
          blurRadius: 8,
          spreadRadius: -2,
        ),
      ];
    }

    // Raised effect - classic neumorphism
    return [
      BoxShadow(
        color: shadowDark,
        offset: const Offset(8, 8),
        blurRadius: 16,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: shadowLight,
        offset: const Offset(-8, -8),
        blurRadius: 16,
        spreadRadius: 0,
      ),
    ];
  }

  // Flat surface (no depth) - for backgrounds
  static List<BoxShadow> flatShadows({bool dark = false}) {
    if (dark) return [];

    return [
      BoxShadow(
        color: shadowDark.withOpacity(0.3),
        offset: const Offset(4, 4),
        blurRadius: 8,
      ),
      BoxShadow(
        color: shadowLight,
        offset: const Offset(-4, -4),
        blurRadius: 8,
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
      secondary: accent,
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
        letterSpacing: -0.5,
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
      secondary: accent,
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
