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
    required this.glass,
    // ── Semantic tokens (Stage 0 — design system) ──────────────────────────
    // Theme-independent by default; override per mode only where needed.
    this.rankGold = const Color(0xFFFFD700),
    this.rankSilver = const Color(0xFFC0C0C8),
    this.rankBronze = const Color(0xFFCD7F32),
    this.warning = const Color(0xFFFF9800),
    this.success = const Color(0xFF34C759),
    this.danger = const Color(0xFFE03050),
    this.info = const Color(0xFF00C8FF),
    this.focusBreak = const Color(0xFF4FB0C6),
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

  /// Glass / highlight tint for translucent tube & crystal visuals — white on
  /// dark, a cool slate on light so frosted elements stay readable on a light
  /// card. Replaces the repeated `Color(0xFF5B6480)` / `Colors.white` literal.
  final Color glass;

  // ── Semantic tokens ────────────────────────────────────────────────────────
  /// Leaderboard / medal rank colours.
  final Color rankGold;
  final Color rankSilver;
  final Color rankBronze;

  /// Status semantics — used for locks/fatigue, confirmations, destructive
  /// actions and decorative info grids respectively.
  final Color warning;
  final Color success;
  final Color danger;
  final Color info;

  /// Cool tone for the focus timer's break phase (vs the gold work phase).
  final Color focusBreak;

  bool get isLightMode => mode == SieThemeMode.classicLight;

  /// Goal priority palette (1 = low … 4 = critical). Single source of truth —
  /// replaces the `_priorityColor` switch duplicated across planning,
  /// mission_detail and goal_stats screens.
  Color priorityColor(int priority) => switch (priority) {
    1 => textSecondary,
    2 => accent,
    3 => const Color(0xFFE07830),
    4 => danger,
    _ => accent,
  };

  /// Rank colour for a 1-based leaderboard / medal position.
  /// Positions beyond 3 fall back to [textSecondary].
  Color rankColor(int rank) => switch (rank) {
    1 => rankGold,
    2 => rankSilver,
    3 => rankBronze,
    _ => textSecondary,
  };

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

  /// Frosted-glass panel for carousel plaques: a translucent tinted fill painted
  /// over a [BackdropFilter] (`fill`), plus a thin neutral-glass "frame" with a
  /// soft outer glow (`frame`). The frame is drawn outside the blur clip so the
  /// glow survives. Tint and glow derive from [glass] — white on dark, cool
  /// slate on light — so the rim reads as neutral glass, not a gold accent.
  ({BoxDecoration fill, BoxDecoration frame}) glassPanel({
    double radius = 20,
  }) {
    final r = BorderRadius.circular(radius);
    if (isLightMode) {
      return (
        fill: BoxDecoration(
          color: glass.withValues(alpha: 0.10),
          borderRadius: r,
        ),
        frame: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: glass.withValues(alpha: 0.55), width: 1),
          boxShadow: [
            BoxShadow(
              color: glass.withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: 0,
            ),
          ],
        ),
      );
    }
    return (
      fill: BoxDecoration(
        color: glass.withValues(alpha: 0.06),
        borderRadius: r,
      ),
      frame: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: glass.withValues(alpha: 0.30), width: 1),
        boxShadow: [
          BoxShadow(
            color: glass.withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }

  static SieColors forMode(SieThemeMode mode) => switch (mode) {
    SieThemeMode.classicDark  => _dark,
    SieThemeMode.classicLight => _light,
  };

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
    glass: Color(0xFFFFFFFF),
  );

  static const _light = SieColors(
    mode: SieThemeMode.classicLight,
    background: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    accent:          Color(0xFFC8A84B),  // Gold Sand — primary
    accentSecondary: Color(0xFFE5C16C),  // Light Gold — secondary
    textPrimary:  Color(0xFF1C1C22),
    textSecondary: Color(0xFF646470),
    border: Color(0xFFE4E4EE),
    iconMuted: Color(0xFF9494A0),
    dp: Color(0xFF8B5CF6),
    glass: Color(0xFF5B6480),
  );
}

final sieColorsProvider = Provider<SieColors>((ref) {
  final mode = ref.watch(sieThemeModeProvider).valueOrNull
      ?? SieThemeMode.classicDark;
  return SieColors.forMode(mode);
});
