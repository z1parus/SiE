import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import '../widgets/momentum_chart.dart';

// ─── Local helpers (duplicated from mission_detail_screen / planning_screen) ──

IconData? _categoryIcon(GoalCategory? cat) => switch (cat) {
      GoalCategory.learning   => Icons.school_outlined,
      GoalCategory.health     => Icons.favorite_outline,
      GoalCategory.project    => Icons.rocket_launch_outlined,
      GoalCategory.lifestyle  => Icons.spa_outlined,
      GoalCategory.discipline => Icons.bolt_outlined,
      null                    => null,
    };

String _formatDate(DateTime d) =>
    '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';

// Duplicated from planning.dart (private there, not exported)
List<SubGoal> _allSubGoals(List<SubGoal> roots) {
  final result = <SubGoal>[];
  void visit(SubGoal sg) {
    result.add(sg);
    for (final child in sg.children) { visit(child); }
  }
  for (final sg in roots) { visit(sg); }
  return result;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class GoalStatsScreen extends ConsumerWidget {
  const GoalStatsScreen({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final planningAsync = ref.watch(planningProvider);
    final habitsAsync = ref.watch(habitsProvider);

    final liveGoal = planningAsync.valueOrNull?.goals
            .firstWhere((g) => g.id == goal.id, orElse: () => goal) ??
        goal;

    final habits = habitsAsync.valueOrNull?.habits ?? const [];
    final streaks = habitsAsync.valueOrNull?.streaks ?? const {};

    final advice = planningAsync.maybeWhen(
      data: (_) =>
          ref.read(planningProvider.notifier).getStrategicAdvice(liveGoal),
      orElse: () => const <String>[],
    );

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _StatsHeader(goal: liveGoal, sc: sc),
              Expanded(
                child: RefreshIndicator(
                  color: sc.accent,
                  backgroundColor: sc.isLightMode ? Colors.white : const Color(0xFF0D1B2A),
                  onRefresh: () async {
                    ref.invalidate(planningProvider);
                    ref.invalidate(habitsProvider);
                    await ref.read(planningProvider.future);
                  },
                  child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _ProgressRingCard(goal: liveGoal, sc: sc),
                    const SizedBox(height: 12),
                    _MomentumCard(goal: liveGoal, sc: sc),
                    const SizedBox(height: 12),
                    _TasksCard(goal: liveGoal, sc: sc),
                    const SizedBox(height: 12),
                    _SubGoalsCard(goal: liveGoal, sc: sc),
                    const SizedBox(height: 12),
                    if (liveGoal.milestones.isNotEmpty) ...[
                      _MilestonesCard(goal: liveGoal, sc: sc),
                      const SizedBox(height: 12),
                    ],
                    _TimeCard(goal: liveGoal, sc: sc),
                    const SizedBox(height: 12),
                    _FocusTimeCard(goal: liveGoal, sc: sc),
                    const SizedBox(height: 12),
                    if (liveGoal.habitLinks.isNotEmpty) ...[
                      _HabitsCard(
                        goal: liveGoal,
                        sc: sc,
                        habits: habits,
                        streaks: streaks,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (advice.isNotEmpty) _AdviceCard(advice: advice, sc: sc),
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

// ─── Header ───────────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final catIcon = _categoryIcon(goal.settings.category);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: BoxDecoration(
        color: sc.surface,
        border: Border(bottom: BorderSide(color: sc.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: sc.textPrimary, size: 22),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: sc.priorityColor(goal.priority),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              goal.name,
              style: TextStyle(
                color: sc.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (catIcon != null) ...[
            const SizedBox(width: 8),
            Icon(catIcon, size: 18, color: sc.textSecondary),
          ],
        ],
      ),
    );
  }
}

// ─── Progress ring ────────────────────────────────────────────────────────────

class _ProgressRingCard extends StatelessWidget {
  const _ProgressRingCard({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final progress = goalProgress(goal);
    return _Card(
      sc: sc,
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _StatsRingPainter(
                progress: progress / 100,
                color: goal.color,
                trackColor: sc.border,
              ),
              child: Center(
                child: Text(
                  '${progress.round()}%',
                  style: TextStyle(
                    color: sc.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StatusChip(status: goal.status, sc: sc),
        ],
      ),
    );
  }
}

class _StatsRingPainter extends CustomPainter {
  const _StatsRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 11) / 2;
    const strokeWidth = 11.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect, 0, math.pi * 2, false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect, -math.pi / 2, math.pi * 2 * progress, false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_StatsRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Momentum card ────────────────────────────────────────────────────────────

class _MomentumCard extends ConsumerWidget {
  const _MomentumCard({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  String _fmtShortDate(DateTime d) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(goalAnalyticsProvider(goal.id));

    return _Card(
      sc: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 14, color: sc.textSecondary),
              const SizedBox(width: 6),
              Text(
                'ИМПУЛЬС',
                style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              analyticsAsync.maybeWhen(
                data: (m) {
                  final d = momentumDisplay(m.state, sc);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: d.color.withValues(alpha: 0.12),
                      border:
                          Border.all(color: d.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(d.icon, size: 11, color: d.color),
                        const SizedBox(width: 4),
                        Text(
                          d.label,
                          style: TextStyle(
                            color: d.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          analyticsAsync.when(
            loading: () => SizedBox(
              height: 80,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: sc.accent),
                ),
              ),
            ),
            error: (_, __) => Text(
              'Не удалось загрузить аналитику темпа.',
              style: TextStyle(color: sc.textSecondary, fontSize: 12),
            ),
            data: (m) {
              if (!m.hasEnoughData) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.timelapse,
                          size: 16, color: sc.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Собираем данные о темпе… '
                          '(${m.snapshots.length}/3 замера прогресса)',
                          style: TextStyle(
                              color: sc.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final vel = m.velocityPerWeek;
              final velStr = vel >= 0
                  ? '+${vel.toStringAsFixed(0)}%'
                  : '${vel.toStringAsFixed(0)}%';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MomentumChart(
                    snapshots: m.snapshots,
                    color: goal.color,
                    sc: sc,
                    deadline: goal.deadline,
                    goalCreatedAt: goal.createdAt,
                    projected: m.projectedCompletion,
                  ),
                  const SizedBox(height: 14),
                  _LabelValueRow(
                    label: 'Темп (за 7 дней)',
                    value: '$velStr прогресса',
                    sc: sc,
                    valueColor: vel > 0
                        ? sc.success
                        : (vel < 0 ? sc.danger : sc.textSecondary),
                  ),
                  if (m.projectedCompletion != null)
                    _LabelValueRow(
                      label: 'Прогноз финиша',
                      value: _fmtShortDate(m.projectedCompletion!),
                      sc: sc,
                      valueColor: _projectionColor(m),
                    )
                  else
                    _LabelValueRow(
                      label: 'Прогноз финиша',
                      value: 'темп нулевой',
                      sc: sc,
                      valueColor: sc.textSecondary,
                    ),
                  if (m.daysVsDeadline != null)
                    _LabelValueRow(
                      label: 'Относительно дедлайна',
                      value: _deadlineDeltaLabel(m.daysVsDeadline!),
                      sc: sc,
                      valueColor: m.daysVsDeadline! >= 0
                          ? sc.success
                          : sc.danger,
                    ),
                  if (goal.deadline != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _LegendDot(color: goal.color, sc: sc, label: 'факт'),
                        const SizedBox(width: 12),
                        _LegendDot(
                            color: sc.textSecondary,
                            sc: sc,
                            label: 'идеал',
                            dashed: true),
                        const SizedBox(width: 12),
                        _LegendDot(
                            color: sc.danger,
                            sc: sc,
                            label: 'дедлайн',
                            dashed: true),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _projectionColor(MomentumStats m) {
    final delta = m.daysVsDeadline;
    if (delta == null) return sc.textPrimary;
    if (delta >= 3) return sc.success;
    if (delta >= 0) return sc.warning;
    return sc.danger;
  }

  String _deadlineDeltaLabel(int days) {
    if (days == 0) return 'точно в срок';
    if (days > 0) return 'на $days дн. раньше';
    return 'на ${days.abs()} дн. позже';
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.sc,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final SieColors sc;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 2.5,
          decoration: BoxDecoration(
            color: dashed ? color.withValues(alpha: 0.5) : color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: sc.textSecondary, fontSize: 10)),
      ],
    );
  }
}

// ─── Tasks card ───────────────────────────────────────────────────────────────

class _TasksCard extends StatelessWidget {
  const _TasksCard({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final allTasks =
        _allSubGoals(goal.subGoals).expand((sg) => sg.tasks).toList();
    final now = DateTime.now();

    final lightDone = allTasks.where((t) => t.weight == 1 && t.isCompleted).length;
    final lightTotal = allTasks.where((t) => t.weight == 1).length;
    final medDone = allTasks.where((t) => t.weight == 3 && t.isCompleted).length;
    final medTotal = allTasks.where((t) => t.weight == 3).length;
    final heavyDone = allTasks.where((t) => t.weight == 5 && t.isCompleted).length;
    final heavyTotal = allTasks.where((t) => t.weight == 5).length;
    final overdueCount = allTasks
        .where((t) =>
            !t.isCompleted && t.dueDate != null && now.isAfter(t.dueDate!))
        .length;

    final total = goal.totalTasks;
    final done = goal.completedTasks;

    return _Card(
      sc: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(title: 'Задачи', icon: Icons.task_alt_outlined, sc: sc),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _StatCell(label: 'Всего', value: '$total', sc: sc)),
            Expanded(
                child:
                    _StatCell(label: 'Выполнено', value: '$done', sc: sc)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _StatCell(
                    label: 'Лёгкие (×1)',
                    value: '$lightDone/$lightTotal',
                    sc: sc)),
            Expanded(
                child: _StatCell(
                    label: 'Средние (×3)',
                    value: '$medDone/$medTotal',
                    sc: sc)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _StatCell(
                    label: 'Тяжёлые (×5)',
                    value: '$heavyDone/$heavyTotal',
                    sc: sc)),
            Expanded(
                child: _StatCell(
                    label: 'Просроченных',
                    value: '$overdueCount',
                    sc: sc,
                    valueColor: overdueCount > 0 ? sc.danger : null)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              backgroundColor: sc.border,
              valueColor: AlwaysStoppedAnimation<Color>(goal.color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$done из $total',
            style: TextStyle(color: sc.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── SubGoals card ────────────────────────────────────────────────────────────

class _SubGoalsCard extends StatelessWidget {
  const _SubGoalsCard({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final all = _allSubGoals(goal.subGoals);
    final totalAll = all.length;
    final completedAll = all.where((sg) => sg.isCompleted).length;
    final topLevel = goal.subGoals.length;
    final nested = totalAll - topLevel;

    return _Card(
      sc: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
              title: 'Этапы', icon: Icons.account_tree_outlined, sc: sc),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _StatCell(
                    label: 'Всего этапов', value: '$totalAll', sc: sc)),
            Expanded(
                child: _StatCell(
                    label: 'Завершено', value: '$completedAll', sc: sc)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _StatCell(
                    label: 'Верхний уровень', value: '$topLevel', sc: sc)),
            Expanded(
                child:
                    _StatCell(label: 'Вложенных', value: '$nested', sc: sc)),
          ]),
        ],
      ),
    );
  }
}

// ─── Milestones card ──────────────────────────────────────────────────────────

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final total = goal.milestones.length;
    final completed = goal.milestones.where((m) => m.isCompleted).length;
    final now = DateTime.now();

    final upcoming = goal.milestones
        .where((m) =>
            !m.isCompleted &&
            m.targetDate != null &&
            m.targetDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.targetDate!.compareTo(b.targetDate!));
    final nearest = upcoming.isNotEmpty ? upcoming.first : null;

    return _Card(
      sc: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
              title: 'Контрольные точки',
              icon: Icons.flag_outlined,
              sc: sc),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child:
                    _StatCell(label: 'Всего', value: '$total', sc: sc)),
            Expanded(
                child: _StatCell(
                    label: 'Завершено', value: '$completed', sc: sc)),
          ]),
          if (nearest != null) ...[
            const SizedBox(height: 10),
            Text(
              'Ближайшая: ${nearest.name} (${_formatDate(nearest.targetDate!)})',
              style: TextStyle(color: sc.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Time card ────────────────────────────────────────────────────────────────

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysActive = now.difference(goal.createdAt).inDays;
    final daysLeft = goal.daysUntilDeadline;

    final String daysLeftValue;
    final Color? daysLeftColor;
    if (daysLeft == null) {
      daysLeftValue = '—';
      daysLeftColor = null;
    } else if (daysLeft < 0) {
      daysLeftValue = 'просрочено';
      daysLeftColor = sc.danger;
    } else {
      daysLeftValue = '$daysLeft дн.';
      daysLeftColor = null;
    }

    return _Card(
      sc: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
              title: 'Время', icon: Icons.schedule_outlined, sc: sc),
          const SizedBox(height: 12),
          _LabelValueRow(
              label: 'Создана',
              value: _formatDate(goal.createdAt),
              sc: sc),
          _LabelValueRow(
              label: 'Активна уже', value: '$daysActive дн.', sc: sc),
          _LabelValueRow(
              label: 'Обновлена',
              value: goal.updatedAt != null
                  ? _formatDate(goal.updatedAt!)
                  : '—',
              sc: sc),
          _LabelValueRow(
              label: 'Дедлайн',
              value: goal.deadline != null
                  ? _formatDate(goal.deadline!)
                  : 'не задан',
              sc: sc),
          _LabelValueRow(
              label: 'Осталось дней',
              value: daysLeftValue,
              sc: sc,
              valueColor: daysLeftColor),
        ],
      ),
    );
  }
}

// ─── Focus time card (Stage 7) ────────────────────────────────────────────────

class _FocusTimeCard extends ConsumerWidget {
  const _FocusTimeCard({required this.goal, required this.sc});

  final Goal goal;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(goalFocusStatsProvider(goal.id));

    return _Card(
      sc: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
              title: 'Время в фокусе', icon: Icons.timer_outlined, sc: sc),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: sc.accent),
                ),
              ),
            ),
            error: (_, __) => Text('—',
                style: TextStyle(color: sc.textSecondary, fontSize: 13)),
            data: (stats) {
              if (stats.totalSeconds <= 0) {
                return Text(
                  'Пока нет фокус-сессий по этой цели. Запусти ▶ на задаче, '
                  'чтобы засчитать время.',
                  style: TextStyle(
                      color: sc.textSecondary, fontSize: 12, height: 1.4),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        formatFocusDuration(stats.totalSeconds),
                        style: TextStyle(
                          color: sc.accentSecondary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('всего вложено',
                            style: TextStyle(
                                color: sc.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                  if (stats.topTasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('ТОП ЗАДАЧ ПО ВРЕМЕНИ',
                        style: TextStyle(
                            color: sc.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    ...stats.topTasks.map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 5, color: sc.accentSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.taskName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: sc.textPrimary, fontSize: 13),
                                ),
                              ),
                              Text(
                                formatFocusDuration(t.seconds),
                                style: TextStyle(
                                    color: sc.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Habits card ──────────────────────────────────────────────────────────────

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({
    required this.goal,
    required this.sc,
    required this.habits,
    required this.streaks,
  });

  final Goal goal;
  final SieColors sc;
  final List<Habit> habits;
  final Map<String, int> streaks;

  @override
  Widget build(BuildContext context) {
    return _Card(
      sc: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
              title: 'Привязанные привычки',
              icon: Icons.link,
              sc: sc),
          const SizedBox(height: 12),
          ...goal.habitLinks.map((link) {
            final habit = habits
                .cast<Habit?>()
                .firstWhere((h) => h?.id == link.habitId,
                    orElse: () => null);
            final streak = streaks[link.habitId] ?? 0;

            if (habit == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Привычка удалена',
                  style: TextStyle(
                      color: sc.textSecondary, fontSize: 13),
                ),
              );
            }

            final habitColor = Color(
                int.parse('0xFF${habit.color.replaceAll('#', '')}'));

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: habitColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.title,
                      style: TextStyle(
                          color: sc.textPrimary, fontSize: 14),
                    ),
                  ),
                  if (streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: sc.rankGold.withValues(alpha: 0.15),
                        border: Border.all(
                            color: sc.rankGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '🔥 $streak',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Advice card ──────────────────────────────────────────────────────────────

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice, required this.sc});

  final List<String> advice;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sc.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: sc.warning, size: 16),
              const SizedBox(width: 8),
              Text(
                'СОВЕТЫ',
                style: TextStyle(
                  color: sc.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...advice.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            color: sc.warning.withValues(alpha: 0.8),
                            fontSize: 12)),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                            color: sc.textSecondary,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.sc, required this.child});

  final SieColors sc;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sc.border),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(
      {required this.title, required this.icon, required this.sc});

  final String title;
  final IconData icon;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: sc.textSecondary),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: sc.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.sc,
    this.valueColor,
  });

  final String label;
  final String value;
  final SieColors sc;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: sc.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? sc.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({
    required this.label,
    required this.value,
    required this.sc,
    this.valueColor,
  });

  final String label;
  final String value;
  final SieColors sc;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: sc.textSecondary, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? sc.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Exact copy of _StatusChip from mission_detail_screen.dart
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.sc});

  final String status;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'completed' => ('ЗАВЕРШЕНА', const Color(0xFF5AADA0)),
      'frozen'    => ('ЗАМОРОЖЕНА', const Color(0xFF6A8ED8)),
      'failed'    => ('ПРОВАЛЕНА', const Color(0xFFE03050)),
      _           => ('АКТИВНА', const Color(0xFF5AADA0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
