import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../theme/sie_theme.dart';

class AchievementBadge extends StatelessWidget {
  final UserAchievement userAchievement;

  const AchievementBadge({super.key, required this.userAchievement});

  static const _lockedFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      0.4, 0,
  ]);

  // Slug → Material Icon mapping. Guarantees rendering on all Android versions
  // without relying on NotoColorEmoji font availability.
  static IconData _iconForSlug(String slug) => switch (slug) {
        'first_breath' => Icons.air,
        'streak_7'     => Icons.local_fire_department,
        'streak_30'    => Icons.whatshot,
        'habits_10'    => Icons.checklist,
        'xp_1000'      => Icons.bolt,
        _              => Icons.emoji_events,
      };

  @override
  Widget build(BuildContext context) {
    final earned = userAchievement.earned;
    final ach = userAchievement.achievement;

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: earned
              ? SieTheme.accent.withValues(alpha: 0.70)
              : SieTheme.borderDefault,
          width: earned ? 1.5 : 1.0,
        ),
        color: earned
            ? SieTheme.accent.withValues(alpha: 0.07)
            : SieTheme.surface,
        boxShadow: earned
            ? [
                BoxShadow(
                  color: SieTheme.accent.withValues(alpha: 0.22),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          _iconForSlug(ach.slug),
          color: earned ? SieTheme.accent : SieTheme.textSecondary,
          size: 16,
        ),
      ),
    );

    if (!earned) {
      return ColorFiltered(colorFilter: _lockedFilter, child: badge);
    }
    return badge;
  }
}
