import 'package:flutter/material.dart';

class SieTheme {
  static const background = Color(0xFF07111D);
  static const surface = Color(0xFF0B1E30);
  static const surfaceAlt = Color(0xFF102840);
  static const accent = Color(0xFF00C8FF);
  static const accentSecondary = Color(0xFF3D85C8);
  static const textPrimary = Color(0xFFC8DCF0);
  static const textSecondary = Color(0xFF6A90B0);
  static const borderDefault = Color(0xFF1A3A5C);
  static const borderAccent = Color(0xFF005F80);
  static const dp = Color(0xFF9D50BB);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accentSecondary,
          surface: surface,
          onSurface: textPrimary,
          onPrimary: background,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceAlt,
          contentTextStyle: const TextStyle(
            color: textPrimary,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: borderAccent),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
          labelSmall: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      );
}
