import 'package:flutter/material.dart';

ThemeData buildLiftLabTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
    primaryColor: const Color(0xFF3B82F6), // Blue 500
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF8B5CF6),
      surface: Color(0xFF1E293B), // Slate 800
      error: Color(0xFFEF4444),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    cardColor: const Color(0xFF1E293B), // Slate 800
    dividerColor: const Color(0xFF334155), // Slate 700
  );
}

