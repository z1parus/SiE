import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../theme/sie_colors.dart';

class HabitCard extends ConsumerWidget {
  final Habit habit;
  final bool completedToday;
  final int streak;
  final Set<String> allLogDates;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;

  /// 0.0 = neutral, 1.0 = fully swiped to threshold.
  final double swipeProgress;

  /// null = not swiping, true = left (delete), false = right (pin).
  final bool? swipeIsLeft;

  const HabitCard({
    super.key,
    required this.habit,
    required this.completedToday,
    required this.streak,
    required this.allLogDates,
    required this.onToggle,
    this.onLongPress,
    this.swipeProgress = 0.0,
    this.swipeIsLeft,
  });

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Color get _habitColor {
    final h = habit.color.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final color = _habitColor;
    final today = DateTime.now();
    final weekDays =
        List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    // ── Swipe color derivation ────────────────────────────────
    final swiping = swipeProgress > 0.001 && swipeIsLeft != null;
    final p = swipeProgress.clamp(0.0, 1.0);

    final swipeBg = (swipeIsLeft ?? false)
        ? const Color(0xFF8B0000)
        : const Color(0xFFDAA520);
    final swipeFgStrong =
        (swipeIsLeft ?? false) ? Colors.white : Colors.black;
    final swipeFgSoft = (swipeIsLeft ?? false)
        ? Colors.white.withValues(alpha: 0.75)
        : Colors.black.withValues(alpha: 0.65);

    Color lerp(Color base, Color target) =>
        swiping ? Color.lerp(base, target, p)! : base;

    final baseBg = completedToday
        ? color.withValues(alpha: 0.06)
        : c.surface;
    final cardBg = lerp(baseBg, swipeBg);

    final baseBorder = completedToday
        ? color.withValues(alpha: 0.40)
        : c.border;
    final cardBorder = lerp(baseBorder, swipeBg.withValues(alpha: 0.50));

    final titleColor = lerp(
      completedToday ? color : c.textPrimary,
      swipeFgStrong,
    );
    final descColor = lerp(c.textSecondary, swipeFgSoft);
    final dotDone = lerp(color, swipeFgStrong);
    final dotIdle = lerp(c.border, swipeFgSoft);
    final accentCol = lerp(color, swipeFgStrong);
    final accentColSoft = lerp(
      color.withValues(alpha: 0.50),
      swipeFgStrong.withValues(alpha: 0.50),
    );
    final barColor = lerp(color, swipeFgStrong);

    // ── Widget tree ───────────────────────────────────────────
    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        // Duration.zero during swipe → immediate color response.
        duration: swiping
            ? Duration.zero
            : const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: cardBorder),
          boxShadow: completedToday && !swiping
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    bottomLeft: Radius.circular(3),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.title.toUpperCase(),
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (habit.description != null &&
                                habit.description!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                habit.description!,
                                style: TextStyle(
                                  color: descColor,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ...weekDays.map((day) {
                                  final done =
                                      allLogDates.contains(_fmt(day));
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(right: 4),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: done ? dotDone : dotIdle,
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 8),
                                if (streak > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: accentColSoft),
                                      borderRadius:
                                          BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      '$streak D',
                                      style: TextStyle(
                                        color: accentCol,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onToggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: completedToday
                                ? accentCol.withValues(alpha: 0.15)
                                : Colors.transparent,
                            border: Border.all(
                              color: completedToday
                                  ? accentCol
                                  : lerp(c.border, swipeFgSoft),
                              width: completedToday ? 1.5 : 1.0,
                            ),
                          ),
                          child: completedToday
                              ? Icon(Icons.check,
                                  color: accentCol, size: 16)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
