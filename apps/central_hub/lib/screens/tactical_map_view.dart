import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

// ─── Public entry-point ───────────────────────────────────────────────────────

class TacticalMapView extends ConsumerStatefulWidget {
  const TacticalMapView({super.key, required this.goal});
  final Goal goal;

  @override
  ConsumerState<TacticalMapView> createState() => _TacticalMapViewState();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _TacticalMapViewState extends ConsumerState<TacticalMapView> {
  final Map<String, Offset> _positions = {};
  final _tc = TransformationController();
  String? _draggingId;

  static const double _cx = 1200.0;
  static const double _cs = 2400.0;

  Goal get _goal => widget.goal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerView());
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _centerView() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final s = box.size;
    _tc.value = Matrix4.translationValues(s.width / 2 - _cx, s.height / 2 - _cx, 0);
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  void _ensureSubGoalPositions(SubGoal sg) {
    // Position child sub-goals around this sub-goal
    final children = sg.children;
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      if (!_positions.containsKey(child.id)) {
        final sgPos = _positions[sg.id]!;
        final base = math.atan2(sgPos.dy, sgPos.dx) + math.pi / 2;
        const spread = math.pi * 0.7;
        final angle = children.length <= 1
            ? base
            : base + (-spread / 2 + spread * i / (children.length - 1));
        _positions[child.id] =
            sgPos + Offset(160 * math.cos(angle), 160 * math.sin(angle));
      }
      _ensureSubGoalPositions(child);
    }
    // Position tasks for this sub-goal
    final tasks = sg.tasks;
    for (int j = 0; j < tasks.length; j++) {
      final t = tasks[j];
      if (!_positions.containsKey(t.id)) {
        final sgPos = _positions[sg.id]!;
        final base = math.atan2(sgPos.dy, sgPos.dx);
        const spread = math.pi * 0.8;
        final ta = tasks.length <= 1
            ? base
            : base + (-spread / 2 + spread * j / (tasks.length - 1));
        _positions[t.id] =
            sgPos + Offset(145 * math.cos(ta), 145 * math.sin(ta));
      }
    }
  }

  void _ensurePositions(Goal goal) {
    _positions[goal.id] = Offset.zero;

    final sgs = goal.subGoals;
    for (int i = 0; i < sgs.length; i++) {
      final sg = sgs[i];
      if (!_positions.containsKey(sg.id)) {
        final angle =
            (2 * math.pi * i / math.max(sgs.length, 1)) - math.pi / 2;
        _positions[sg.id] = Offset(240 * math.cos(angle), 240 * math.sin(angle));
      }
      _ensureSubGoalPositions(sg);
    }

    final mss = goal.milestones;
    for (int i = 0; i < mss.length; i++) {
      if (!_positions.containsKey(mss[i].id)) {
        final angle =
            (2 * math.pi * i / math.max(mss.length, 1)) + math.pi / 4;
        _positions[mss[i].id] =
            Offset(200 * math.cos(angle), 200 * math.sin(angle));
      }
    }

    final links = goal.habitLinks;
    for (int i = 0; i < links.length; i++) {
      if (!_positions.containsKey(links[i].id)) {
        final angle =
            (2 * math.pi * i / math.max(links.length, 1)) + math.pi / 6;
        _positions[links[i].id] =
            Offset(320 * math.cos(angle), 320 * math.sin(angle));
      }
    }

    final allSgs = _flatSubGoals(goal.subGoals);
    final all = {
      goal.id,
      ...allSgs.map((sg) => sg.id),
      ...allSgs.expand((sg) => sg.tasks).map((t) => t.id),
      ...goal.milestones.map((m) => m.id),
      ...goal.habitLinks.map((l) => l.id),
    };
    _positions.removeWhere((k, _) => !all.contains(k));
  }

  List<SubGoal> _flatSubGoals(List<SubGoal> roots) {
    final result = <SubGoal>[];
    void visit(SubGoal sg) {
      result.add(sg);
      for (final child in sg.children) visit(child);
    }
    for (final sg in roots) visit(sg);
    return result;
  }

  // ── Collision resolution ──────────────────────────────────────────────────

  double _nodeRadius(String id, Goal goal) {
    if (id == goal.id) return 80.0;
    final allSgs = _flatSubGoals(goal.subGoals);
    if (allSgs.any((sg) => sg.id == id)) return 55.0;
    final task = allSgs.expand((sg) => sg.tasks).where((t) => t.id == id).firstOrNull;
    if (task != null) return switch (task.weight) { 5 => 36, 3 => 28, _ => 22 };
    if (goal.milestones.any((m) => m.id == id)) return 40.0;
    if (goal.habitLinks.any((l) => l.id == id)) return 26.0;
    return 30.0;
  }

  void _resolveCollisions(String movedId, Goal goal) {
    for (int iter = 0; iter < 30; iter++) {
      bool any = false;
      final ids = _positions.keys.toList();
      for (int i = 0; i < ids.length; i++) {
        for (int j = i + 1; j < ids.length; j++) {
          final a = ids[i];
          final b = ids[j];
          final pa = _positions[a]!;
          final pb = _positions[b]!;
          final minD = _nodeRadius(a, goal) + _nodeRadius(b, goal) + 18.0;
          final diff = pb - pa;
          final dist = diff.distance;
          if (dist < minD && dist > 0.001) {
            final push = (minD - dist) / 2.0;
            final dir = diff / dist;
            if (a != movedId && a != goal.id) _positions[a] = pa - dir * push;
            if (b != movedId && b != goal.id) _positions[b] = pb + dir * push;
            any = true;
          }
        }
      }
      if (!any) break;
    }
  }

  // ── Interactions ──────────────────────────────────────────────────────────

  void _onTap(String nodeId, Goal goal) {
    final c = ref.read(sieColorsProvider);
    if (nodeId == goal.id) {
      _showGoalSheet(goal, c);
      return;
    }
    final allSgs = _flatSubGoals(goal.subGoals);
    final sg = allSgs.where((s) => s.id == nodeId).firstOrNull;
    if (sg != null) {
      _showSubGoalSheet(sg, goal, c);
      return;
    }
    final task = allSgs.expand((s) => s.tasks).where((t) => t.id == nodeId).firstOrNull;
    if (task != null) {
      final parent = allSgs.firstWhere((s) => s.tasks.any((t) => t.id == nodeId));
      _showTaskSheet(task, parent, goal, c);
      return;
    }
    final ms = goal.milestones.where((m) => m.id == nodeId).firstOrNull;
    if (ms != null) {
      _showMilestoneSheet(ms, goal, c);
      return;
    }
    final lnk = goal.habitLinks.where((l) => l.id == nodeId).firstOrNull;
    if (lnk != null) _showHabitLinkSheet(lnk, goal, c);
  }

  // ── Bottom sheets ─────────────────────────────────────────────────────────

  void _showGoalSheet(Goal goal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => _AddNodeSheet(
        sc: c,
        onAddSubGoal: (name) {
          ref.read(planningProvider.notifier).addSubGoal(goal.id, name);
          Navigator.pop(ctx);
        },
        onAddMilestone: (name) {
          ref.read(planningProvider.notifier).addMilestone(goal.id, name);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showSubGoalSheet(SubGoal sg, Goal goal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => _SubGoalSheet(
        sg: sg,
        sc: c,
        onAddTask: (name, weight) {
          ref
              .read(planningProvider.notifier)
              .addTask(goalId: goal.id, subGoalId: sg.id, name: name, weight: weight);
          Navigator.pop(ctx);
        },
        onComplete: sg.isCompleted
            ? null
            : () {
                ref
                    .read(planningProvider.notifier)
                    .completeSubGoal(sg.id, goal.id);
                Navigator.pop(ctx);
              },
        onDelete: () {
          ref.read(planningProvider.notifier).deleteSubGoal(sg.id, goal.id);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showTaskSheet(PlanningTask task, SubGoal sg, Goal goal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TaskSheet(
        task: task,
        sc: c,
        onToggle: () {
          ref
              .read(planningProvider.notifier)
              .toggleTask(task.id, sg.id, goal.id);
          Navigator.pop(ctx);
        },
        onDelete: () {
          ref
              .read(planningProvider.notifier)
              .deleteTask(task.id, sg.id, goal.id);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showMilestoneSheet(Milestone ms, Goal goal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MilestoneSheet(
        ms: ms,
        sc: c,
        onComplete: ms.isCompleted
            ? null
            : () {
                ref
                    .read(planningProvider.notifier)
                    .completeMilestone(ms.id, goal.id);
                Navigator.pop(ctx);
              },
        onDelete: () {
          ref
              .read(planningProvider.notifier)
              .deleteMilestone(ms.id, goal.id);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showHabitLinkSheet(GoalHabitLink lnk, Goal goal, SieColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _HabitLinkSheet(
        link: lnk,
        sc: c,
        onUnlink: () {
          ref.read(planningProvider.notifier).unlinkHabit(lnk.id, goal.id);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final goal = ref
            .watch(planningProvider)
            .valueOrNull
            ?.goals
            .where((g) => g.id == _goal.id)
            .firstOrNull ??
        widget.goal;

    _ensurePositions(goal);

    final goalPos = _positions[goal.id] ?? Offset.zero;

    final edges = <_Edge>[];
    void addSubGoalEdges(SubGoal sg, Offset parentPos, _EType edgeType) {
      final sgPos = _positions[sg.id];
      if (sgPos == null) return;
      edges.add(_Edge(parentPos, sgPos, edgeType));
      for (final t in sg.tasks) {
        final tp = _positions[t.id];
        if (tp != null) edges.add(_Edge(sgPos, tp, _EType.subTask));
      }
      for (final child in sg.children) {
        addSubGoalEdges(child, sgPos, _EType.subSub);
      }
    }
    for (final sg in goal.subGoals) {
      addSubGoalEdges(sg, goalPos, _EType.goalSub);
    }
    for (final ms in goal.milestones) {
      final mp = _positions[ms.id];
      if (mp != null) edges.add(_Edge(goalPos, mp, _EType.goalMs));
    }
    for (final l in goal.habitLinks) {
      final lp = _positions[l.id];
      if (lp != null) edges.add(_Edge(goalPos, lp, _EType.goalHabit));
    }

    return InteractiveViewer(
      transformationController: _tc,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(800),
      minScale: 0.15,
      maxScale: 3.0,
      child: SizedBox(
        width: _cs,
        height: _cs,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Grid
            Positioned.fill(child: CustomPaint(painter: _GridPainter(c))),
            // Edges
            Positioned.fill(
              child: CustomPaint(painter: _EdgePainter(edges, _cx, c)),
            ),
            // Habit links
            for (final l in goal.habitLinks)
              _posNode(
                l.id,
                42,
                42,
                goal,
                _HabitLinkNode(link: l, sc: c, dragging: _draggingId == l.id),
              ),
            // Milestones
            for (final ms in goal.milestones)
              _posNode(
                ms.id,
                80,
                80,
                goal,
                _MilestoneNode(ms: ms, sc: c, dragging: _draggingId == ms.id),
              ),
            // Tasks and nested sub-goals (all depths)
            for (final sg in _flatSubGoals(goal.subGoals)) ...[
              for (final t in sg.tasks)
                _taskPosNode(t, sg.id, goal, c),
              _posNode(
                sg.id,
                158,
                68,
                goal,
                _SubGoalNode(
                  sg: sg,
                  sc: c,
                  dragging: _draggingId == sg.id,
                  onAdd: () => _showSubGoalSheet(sg, goal, c),
                ),
              ),
            ],
            // Goal (fixed, topmost)
            Positioned(
              left: _cx - 80,
              top: _cx - 80,
              child: _GoalNode(
                goal: goal,
                sc: c,
                onTap: () => _showGoalSheet(goal, c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _taskW(int w) => switch (w) { 5 => 124, 3 => 104, _ => 84 };

  Widget _taskPosNode(PlanningTask task, String currentSgId, Goal goal, SieColors c) {
    final pos = _positions[task.id];
    if (pos == null) return const SizedBox.shrink();
    final w = _taskW(task.weight);
    const h = 40.0;
    return Positioned(
      left: _cx + pos.dx - w / 2,
      top: _cx + pos.dy - h / 2,
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(task.id, goal),
        onPanStart: (_) => setState(() => _draggingId = task.id),
        onPanUpdate: (d) {
          final scale = _tc.value.getMaxScaleOnAxis();
          setState(() => _positions[task.id] = _positions[task.id]! + d.delta / scale);
        },
        onPanEnd: (_) {
          _tryReparentTask(task.id, currentSgId, goal);
          _resolveCollisions(task.id, goal);
          setState(() => _draggingId = null);
        },
        child: _TaskNode(task: task, sc: c, dragging: _draggingId == task.id),
      ),
    );
  }

  void _tryReparentTask(String taskId, String currentSgId, Goal goal) {
    final taskPos = _positions[taskId];
    if (taskPos == null) return;
    const threshold = 120.0;
    String? nearestSgId;
    double nearestDist = threshold;
    for (final sg in _flatSubGoals(goal.subGoals)) {
      final sgPos = _positions[sg.id];
      if (sgPos == null) continue;
      final dist = (taskPos - sgPos).distance;
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestSgId = sg.id;
      }
    }
    if (nearestSgId != null && nearestSgId != currentSgId) {
      ref.read(planningProvider.notifier).moveTask(taskId, nearestSgId);
    }
  }

  Widget _posNode(String id, double w, double h, Goal goal, Widget child) {
    final pos = _positions[id];
    if (pos == null) return const SizedBox.shrink();
    return Positioned(
      left: _cx + pos.dx - w / 2,
      top: _cx + pos.dy - h / 2,
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(id, goal),
        onPanStart: (_) => setState(() => _draggingId = id),
        onPanUpdate: (d) {
          final scale = _tc.value.getMaxScaleOnAxis();
          setState(
              () => _positions[id] = _positions[id]! + d.delta / scale);
        },
        onPanEnd: (_) {
          _resolveCollisions(id, goal);
          setState(() => _draggingId = null);
        },
        child: child,
      ),
    );
  }
}

// ─── Edge types & data ────────────────────────────────────────────────────────

enum _EType { goalSub, subSub, subTask, goalMs, goalHabit }

class _Edge {
  const _Edge(this.src, this.dst, this.type);
  final Offset src;
  final Offset dst;
  final _EType type;
}

// ─── Grid painter ─────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter(this.c);
  final SieColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = c.border.withOpacity(c.isLightMode ? 0.45 : 0.25)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.c != c;
}

// ─── Edge painter ─────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  const _EdgePainter(this.edges, this.center, this.c);
  final List<_Edge> edges;
  final double center;
  final SieColors c;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final src = Offset(center + e.src.dx, center + e.src.dy);
      final dst = Offset(center + e.dst.dx, center + e.dst.dy);

      final (color, width, dashed) = switch (e.type) {
        _EType.goalSub => (c.accent.withOpacity(0.38), 2.0, false),
        _EType.subSub => (c.border.withOpacity(0.9), 1.5, true),
        _EType.subTask => (c.border.withOpacity(0.8), 1.5, false),
        _EType.goalMs => (c.accentSecondary.withOpacity(0.45), 1.5, true),
        _EType.goalHabit => (c.dp.withOpacity(0.35), 1.2, false),
      };

      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final diff = dst - src;
      final dist = diff.distance;
      if (dist < 1) continue;
      final px = -diff.dy / dist * dist * 0.28;
      final py = diff.dx / dist * dist * 0.28;
      final cp1 = Offset(src.dx + diff.dx * 0.38 + px, src.dy + diff.dy * 0.38 + py);
      final cp2 = Offset(src.dx + diff.dx * 0.62 - px, src.dy + diff.dy * 0.62 - py);

      final path = Path()
        ..moveTo(src.dx, src.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, dst.dx, dst.dy);

      if (dashed) {
        _drawDashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    for (final m in path.computeMetrics()) {
      double d = 0;
      bool draw = true;
      while (d < m.length) {
        final len = draw ? dash : gap;
        if (draw) {
          canvas.drawPath(
              m.extractPath(d, math.min(d + len, m.length)), paint);
        }
        d += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

// ─── Goal Node ────────────────────────────────────────────────────────────────

class _GoalNode extends StatelessWidget {
  const _GoalNode({required this.goal, required this.sc, required this.onTap});
  final Goal goal;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = goalProgress(goal) / 100;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        height: 160,
        child: CustomPaint(
          painter: _GoalRingPainter(goal: goal, progress: progress),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                goal.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sc.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  const _GoalRingPainter({required this.goal, required this.progress});
  final Goal goal;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = goal.color.withOpacity(0.13)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = goal.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r - 4),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = goal.color.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - 4),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = goal.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) => old.progress != progress;
}

// ─── SubGoal Node ─────────────────────────────────────────────────────────────

class _SubGoalNode extends StatelessWidget {
  const _SubGoalNode({
    required this.sg,
    required this.sc,
    required this.dragging,
    required this.onAdd,
  });
  final SubGoal sg;
  final SieColors sc;
  final bool dragging;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final prog = subGoalProgress(sg);
    final done = sg.isCompleted;
    final c = sc;

    final fill = done
        ? c.accent.withOpacity(0.28)
        : prog > 0
            ? c.accent.withOpacity(0.12)
            : c.surface;
    final border = done ? c.accent : prog > 0 ? c.accent.withOpacity(0.5) : c.border;

    final completedTasks = sg.tasks.where((t) => t.isCompleted).length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: dragging ? 2.0 : 1.5),
            boxShadow: dragging
                ? [BoxShadow(color: c.accent.withOpacity(0.3), blurRadius: 14, spreadRadius: 2)]
                : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (done)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.check_circle, size: 11, color: c.accent),
                          ),
                        Expanded(
                          child: Text(
                            sg.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              decoration: done ? TextDecoration.lineThrough : null,
                              decorationColor: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sg.tasks.isNotEmpty)
                      Text(
                        '$completedTasks/${sg.tasks.length}',
                        style: TextStyle(color: c.textSecondary, fontSize: 9),
                      ),
                  ],
                ),
              ),
              if (prog > 0 && !done)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                    child: LinearProgressIndicator(
                      value: prog / 100,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(c.accent.withOpacity(0.55)),
                      minHeight: 4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: -9,
          right: -9,
          child: GestureDetector(
            onTap: onAdd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              child: Icon(Icons.add, size: 13, color: c.background),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Task Node ────────────────────────────────────────────────────────────────

class _TaskNode extends StatelessWidget {
  const _TaskNode({required this.task, required this.sc, required this.dragging});
  final PlanningTask task;
  final SieColors sc;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    final alpha = switch (task.weight) { 5 => 0.27, 3 => 0.16, _ => 0.08 };
    final fill = c.accent.withOpacity(task.isCompleted ? alpha + 0.05 : alpha);
    final border = task.isCompleted ? c.accent : c.accent.withOpacity(0.3 + task.weight * 0.06);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: dragging ? 2.0 : 1.5),
        boxShadow: dragging
            ? [BoxShadow(color: c.accent.withOpacity(0.22), blurRadius: 10)]
            : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                task.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 10,
                  fontWeight: task.weight == 5 ? FontWeight.w600 : FontWeight.w400,
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: c.textSecondary,
                ),
              ),
            ),
          ),
          Positioned(
            right: 5,
            bottom: 2,
            child: Text(
              '×${task.weight}',
              style: TextStyle(color: c.textSecondary, fontSize: 8, fontWeight: FontWeight.w500),
            ),
          ),
          if (task.isCompleted)
            Positioned(
              left: 5,
              top: 0,
              bottom: 0,
              child: Center(child: Icon(Icons.check, size: 10, color: c.accent)),
            ),
        ],
      ),
    );
  }
}

// ─── Milestone Node ───────────────────────────────────────────────────────────

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({required this.ms, required this.sc, required this.dragging});
  final Milestone ms;
  final SieColors sc;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    final sec = c.accentSecondary;
    final fill = ms.isCompleted ? sec.withOpacity(0.35) : sec.withOpacity(0.14);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sec, width: dragging ? 2.5 : 2.0),
              boxShadow: dragging
                  ? [BoxShadow(color: sec.withOpacity(0.3), blurRadius: 10)]
                  : null,
            ),
            child: Center(
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Icon(
                  ms.isCompleted ? Icons.flag : Icons.outlined_flag,
                  size: 18,
                  color: sec,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 78,
          child: Text(
            ms.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 8),
          ),
        ),
        if (ms.targetDate != null)
          Text(
            '${ms.targetDate!.day}.${ms.targetDate!.month.toString().padLeft(2, '0')}',
            style: TextStyle(color: c.textSecondary.withOpacity(0.6), fontSize: 7),
          ),
      ],
    );
  }
}

// ─── Habit Link Node ──────────────────────────────────────────────────────────

class _HabitLinkNode extends StatelessWidget {
  const _HabitLinkNode({required this.link, required this.sc, required this.dragging});
  final GoalHabitLink link;
  final SieColors sc;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: c.dp.withOpacity(0.14),
        shape: BoxShape.circle,
        border: Border.all(color: c.dp, width: dragging ? 2.0 : 1.5),
        boxShadow: dragging
            ? [BoxShadow(color: c.dp.withOpacity(0.28), blurRadius: 8)]
            : null,
      ),
      child: Icon(Icons.link, size: 16, color: c.dp),
    );
  }
}

// ─── Sheet: Add node (SubGoal / Milestone) ────────────────────────────────────

class _AddNodeSheet extends StatefulWidget {
  const _AddNodeSheet(
      {required this.sc,
      required this.onAddSubGoal,
      required this.onAddMilestone});
  final SieColors sc;
  final ValueChanged<String> onAddSubGoal;
  final ValueChanged<String> onAddMilestone;

  @override
  State<_AddNodeSheet> createState() => _AddNodeSheetState();
}

class _AddNodeSheetState extends State<_AddNodeSheet> {
  final _ctrl = TextEditingController();
  String _mode = 'subgoal';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Chip(label: 'Под-цель', selected: _mode == 'subgoal', sc: c,
                  onTap: () => setState(() => _mode = 'subgoal')),
              const SizedBox(width: 8),
              _Chip(label: 'Чекпоинт', selected: _mode == 'milestone', sc: c,
                  onTap: () => setState(() => _mode = 'milestone')),
            ],
          ),
          const SizedBox(height: 14),
          _StyledTextField(
            ctrl: _ctrl,
            hint: _mode == 'subgoal' ? 'Название под-цели' : 'Название чекпоинта',
            sc: c,
            onSubmit: _submit,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _submit([String? _]) {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    if (_mode == 'subgoal') {
      widget.onAddSubGoal(v);
    } else {
      widget.onAddMilestone(v);
    }
  }
}

// ─── Sheet: SubGoal ───────────────────────────────────────────────────────────

class _SubGoalSheet extends StatefulWidget {
  const _SubGoalSheet({
    required this.sg,
    required this.sc,
    required this.onAddTask,
    this.onComplete,
    required this.onDelete,
  });
  final SubGoal sg;
  final SieColors sc;
  final void Function(String name, int weight) onAddTask;
  final VoidCallback? onComplete;
  final VoidCallback onDelete;

  @override
  State<_SubGoalSheet> createState() => _SubGoalSheetState();
}

class _SubGoalSheetState extends State<_SubGoalSheet> {
  bool _adding = false;
  final _ctrl = TextEditingController();
  int _weight = 1;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.sc;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(title: widget.sg.name, icon: Icons.layers_outlined, sc: c),
          const SizedBox(height: 16),
          if (!_adding) ...[
            if (widget.onComplete != null) ...[
              _ActionBtn(
                  label: 'Завершить',
                  icon: Icons.check_circle_outline,
                  color: c.accent,
                  sc: c,
                  onTap: widget.onComplete!),
              const SizedBox(height: 8),
            ],
            _ActionBtn(
                label: 'Добавить задачу',
                icon: Icons.add_task,
                color: c.accent,
                sc: c,
                onTap: () => setState(() => _adding = true)),
            const SizedBox(height: 8),
            _ActionBtn(
                label: 'Удалить',
                icon: Icons.delete_outline,
                color: const Color(0xFFE03050),
                sc: c,
                onTap: widget.onDelete),
          ] else ...[
            _StyledTextField(ctrl: _ctrl, hint: 'Название задачи', sc: c, onSubmit: _submitTask),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Вес:', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const SizedBox(width: 8),
                for (final w in [1, 3, 5])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _weight = w),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _weight == w ? c.accent : c.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _weight == w ? c.accent : c.border),
                        ),
                        child: Text('×$w',
                            style: TextStyle(
                              color: _weight == w ? c.background : c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _adding = false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Отмена', style: TextStyle(color: c.textSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submitTask(null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.background,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Добавить'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _submitTask([String? _]) {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.onAddTask(v, _weight);
  }
}

// ─── Sheet: Task ──────────────────────────────────────────────────────────────

class _TaskSheet extends StatelessWidget {
  const _TaskSheet(
      {required this.task,
      required this.sc,
      required this.onToggle,
      required this.onDelete});
  final PlanningTask task;
  final SieColors sc;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SheetHeader(title: task.name, icon: Icons.task_alt, sc: c),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('×${task.weight}',
                    style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ActionBtn(
            label: task.isCompleted ? 'Отметить невыполненной' : 'Выполнено',
            icon: task.isCompleted ? Icons.radio_button_unchecked : Icons.check_circle_outline,
            color: c.accent,
            sc: c,
            onTap: onToggle,
          ),
          const SizedBox(height: 8),
          _ActionBtn(
              label: 'Удалить',
              icon: Icons.delete_outline,
              color: const Color(0xFFE03050),
              sc: c,
              onTap: onDelete),
        ],
      ),
    );
  }
}

// ─── Sheet: Milestone ─────────────────────────────────────────────────────────

class _MilestoneSheet extends StatelessWidget {
  const _MilestoneSheet(
      {required this.ms, required this.sc, this.onComplete, required this.onDelete});
  final Milestone ms;
  final SieColors sc;
  final VoidCallback? onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
              title: ms.name,
              icon: ms.isCompleted ? Icons.flag : Icons.outlined_flag,
              sc: c,
              iconColor: c.accentSecondary),
          if (ms.targetDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Цель: ${ms.targetDate!.day}.${ms.targetDate!.month.toString().padLeft(2, '0')}.${ms.targetDate!.year}',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          if (onComplete != null) ...[
            _ActionBtn(
                label: 'Достигнут',
                icon: Icons.flag,
                color: c.accentSecondary,
                sc: c,
                onTap: onComplete!),
            const SizedBox(height: 8),
          ],
          _ActionBtn(
              label: 'Удалить',
              icon: Icons.delete_outline,
              color: const Color(0xFFE03050),
              sc: c,
              onTap: onDelete),
        ],
      ),
    );
  }
}

// ─── Sheet: Habit Link ────────────────────────────────────────────────────────

class _HabitLinkSheet extends StatelessWidget {
  const _HabitLinkSheet(
      {required this.link, required this.sc, required this.onUnlink});
  final GoalHabitLink link;
  final SieColors sc;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(title: 'Связанная привычка', icon: Icons.link, sc: c, iconColor: c.dp),
          const SizedBox(height: 16),
          _ActionBtn(
              label: 'Отвязать привычку',
              icon: Icons.link_off,
              color: const Color(0xFFE03050),
              sc: c,
              onTap: onUnlink),
        ],
      ),
    );
  }
}

// ─── Shared sheet widgets ─────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(
      {required this.title,
      required this.icon,
      required this.sc,
      this.iconColor});
  final String title;
  final IconData icon;
  final SieColors sc;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return Row(
      children: [
        Icon(icon, color: iconColor ?? c.accent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
                color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.sc,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label,
      required this.selected,
      required this.sc,
      required this.onTap});
  final String label;
  final bool selected;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.accent : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.background : c.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  const _StyledTextField(
      {required this.ctrl,
      required this.hint,
      required this.sc,
      this.onSubmit});
  final TextEditingController ctrl;
  final String hint;
  final SieColors sc;
  final ValueChanged<String>? onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = sc;
    return TextField(
      controller: ctrl,
      autofocus: true,
      style: TextStyle(color: c.textPrimary),
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary),
        filled: true,
        fillColor: c.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );
  }
}
