import 'package:flutter/material.dart';

/// Modern Neumorphic Design System
class AppTheme {
  // === Light Mode Colors ===
  static const lightBg = Color(0xFFEEF1F4);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF2C2F3E);

  // === Dark Mode Colors ===
  static const darkBg = Color(0xFF2C2F3E);
  static const darkCard = Color(0xFF353849);
  static const darkText = Color(0xFFFFFFFF);

  // === Accent Colors ===
  static const green = Color(0xFF4ADE80);
  static const orange = Color(0xFFFF9500);
  static const red = Color(0xFFFF3B30);
  static const iconGray = Color(0xFF8E93A6);
  static const textGray = Color(0xFF6B7280);

  // === Shadows ===
  static List<BoxShadow> lightShadows({bool pressed = false}) {
    if (pressed) {
      return [
        BoxShadow(
          color: const Color(0xFFD1D9E0),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
        BoxShadow(
          color: Colors.white,
          offset: const Offset(-2, -2),
          blurRadius: 4,
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFFD1D9E0).withOpacity(0.6),
        offset: const Offset(6, 6),
        blurRadius: 12,
      ),
      BoxShadow(
        color: Colors.white,
        offset: const Offset(-6, -6),
        blurRadius: 12,
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
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        offset: const Offset(4, 4),
        blurRadius: 8,
      ),
      BoxShadow(
        color: const Color(0xFF3D4050).withOpacity(0.5),
        offset: const Offset(-2, -2),
        blurRadius: 8,
      ),
    ];
  }

  // === ThemeData ===
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: green,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: green,
      secondary: orange,
      error: red,
      surface: lightCard,
      onPrimary: Colors.white,
      onSurface: lightText,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: lightText),
      bodyMedium: TextStyle(color: textGray),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: green,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: green,
      secondary: orange,
      error: red,
      surface: darkCard,
      onPrimary: Colors.white,
      onSurface: darkText,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkText),
      bodyMedium: TextStyle(color: iconGray),
    ),
  );

  // === Helper Methods ===
  static Color getBackground(BuildContext context) {
    return MediaQuery.of(context).platformBrightness == Brightness.dark
        ? darkBg
        : lightBg;
  }

  static Color getCardColor(BuildContext context) {
    return MediaQuery.of(context).platformBrightness == Brightness.dark
        ? darkCard
        : lightCard;
  }

  static Color getSurface(BuildContext context) {
    return getCardColor(context);
  }

  static List<BoxShadow> getShadows(
    BuildContext context, {
    bool pressed = false,
  }) {
    return MediaQuery.of(context).platformBrightness == Brightness.dark
        ? darkShadows(pressed: pressed)
        : lightShadows(pressed: pressed);
  }
}
