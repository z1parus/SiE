import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import '../widgets/habit_heatmap.dart';
import 'habit_tracker_screen.dart';

class HabitsOverviewScreen extends ConsumerWidget {
  const HabitsOverviewScreen({super.key});

  static Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00C8FF);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc      = ref.watch(sieColorsProvider);
    final dash    = ref.watch(habitsDashboardProvider);
    final state   = ref.watch(habitsProvider).valueOrNull;
    final accent  = sc.accent;

    final weekPct  = (dash.weeklyCompletionRate * 100).round();
    final monthPct = (dash.monthlyCompletionRate * 100).round();

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.arrow_back_ios_new,
                          color: sc.textSecondary, size: 15),
                    ),
                    const SizedBox(width: 16),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'HABITS ',
                            style: TextStyle(
                              color: accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: 'OVERVIEW',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  children: [
                    // ── Completion rate strip ─────────────────────────────
                    Row(
                      children: [
                        _RateCard(
                          sc: sc,
                          accent: accent,
                          label: 'НЕДЕЛЯ',
                          percent: weekPct,
                          total: dash.totalHabits,
                        ),
                        const SizedBox(width: 12),
                        _RateCard(
                          sc: sc,
                          accent: accent,
                          label: 'МЕСЯЦ',
                          percent: monthPct,
                          total: dash.totalHabits,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ── Aggregate heatmap (last 28 days) ─────────────────
                    Text(
                      'ДИСЦИПЛИНА · 28 ДНЕЙ',
                      style: TextStyle(
                        color: sc.textSecondary.withValues(alpha: 0.55),
                        fontSize: 9,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AggregateHeatmap(
                      completionByDate: dash.heatmapCompletionByDate,
                      sc: sc,
                      accentColor: accent,
                    ),
                    const SizedBox(height: 20),
                    // ── Top habits ────────────────────────────────────────
                    if (dash.topHabits.isNotEmpty) ...[
                      Text(
                        'ЛИДЕРЫ',
                        style: TextStyle(
                          color: sc.textSecondary.withValues(alpha: 0.55),
                          fontSize: 9,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in dash.topHabits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HabitRankTile(
                            sc: sc,
                            habit: r.habit,
                            rate: r.rate,
                            accentColor: _hexColor(r.habit.color),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    HabitDetailScreen(habit: r.habit),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    // ── Lagging habits ────────────────────────────────────
                    if (dash.laggingHabits.isNotEmpty) ...[
                      Text(
                        'ПРОСЕДАЮТ',
                        style: TextStyle(
                          color: sc.textSecondary.withValues(alpha: 0.55),
                          fontSize: 9,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in dash.laggingHabits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HabitRankTile(
                            sc: sc,
                            habit: r.habit,
                            rate: r.rate,
                            accentColor: _hexColor(r.habit.color),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    HabitDetailScreen(habit: r.habit),
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (state != null && state.habits.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'Привычки не добавлены',
                            style: TextStyle(
                              color: sc.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  final SieColors sc;
  final Color accent;
  final String label;
  final int percent;
  final int total;

  const _RateCard({
    required this.sc,
    required this.accent,
    required this.label,
    required this.percent,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SieGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: sc.textSecondary.withValues(alpha: 0.6),
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$percent%',
              style: TextStyle(
                color: accent,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: percent / 100,
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(accent),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitRankTile extends StatelessWidget {
  final SieColors sc;
  final Habit habit;
  final double rate;
  final Color accentColor;
  final VoidCallback onTap;

  const _HabitRankTile({
    required this.sc,
    required this.habit,
    required this.rate,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (rate * 100).round();
    return SieGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          if (habit.icon != null)
            Text(habit.icon!, style: const TextStyle(fontSize: 16))
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: accentColor),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: rate.clamp(0, 1),
                    backgroundColor: accentColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(accentColor),
                    minHeight: 2.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$pct%',
            style: TextStyle(
              color: accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
