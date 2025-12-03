import 'package:flutter/material.dart';

/// Modern Neumorphic Design System
/// Based on clean mobile app reference (light/dark modes)

class AppTheme {
  // === Light Mode Colors ===
  static const lightBackground = Color(0xFFEEF1F4); // Light blue-gray
  static const lightSurface = Color(0xFFFFFFFF); // Pure white cards
  static const lightText = Color(0xFF2C2F3E); // Dark text
  static const lightTextSecondary = Color(0xFF8E93A6); // Gray text

  // === Dark Mode Colors ===
  static const darkBackground = Color(0xFF2C2F3E); // Dark charcoal
  static const darkSurface = Color(0xFF353849); // Slightly lighter panels
  static const darkText = Color(0xFFFFFFFF); // White text
  static const darkTextSecondary = Color(0xFF8E93A6); // Gray text (same)

  // === Accent Colors (Same for both modes) ===
  static const green = Color(0xFF4ADE80); // Primary green
  static const orange = Color(0xFFFF9500); // Orange accent
  static const red = Color(0xFFFF3B30); // Red for negative values
  static const iconGray = Color(0xFF8E93A6); // Icon tint

  // === Shadow System ===
  static List<BoxShadow> lightShadows({bool pressed = false}) {
    if (pressed) {
      return [
        BoxShadow(
          color: const Color(0xFFD1D9E0),
          offset: const Offset(2, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.white,
          offset: const Offset(-2, -2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFFD1D9E0).withOpacity(0.6),
        offset: const Offset(6, 6),
        blurRadius: 12,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.white,
        offset: const Offset(-6, -6),
        blurRadius: 12,
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> darkShadows({bool pressed = false}) {
    if (pressed) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          offset: const Offset(2, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        offset: const Offset(4, 4),
        blurRadius: 8,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: const Color(0xFF3D4050).withOpacity(0.5),
        offset: const Offset(-2, -2),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ];
  }

  // === ThemeData ===
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: green,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: green,
      secondary: orange,
      error: red,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSurface: lightText,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: lightText,
      ),
      displayMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: lightText,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: lightText),
      bodyMedium: TextStyle(fontSize: 14, color: lightTextSecondary),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: lightText,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: green,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: green,
      secondary: orange,
      error: red,
      surface: darkSurface,
      onPrimary: Colors.white,
      onSurface: darkText,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: darkText,
      ),
      displayMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: darkText),
      bodyMedium: TextStyle(fontSize: 14, color: darkTextSecondary),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
    ),
  );

  // Helper to get shadows based on theme
  static List<BoxShadow> getShadows(
    BuildContext context, {
    bool pressed = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? darkShadows(pressed: pressed)
        : lightShadows(pressed: pressed);
  }

  // Helper to get surface color
  static Color getSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkSurface : lightSurface;
  }

  // Helper to get background color
  static Color getBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBackground : lightBackground;
  }
}
