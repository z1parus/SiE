import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sie_theme_mode_provider.dart';
import 'sie_theme.dart';

@immutable
class SieColors {
  const SieColors({
    required this.mode,
    required this.background,
    required this.surface,
    required this.accent,
    required this.accentSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.iconMuted,
    required this.dp,
  });

  final SieThemeMode mode;
  final Color background;
  final Color surface;
  final Color accent;
  final Color accentSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color iconMuted;
  final Color dp;

  bool get isCosmicMode => mode == SieThemeMode.cosmicLiquidGlass;
  bool get isLightMode  => mode == SieThemeMode.classicLight;

  BoxDecoration flatCard({double radius = 16}) {
    if (isLightMode) {
      return BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      );
    }
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
    );
  }

  BoxDecoration subtleContainer({double radius = 20}) {
    if (isLightMode) {
      return BoxDecoration(
        color: const Color(0x0A000000),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 0.8),
      );
    }
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 0.8,
      ),
    );
  }

  static SieColors forMode(SieThemeMode mode) => switch (mode) {
    SieThemeMode.cosmicLiquidGlass => _cosmic,
    SieThemeMode.classicDark       => _dark,
    SieThemeMode.classicLight      => _light,
  };

  static const _cosmic = SieColors(
    mode: SieThemeMode.cosmicLiquidGlass,
    background: Color(0xFF0A0E1A),
    surface: Color(0xFF0B1E30),
    accent: Color(0xFF00E5FF),
    accentSecondary: Color(0xFF7000FF),
    textPrimary: Color(0xFFC8DCF0),
    textSecondary: Color(0xFF90A4AE),
    border: Color(0xFF1A3A5C),
    iconMuted: Color(0xFF90A4AE),
    dp: Color(0xFF9D50BB),
  );

  static const _dark = SieColors(
    mode: SieThemeMode.classicDark,
    background: Color(0xFF1C1C22),
    surface: Color(0xFF252529),
    accent: Color(0xFFC8A84B),
    accentSecondary: Color(0xFFAA7744),
    textPrimary: Color(0xFFE4E4EC),
    textSecondary: Color(0xFF888898),
    border: Color(0xFF3E3E48),
    iconMuted: Color(0xFF888898),
    dp: Color(0xFFAA7744),
  );

  static const _light = SieColors(
    mode: SieThemeMode.classicLight,
    background: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF5AADA0),
    accentSecondary: Color(0xFF3D9489),
    textPrimary: Color(0xFF1C1C22),
    textSecondary: Color(0xFF646470),
    border: Color(0xFFE4E4EE),
    iconMuted: Color(0xFF9494A0),
    dp: Color(0xFF8B5CF6),
  );
}

final sieColorsProvider = Provider<SieColors>((ref) {
  final mode = ref.watch(sieThemeModeProvider).valueOrNull
      ?? SieThemeMode.cosmicLiquidGlass;
  return SieColors.forMode(mode);
});
