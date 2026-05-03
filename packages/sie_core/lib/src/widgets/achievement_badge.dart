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
        child: Text(
          ach.iconEmoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );

    if (!earned) {
      return ColorFiltered(colorFilter: _lockedFilter, child: badge);
    }
    return badge;
  }
}
