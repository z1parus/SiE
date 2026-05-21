import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SieSpaceEffects
//
// ThemeExtension carrying premium "Cyber-Space" visual design tokens.
// Inject via ThemeData.extensions; consume with:
//   Theme.of(context).extension<SieSpaceEffects>()
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
  // ── Color palette ──────────────────────────────────────────────────────────

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

  // Private tokens for cyberpunkDarkTheme only.
  static const _spaceVacuum    = Color(0xFF0A0E1A);
  static const _mutedGreyBlue  = Color(0xFF90A4AE);

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

  /// Full "Cyber-Space" dark theme with [SieSpaceEffects] injected.
  ///
  /// Built on top of [dark] via copyWith so every style defined there
  /// (cardTheme, snackBarTheme, scrollbarTheme, labelSmall, etc.) is
  /// inherited automatically — zero regressions on screens not yet refactored.
  ///
  /// New text tokens added on top of [dark]:
  ///   • headlineLarge — w800, white
  ///   • titleLarge    — w700, white
  ///   • bodyLarge     — w400, white
  ///   • bodyMedium    — w400, muted grey-blue (overrides base value)
  ///
  /// Access the extension in widgets:
  /// ```dart
  /// Theme.of(context).extension<SieSpaceEffects>()
  /// ```
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
        // Inherits fontSize (13) and height (1.5) from base; only
        // updates color to the muted grey-blue cyberpunk palette tone.
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: _mutedGreyBlue,
          fontWeight: FontWeight.w400,
        ),
      ),
      extensions: [SieSpaceEffects.dark],
    );
  }
}
