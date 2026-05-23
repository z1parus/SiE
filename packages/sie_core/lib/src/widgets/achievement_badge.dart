import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../models/achievement.dart';
import '../theme/sie_theme.dart';

const _kGold  = Color(0xFFFFD700);
const _kAmber = Color(0xFFFFB300);
const _kFrost = Color(0xFF0A1628);

const _lockedFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      0.4, 0,
]);

IconData _iconForSlug(String slug) => switch (slug) {
      'first_breath' => Icons.air,
      'streak_7'     => Icons.local_fire_department,
      'streak_30'    => Icons.whatshot,
      'habits_10'    => Icons.checklist,
      'xp_1000'      => Icons.bolt,
      _              => Icons.emoji_events,
    };

class AchievementBadge extends StatelessWidget {
  const AchievementBadge({super.key, required this.userAchievement});

  final UserAchievement userAchievement;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size     = min(constraints.maxWidth, constraints.maxHeight);
        final iconSize = (size * 0.36).clamp(14.0, 30.0);
        final fontSize = (size * 0.13).clamp(7.0, 11.0);
        final slug     = userAchievement.achievement.slug;
        final name     = userAchievement.achievement.name;

        return userAchievement.earned
            ? _UnlockedBadge(slug: slug, name: name, iconSize: iconSize, fontSize: fontSize)
            : _LockedBadge(slug: slug, name: name, iconSize: iconSize, fontSize: fontSize);
      },
    );
  }
}

// ── Unlocked — amber-tinted glass card with gold glow halo ────────────────────
class _UnlockedBadge extends StatelessWidget {
  const _UnlockedBadge({
    required this.slug,
    required this.name,
    required this.iconSize,
    required this.fontSize,
  });
  final String slug;
  final String name;
  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Gold diffusion halo behind the card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kGold.withValues(alpha: 0.30),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          shape: LiquidRoundedSuperellipse(borderRadius: 16),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: LiquidGlassSettings(
            blur: 2.5,
            thickness: 22,
            refractiveIndex: 1.45,
            glassColor: _kAmber.withValues(alpha: 0.11),
            lightAngle: GlassDefaults.lightAngle,
            lightIntensity: 0.88,
            glowIntensity: 1.0,
            saturation: 1.6,
            specularSharpness: GlassSpecularSharpness.sharp,
            ambientStrength: 0.10,
            chromaticAberration: 0.012,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconForSlug(slug),
                color: _kGold,
                size: iconSize,
                shadows: [
                  Shadow(
                    color: _kGold.withValues(alpha: 0.75),
                    blurRadius: 10,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: _kGold,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  height: 1.2,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Locked — desaturated frost container at 20 % opacity ─────────────────────
class _LockedBadge extends StatelessWidget {
  const _LockedBadge({
    required this.slug,
    required this.name,
    required this.iconSize,
    required this.fontSize,
  });
  final String slug;
  final String name;
  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.20,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _kFrost,
          border: Border.all(
            color: const Color(0xFF1E3A5F),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: ColorFiltered(
          colorFilter: _lockedFilter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconForSlug(slug),
                color: SieTheme.textSecondary,
                size: iconSize,
              ),
              const SizedBox(height: 4),
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: SieTheme.textSecondary,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                  height: 1.2,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
