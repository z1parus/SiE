import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement.dart';
import '../theme/sie_colors.dart';

const _kGold     = Color(0xFFFFD700);
const _kAmber    = Color(0xFFFFB300);
const _kGoldDark = Color(0xFF7B4F00);

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

class AchievementBadge extends ConsumerWidget {
  const AchievementBadge({super.key, required this.userAchievement});

  final UserAchievement userAchievement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size     = min(constraints.maxWidth, constraints.maxHeight);
        final iconSize = (size * 0.36).clamp(14.0, 30.0);
        final fontSize = (size * 0.13).clamp(7.0, 11.0);
        final slug     = userAchievement.achievement.slug;
        final name     = userAchievement.achievement.name;

        return userAchievement.earned
            ? _UnlockedBadge(
                slug: slug,
                name: name,
                iconSize: iconSize,
                fontSize: fontSize,
              )
            : _LockedBadge(
                slug: slug,
                name: name,
                iconSize: iconSize,
                fontSize: fontSize,
                c: c,
              );
      },
    );
  }
}

// ── Unlocked — gold Container. Glow intensity adapts to light mode.
class _UnlockedBadge extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final c         = ref.watch(sieColorsProvider);
    final iconColor = c.isLightMode ? _kGoldDark : _kGold;
    final textColor = c.isLightMode ? _kGoldDark : _kGold;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _kAmber.withValues(alpha: 0.09),
        border: Border.all(
          color: _kGold.withValues(alpha: c.isLightMode ? 0.70 : 0.40),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _kGold.withValues(alpha: c.isLightMode ? 0.45 : 0.20),
            blurRadius: c.isLightMode ? 20 : 14,
            spreadRadius: c.isLightMode ? 2 : 1,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _iconForSlug(slug),
            color: iconColor,
            size: iconSize,
            shadows: [
              Shadow(
                color: _kGold.withValues(alpha: 0.70),
                blurRadius: 10,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              color: textColor,
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
    );
  }
}

// ── Locked — uses SieColors so light mode gets a white surface + grey border
class _LockedBadge extends StatelessWidget {
  const _LockedBadge({
    required this.slug,
    required this.name,
    required this.iconSize,
    required this.fontSize,
    required this.c,
  });
  final String slug;
  final String name;
  final double iconSize;
  final double fontSize;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.20,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: c.surface,
          border: Border.all(color: c.border, width: 1.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: ColorFiltered(
          colorFilter: _lockedFilter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconForSlug(slug),
                color: c.textSecondary,
                size: iconSize,
              ),
              const SizedBox(height: 4),
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: c.textSecondary,
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
