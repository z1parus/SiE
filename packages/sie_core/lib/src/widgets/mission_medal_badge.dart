import 'package:flutter/material.dart';
import '../models/mission_medal.dart';
import '../models/planning.dart';

// ─── Level colors ─────────────────────────────────────────────────────────────

const _kBronze = Color(0xFFCD7F32);
const _kSilver = Color(0xFFC0C0C0);
const _kGold   = Color(0xFFFFD700);

Color medalLevelColor(int level) => switch (level) {
      3 => _kGold,
      2 => _kSilver,
      _ => _kBronze,
    };

String medalLevelLabel(int level) => switch (level) {
      3 => 'GOLD',
      2 => 'SILVER',
      _ => 'BRONZE',
    };

// ─── Category icon helper ─────────────────────────────────────────────────────

IconData categoryIconData(GoalCategory? cat) => switch (cat) {
      GoalCategory.learning   => Icons.school_outlined,
      GoalCategory.health     => Icons.favorite_outline,
      GoalCategory.project    => Icons.rocket_launch_outlined,
      GoalCategory.lifestyle  => Icons.spa_outlined,
      GoalCategory.discipline => Icons.bolt_outlined,
      null                    => Icons.military_tech,
    };

Color categoryIconColor(GoalCategory? cat) => switch (cat) {
      GoalCategory.learning   => const Color(0xFF4A90D9),
      GoalCategory.health     => const Color(0xFF5AAD6A),
      GoalCategory.project    => const Color(0xFFE07830),
      GoalCategory.lifestyle  => const Color(0xFF9B59B6),
      GoalCategory.discipline => const Color(0xFFF4C430),
      null                    => const Color(0xFF5AADA0),
    };

// ─── Badge widget ─────────────────────────────────────────────────────────────

class MissionMedalBadge extends StatelessWidget {
  const MissionMedalBadge({
    super.key,
    required this.medal,
    this.size = 72,
    this.onTap,
    this.count,
  });

  final MissionMedal medal;
  final double size;
  final VoidCallback? onTap;
  /// When > 1, shows a count badge on the bottom-right of the circle.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final levelColor = medalLevelColor(medal.level);
    final isGold     = medal.level == 3;
    // Vanguard medals: lightning bolt in level color; goal medals: category icon
    final catColor = medal.isVanguard ? levelColor : categoryIconColor(medal.category);
    final icon     = medal.isVanguard ? Icons.bolt : categoryIconData(medal.category);

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: levelColor.withValues(alpha: 0.1),
        border: Border.all(color: levelColor, width: isGold ? 2.5 : 1.8),
        boxShadow: isGold
            ? [
                BoxShadow(
                  color: catColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: size * 0.42, color: catColor),
    );

    final showCount = count != null && count! > 1;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                circle,
                if (showCount)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1525),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: levelColor, width: 1),
                      ),
                      child: Text(
                        '×${count!}',
                        style: TextStyle(
                          color: levelColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: size,
            child: Text(
              medal.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: levelColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
