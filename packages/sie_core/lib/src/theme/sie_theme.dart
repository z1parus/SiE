import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SieThemeMode
//
// Three tiers of visual fidelity — persisted via sieThemeModeProvider.
// ─────────────────────────────────────────────────────────────────────────────
enum SieThemeMode {
  /// Full Cyber-Space experience: SieSpaceBackground starfield + liquid-glass
  /// shader cards. Highest GPU cost, best visual impact.
  cosmicLiquidGlass,

  /// Flat anthracite dark mode. No shaders, no starfield. Gold-sand accents.
  /// Suitable for lower-end devices or users who prefer minimal graphics.
  classicDark,

  /// Flat light mode. No shaders, no starfield. Seafoam-teal accents.
  classicLight,
}

// ─────────────────────────────────────────────────────────────────────────────
// SieSpaceEffects
//
// ThemeExtension carrying premium "Cyber-Space" visual design tokens.
// Inject via ThemeData.extensions; consume with:
//   Theme.of(context).extension<SieSpaceEffects>()
// Only present on the cosmicLiquidGlass ThemeData.
// ─────────────────────────────────────────────────────────────────────────────
@immutable
class SieSpaceEffects extends ThemeExtension<SieSpaceEffects> {
  const SieSpaceEffects({
    required this.glassDecoration,
    required this.primaryGradient,
    required this.accentGradient,
    required this.neonGlow,
  });

  /// Frosted-glass surface: circular radius 24, white border at 15% opacity
  /// to simulate light refraction on dark backgrounds.
  final BoxDecoration glassDecoration;

  /// Neon Cyan → Neon Purple — hero gradients, primary CTAs.
  final List<Color> primaryGradient;

  /// Neon Purple → Deep Space Purple — secondary accents, depth layers.
  final List<Color> accentGradient;

  /// Cyan neon glow — apply as [BoxDecoration.boxShadow] to signal interactivity.
  final BoxShadow neonGlow;

  // ── Canonical dark preset ──────────────────────────────────────────────────

  static final dark = SieSpaceEffects(
    glassDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.15),
      ),
    ),
    primaryGradient: const [
      Color(0xFF00E5FF), // Neon Cyan
      Color(0xFF7000FF), // Neon Purple
    ],
    accentGradient: const [
      Color(0xFF7000FF), // Neon Purple
      Color(0xFF300066), // Deep Space Purple
    ],
    neonGlow: BoxShadow(
      color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  );

  // ── ThemeExtension overrides ───────────────────────────────────────────────

  @override
  SieSpaceEffects copyWith({
    BoxDecoration? glassDecoration,
    List<Color>? primaryGradient,
    List<Color>? accentGradient,
    BoxShadow? neonGlow,
  }) =>
      SieSpaceEffects(
        glassDecoration: glassDecoration ?? this.glassDecoration,
        primaryGradient: primaryGradient ?? this.primaryGradient,
        accentGradient: accentGradient ?? this.accentGradient,
        neonGlow: neonGlow ?? this.neonGlow,
      );

  @override
  SieSpaceEffects lerp(ThemeExtension<SieSpaceEffects>? other, double t) {
    if (other is! SieSpaceEffects) return this;
    return SieSpaceEffects(
      glassDecoration:
          BoxDecoration.lerp(glassDecoration, other.glassDecoration, t) ??
              glassDecoration,
      primaryGradient: _lerpGradient(primaryGradient, other.primaryGradient, t),
      accentGradient: _lerpGradient(accentGradient, other.accentGradient, t),
      neonGlow: BoxShadow.lerp(neonGlow, other.neonGlow, t) ?? neonGlow,
    );
  }

  /// Interpolates two color lists component-wise (up to the shorter length).
  static List<Color> _lerpGradient(
    List<Color> a,
    List<Color> b,
    double t,
  ) {
    final len = a.length < b.length ? a.length : b.length;
    return List<Color>.generate(len, (i) => Color.lerp(a[i], b[i], t) ?? a[i]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SieTheme
// ─────────────────────────────────────────────────────────────────────────────
class SieTheme {
  // ── Cosmic palette (cosmicLiquidGlass) ─────────────────────────────────────

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

  static const _spaceVacuum   = Color(0xFF0A0E1A);
  static const _mutedGreyBlue = Color(0xFF90A4AE);

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
    SieThemeMode.cosmicLiquidGlass => cyberpunkDarkTheme,
    SieThemeMode.classicDark       => classicDarkTheme,
    SieThemeMode.classicLight      => classicLightTheme,
  };

  // ── Legacy dark theme (preserved for backward compatibility) ───────────────

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
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: const WidgetStatePropertyAll(borderAccent),
          trackColor:
              WidgetStatePropertyAll(borderDefault.withValues(alpha: 0.4)),
          thickness: const WidgetStatePropertyAll(4),
          radius: const Radius.circular(2),
          thumbVisibility: const WidgetStatePropertyAll(false),
          trackVisibility: const WidgetStatePropertyAll(false),
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

  // ── Cyber-Space dark theme ─────────────────────────────────────────────────

  static ThemeData get cyberpunkDarkTheme {
    final base = dark;
    return base.copyWith(
      scaffoldBackgroundColor: _spaceVacuum,
      colorScheme: ColorScheme.dark(
        primary: SieSpaceEffects.dark.primaryGradient.first,
        secondary: SieSpaceEffects.dark.accentGradient.first,
        surface: _spaceVacuum,
        onSurface: Colors.white,
        onPrimary: _spaceVacuum,
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: _mutedGreyBlue,
          fontWeight: FontWeight.w400,
        ),
      ),
      extensions: [SieSpaceEffects.dark],
    );
  }

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
      );
}
