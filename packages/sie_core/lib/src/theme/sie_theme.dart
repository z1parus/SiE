import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SieThemeMode
//
// Two tiers of visual fidelity — persisted via sieThemeModeProvider.
// ─────────────────────────────────────────────────────────────────────────────
enum SieThemeMode {
  /// Flat anthracite dark mode. No shaders, no starfield. Gold-sand accents.
  classicDark,

  /// Flat light mode. Seafoam-teal accents.
  classicLight,
}

// ─────────────────────────────────────────────────────────────────────────────
// SieTheme
// ─────────────────────────────────────────────────────────────────────────────
class SieTheme {
  // ── Cyber-Space palette (used as fallback colors in cosmetic_asset models) ──

  static const background      = Color(0xFF07111D);
  static const surface         = Color(0xFF0B1E30);
  static const surfaceAlt      = Color(0xFF102840);
  static const accent          = Color(0xFF00C8FF);
  static const accentSecondary = Color(0xFF3D85C8);
  static const textPrimary     = Color(0xFFC8DCF0);
  static const textSecondary   = Color(0xFF6A90B0);
  static const borderDefault   = Color(0xFF1A3A5C);
  static const borderAccent    = Color(0xFF005F80);
  static const dp              = Color(0xFF9D50BB);

  // ── Classic Dark palette ───────────────────────────────────────────────────

  static const cdBackground    = Color(0xFF1C1C22); // anthracite
  static const cdSurface       = Color(0xFF252529);
  static const cdAccent        = Color(0xFFC8A84B); // gold-sand
  static const cdBorder        = Color(0xFF3E3E48);
  static const cdTextPrimary   = Color(0xFFE4E4EC);
  static const cdTextSecondary = Color(0xFF888898);
  static const cdDp            = Color(0xFFAA7744); // warm bronze

  // ── Classic Light palette ──────────────────────────────────────────────────

  static const clBackground    = Color(0xFFF5F6FA); // crisp light grey
  static const clSurface       = Color(0xFFFFFFFF);
  static const clAccent        = Color(0xFF5AADA0); // seafoam teal
  static const clBorder        = Color(0xFFE4E4EE);
  static const clTextPrimary   = Color(0xFF1C1C22);
  static const clTextSecondary = Color(0xFF646470);
  static const clDp            = Color(0xFF8B5CF6); // muted violet

  // ── Theme routing ──────────────────────────────────────────────────────────

  static ThemeData themeDataFor(SieThemeMode mode) => switch (mode) {
    SieThemeMode.classicDark  => classicDarkTheme,
    SieThemeMode.classicLight => classicLightTheme,
  };

  // ── Classic Dark theme ─────────────────────────────────────────────────────

  static ThemeData get classicDarkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: cdBackground,
        colorScheme: ColorScheme.dark(
          primary: cdAccent,
          secondary: cdAccent,
          surface: cdSurface,
          onSurface: cdTextPrimary,
          onPrimary: cdBackground,
        ),
        cardTheme: CardThemeData(
          color: cdSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: cdBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: cdSurface,
          contentTextStyle: const TextStyle(
            color: cdTextPrimary,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: cdBorder),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: const WidgetStatePropertyAll(cdBorder),
          trackColor: WidgetStatePropertyAll(cdBorder.withValues(alpha: 0.4)),
          thickness: const WidgetStatePropertyAll(4),
          radius: const Radius.circular(2),
          thumbVisibility: const WidgetStatePropertyAll(false),
          trackVisibility: const WidgetStatePropertyAll(false),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: cdTextPrimary,
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: TextStyle(
            color: cdTextPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
          titleLarge: TextStyle(
            color: cdTextPrimary,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: cdTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
          bodyLarge: TextStyle(
            color: cdTextPrimary,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            color: cdTextSecondary,
            fontSize: 13,
            height: 1.5,
          ),
          labelSmall: TextStyle(
            color: cdAccent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        pageTransitionsTheme: _cupertinoTransitions,
      );

  // ── Classic Light theme ────────────────────────────────────────────────────

  static ThemeData get classicLightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: clBackground,
        colorScheme: ColorScheme.light(
          primary: clAccent,
          secondary: clAccent,
          surface: clSurface,
          onSurface: clTextPrimary,
          onPrimary: clSurface,
        ),
        cardTheme: CardThemeData(
          color: clSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: clBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: clSurface,
          contentTextStyle: const TextStyle(
            color: clTextPrimary,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: clBorder),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: const WidgetStatePropertyAll(clBorder),
          trackColor: WidgetStatePropertyAll(clBorder.withValues(alpha: 0.5)),
          thickness: const WidgetStatePropertyAll(4),
          radius: const Radius.circular(2),
          thumbVisibility: const WidgetStatePropertyAll(false),
          trackVisibility: const WidgetStatePropertyAll(false),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: clTextPrimary,
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: TextStyle(
            color: clTextPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
          titleLarge: TextStyle(
            color: clTextPrimary,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: clTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
          bodyLarge: TextStyle(
            color: clTextPrimary,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            color: clTextSecondary,
            fontSize: 13,
            height: 1.5,
          ),
          labelSmall: TextStyle(
            color: clAccent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        pageTransitionsTheme: _cupertinoTransitions,
      );
}

// Cupertino-style page transitions for all platforms — enables swipe-back
// gesture on Android (and keeps the familiar iOS slide on iOS).
final _cupertinoTransitions = const PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux:   CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
  },
);
