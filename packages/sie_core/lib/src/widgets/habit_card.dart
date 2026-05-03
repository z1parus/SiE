import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/sie_theme.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool completedToday;
  final int streak;
  final Set<String> allLogDates;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;

  const HabitCard({
    super.key,
    required this.habit,
    required this.completedToday,
    required this.streak,
    required this.allLogDates,
    required this.onToggle,
    this.onLongPress,
  });

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Color get _habitColor {
    final h = habit.color.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  @override
  Widget build(BuildContext context) {
    final color = _habitColor;
    final today = DateTime.now();
    final weekDays =
        List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: completedToday
              ? color.withValues(alpha: 0.06)
              : SieTheme.surface,
          borderRadius: BorderRadius.circular(4),
          // Uniform border — borderRadius requires all sides to share one color.
          border: Border.all(
            color: completedToday
                ? color.withValues(alpha: 0.40)
                : SieTheme.borderDefault,
          ),
          boxShadow: completedToday
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        // IntrinsicHeight lets the left color bar stretch to match card height.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar — separate child to avoid mixed-color border.
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: color,
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
                                color: completedToday
                                    ? color
                                    : SieTheme.textPrimary,
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
                                style: const TextStyle(
                                  color: SieTheme.textSecondary,
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
                                        color: done
                                            ? color
                                            : SieTheme.borderDefault,
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
                                        color:
                                            color.withValues(alpha: 0.50),
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      '$streak D',
                                      style: TextStyle(
                                        color: color,
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
                                ? color.withValues(alpha: 0.15)
                                : Colors.transparent,
                            border: Border.all(
                              color: completedToday
                                  ? color
                                  : SieTheme.borderDefault,
                              width: completedToday ? 1.5 : 1.0,
                            ),
                          ),
                          child: completedToday
                              ? Icon(Icons.check, color: color, size: 16)
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
