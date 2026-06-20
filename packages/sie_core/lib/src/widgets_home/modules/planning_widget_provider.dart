import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../local/app_database.dart';
import '../../theme/sie_colors.dart';
import '../module_widget_provider.dart';
import '../widget_config.dart';
import '../widget_option_spec.dart';
import '../widget_size_bucket.dart';
import '../widget_theme_bridge.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class GoalTile {
  final String id;
  final String name;
  final double progress; // 0..100
  final String colorHex;

  const GoalTile({
    required this.id,
    required this.name,
    required this.progress,
    required this.colorHex,
  });
}

class MilestoneTile {
  final String name;
  final DateTime? targetDate;

  const MilestoneTile({required this.name, this.targetDate});
}

class PlanningWidgetData extends WidgetData {
  final int activeGoals;
  final int tasksDueToday;
  final int overdueTasks;
  final int tasksDoneToday;
  final double topGoalProgress; // 0..100
  final String? topGoalName;
  final List<GoalTile> topGoals; // up to 3, for the large layout
  final MilestoneTile? nextMilestone;

  const PlanningWidgetData({
    required this.activeGoals,
    required this.tasksDueToday,
    required this.overdueTasks,
    required this.tasksDoneToday,
    required this.topGoalProgress,
    required this.topGoalName,
    required this.topGoals,
    required this.nextMilestone,
  });

  /// % of today's tasks completed (due-today set), 1.0 when nothing is due.
  double get dayProgress {
    final total = tasksDueToday + tasksDoneToday;
    return total == 0 ? 1.0 : tasksDoneToday / total;
  }

  bool get isEmpty => activeGoals == 0;

  @override
  String get signature => '$activeGoals:$tasksDueToday:$overdueTasks:'
      '$tasksDoneToday:${topGoalProgress.toStringAsFixed(1)}:'
      '${topGoalName ?? ''}:${nextMilestone?.name ?? ''}:'
      '${topGoals.map((g) => '${g.id}=${g.progress.toStringAsFixed(0)}').join(',')}';
}

// ── Provider ──────────────────────────────────────────────────────────────────

class PlanningWidgetProvider extends ModuleWidgetProvider<PlanningWidgetData> {
  @override
  String get moduleId => 'planning';
  @override
  String get displayName => 'Планирование';
  @override
  IconData get glyph => Icons.flag_outlined;
  @override
  String get androidProviderClass => 'PlanningWidgetProvider';
  @override
  List<WidgetSizeBucket> get supportedSizes => const [
        WidgetSizeBucket.small,
        WidgetSizeBucket.medium,
        WidgetSizeBucket.large,
      ];

  @override
  Future<PlanningWidgetData> loadData(AppDatabase db, WidgetConfig cfg) async {
    var goals = await db.goalsForWidget();
    if (goals.isEmpty) {
      return const PlanningWidgetData(
        activeGoals: 0,
        tasksDueToday: 0,
        overdueTasks: 0,
        tasksDoneToday: 0,
        topGoalProgress: 0,
        topGoalName: null,
        topGoals: [],
        nextMilestone: null,
      );
    }

    // Studio may pin a specific goal to the "top" slot (small/medium focus);
    // 'auto' or a stale id falls back to the query's natural ordering.
    final pinnedGoalId = cfg.contentOptions['topGoal'] as String?;
    if (pinnedGoalId != null && pinnedGoalId != 'auto') {
      final idx = goals.indexWhere((g) => g.id == pinnedGoalId);
      if (idx > 0) {
        final picked = goals.removeAt(idx);
        goals = [picked, ...goals];
      }
    }

    final goalIds = goals.map((g) => g.id).toList();
    final subGoals = await db.subGoalsForGoals(goalIds);
    final subGoalIds = subGoals.map((s) => s.id).toList();
    final tasks = subGoalIds.isEmpty
        ? <LocalPlanningTask>[]
        : await db.tasksForSubGoals(subGoalIds);
    final milestones = await db.milestonesForGoals(goalIds);

    // Map subGoalId → goalId so tasks can be attributed to their goal.
    final subGoalToGoal = {for (final s in subGoals) s.id: s.goalId};

    // Per-goal weighted task completion (non-recurring tasks only).
    final doneWeight = <String, int>{};
    final totalWeight = <String, int>{};
    for (final t in tasks) {
      if (t.recurrenceParentId != null) continue; // skip recurrence instances
      final goalId = subGoalToGoal[t.subGoalId];
      if (goalId == null) continue;
      totalWeight[goalId] = (totalWeight[goalId] ?? 0) + t.weight;
      if (t.isCompleted) {
        doneWeight[goalId] = (doneWeight[goalId] ?? 0) + t.weight;
      }
    }

    double progressFor(LocalGoal g) {
      final total = totalWeight[g.id] ?? 0;
      if (total == 0) return g.progress; // stored fallback (0..100)
      return (doneWeight[g.id] ?? 0) / total * 100.0;
    }

    // Top goals are already ordered (pinned → priority → created) by the query.
    final topGoals = goals
        .take(3)
        .map((g) => GoalTile(
              id: g.id,
              name: g.name,
              progress: progressFor(g),
              colorHex: g.colorHex,
            ))
        .toList();

    // Today's task buckets across all goals.
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    var dueToday = 0, overdue = 0, doneToday = 0;
    for (final t in tasks) {
      if (t.dueDateMs == null) continue;
      final due = DateTime.fromMillisecondsSinceEpoch(t.dueDateMs!);
      final isToday = !due.isBefore(todayStart) && due.isBefore(tomorrowStart);
      if (t.isCompleted) {
        if (isToday) doneToday++;
        continue;
      }
      if (isToday) {
        dueToday++;
      } else if (due.isBefore(todayStart)) {
        overdue++;
      }
    }

    // Nearest incomplete milestone by target date.
    LocalMilestone? next;
    for (final m in milestones) {
      if (m.isCompleted || m.targetDateMs == null) continue;
      if (next == null || m.targetDateMs! < next.targetDateMs!) next = m;
    }

    return PlanningWidgetData(
      activeGoals: goals.length,
      tasksDueToday: dueToday,
      overdueTasks: overdue,
      tasksDoneToday: doneToday,
      topGoalProgress: topGoals.first.progress,
      topGoalName: topGoals.first.name,
      topGoals: topGoals,
      nextMilestone: next == null
          ? null
          : MilestoneTile(
              name: next.name,
              targetDate: next.targetDateMs == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(next.targetDateMs!),
            ),
    );
  }

  @override
  List<WidgetOptionSpec> optionSchema(WidgetSizeBucket size) => const [
        WidgetOptionSpec.toggle('showOverdue', 'Показывать просрочку'),
        WidgetOptionSpec.toggle('showMilestone', 'Показывать веху'),
      ];

  @override
  Future<List<WidgetOptionSpec>> resolveOptionSchema(
      AppDatabase db, WidgetSizeBucket size) async {
    final goals = await db.goalsForWidget();
    final choices = <String, String>{'auto': 'Авто (по приоритету)'};
    for (final g in goals) {
      choices[g.id] = g.name;
    }
    return [
      WidgetOptionSpec.enumChoice('topGoal', 'Цель для показа', choices,
          defaultValue: 'auto'),
      ...optionSchema(size),
    ];
  }

  @override
  PlanningWidgetData sampleData(WidgetSizeBucket size) => PlanningWidgetData(
        activeGoals: 4,
        tasksDueToday: 3,
        overdueTasks: 1,
        tasksDoneToday: 2,
        topGoalProgress: 64,
        topGoalName: 'Запустить проект',
        topGoals: const [
          GoalTile(
              id: '1',
              name: 'Запустить проект',
              progress: 64,
              colorHex: '#5AADA0'),
          GoalTile(
              id: '2', name: 'Выучить язык', progress: 38, colorHex: '#E0A33E'),
          GoalTile(
              id: '3', name: 'Марафон', progress: 12, colorHex: '#C0577B'),
        ],
        nextMilestone: MilestoneTile(
          name: 'MVP готов',
          targetDate: DateTime.now().add(const Duration(days: 5)),
        ),
      );

  @override
  Widget render(
      WidgetRenderContext ctx, WidgetConfig cfg, PlanningWidgetData data) {
    return switch (cfg.sizeBucket) {
      WidgetSizeBucket.small => _SmallPlanningWidget(ctx: ctx, data: data),
      WidgetSizeBucket.medium =>
        _MediumPlanningWidget(ctx: ctx, cfg: cfg, data: data),
      WidgetSizeBucket.large =>
        _LargePlanningWidget(ctx: ctx, cfg: cfg, data: data),
    };
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _parseHex(String hex, Color fallback) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

String _fmtDate(DateTime d) {
  const months = [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];
  return '${d.day} ${months[d.month - 1]}';
}

// ── Small (160×160): top-goal progress ───────────────────────────────────────

class _SmallPlanningWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final PlanningWidgetData data;

  const _SmallPlanningWidget({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    if (data.isEmpty) {
      return _EmptyPlanning(ctx: ctx, size: 160);
    }
    return Container(
      width: 160,
      height: 160,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: CustomPaint(
              painter: _RingPainter(
                progress: data.topGoalProgress / 100.0,
                ringColor: ctx.accent,
                trackColor: c.border,
              ),
              child: Center(
                child: Text(
                  '${data.topGoalProgress.round()}%',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.topGoalName ?? 'Цель',
            style: TextStyle(color: c.textSecondary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Medium (320×160): today ──────────────────────────────────────────────────

class _MediumPlanningWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final WidgetConfig cfg;
  final PlanningWidgetData data;

  const _MediumPlanningWidget(
      {required this.ctx, required this.cfg, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    if (data.isEmpty) {
      return _EmptyPlanning(ctx: ctx, size: 160, wide: true);
    }
    final showOverdue = cfg.contentOptions['showOverdue'] as bool? ?? true;
    final showMilestone = cfg.contentOptions['showMilestone'] as bool? ?? true;
    final allDone = data.tasksDueToday == 0 && data.overdueTasks == 0;
    return Container(
      width: 320,
      height: 160,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CustomPaint(
              painter: _RingPainter(
                progress: data.dayProgress,
                ringColor: allDone ? c.success : ctx.accent,
                trackColor: c.border,
              ),
              child: Center(
                child: allDone
                    ? Icon(Icons.check, color: c.success, size: 22)
                    : Text(
                        '${(data.dayProgress * 100).round()}%',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 2),
                if (allDone)
                  Text(
                    'День закрыт',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${data.tasksDueToday}',
                        style: TextStyle(
                          color: ctx.accent,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'задач на сегодня',
                        style:
                            TextStyle(color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                if (showOverdue && data.overdueTasks > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 13, color: c.danger),
                      const SizedBox(width: 4),
                      Text(
                        '${data.overdueTasks} просрочено',
                        style: TextStyle(color: c.danger, fontSize: 12),
                      ),
                    ],
                  ),
                ],
                if (showMilestone && data.nextMilestone != null) ...[
                  const SizedBox(height: 8),
                  _MilestoneChip(c: c, milestone: data.nextMilestone!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Large (320×320): plan map ────────────────────────────────────────────────

class _LargePlanningWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final WidgetConfig cfg;
  final PlanningWidgetData data;

  const _LargePlanningWidget(
      {required this.ctx, required this.cfg, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    if (data.isEmpty) {
      return _EmptyPlanning(ctx: ctx, size: 320);
    }
    final showOverdue = cfg.contentOptions['showOverdue'] as bool? ?? true;
    final showMilestone = cfg.contentOptions['showMilestone'] as bool? ?? true;
    return Container(
      width: 320,
      height: 320,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ПЛАНИРОВАНИЕ',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                '${data.activeGoals} активных',
                style: TextStyle(color: ctx.accent, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...data.topGoals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GoalBar(ctx: ctx, goal: g),
              )),
          const Spacer(),
          Container(height: 1, color: c.border),
          const SizedBox(height: 12),
          Row(
            children: [
              _TodayStat(
                c: c,
                value: '${data.tasksDueToday}',
                label: 'на сегодня',
                color: ctx.accent,
              ),
              const SizedBox(width: 20),
              if (showOverdue)
                _TodayStat(
                  c: c,
                  value: '${data.overdueTasks}',
                  label: 'просрочено',
                  color: data.overdueTasks > 0 ? c.danger : c.textSecondary,
                ),
              const Spacer(),
              if (showMilestone && data.nextMilestone != null)
                Flexible(
                  child: _MilestoneChip(c: c, milestone: data.nextMilestone!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _GoalBar extends StatelessWidget {
  final WidgetRenderContext ctx;
  final GoalTile goal;

  const _GoalBar({required this.ctx, required this.goal});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final barColor = _parseHex(goal.colorHex, ctx.accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.name,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${goal.progress.round()}%',
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (goal.progress / 100.0).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: c.border,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ],
    );
  }
}

class _TodayStat extends StatelessWidget {
  final SieColors c;
  final String value;
  final String label;
  final Color color;

  const _TodayStat({
    required this.c,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  final SieColors c;
  final MilestoneTile milestone;

  const _MilestoneChip({required this.c, required this.milestone});

  @override
  Widget build(BuildContext context) {
    final date = milestone.targetDate;
    final label = date == null
        ? milestone.name
        : '${milestone.name} · ${_fmtDate(date)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏁', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: c.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanning extends StatelessWidget {
  final WidgetRenderContext ctx;
  final double size;
  final bool wide;

  const _EmptyPlanning(
      {required this.ctx, required this.size, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    return Container(
      width: wide ? 320 : size,
      height: size,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, color: c.iconMuted, size: 32),
          const SizedBox(height: 10),
          Text(
            'Нет активных целей',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
