import 'planning.dart';

// ─── Snapshot ───────────────────────────────────────────────────────────────

/// A point-in-time record of a goal's overall progress (0–100).
class GoalProgressSnapshot {
  const GoalProgressSnapshot({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.progress,
    required this.completedTasks,
    required this.totalTasks,
    required this.capturedAt,
  });

  final String id;
  final String goalId;
  final String userId;
  final double progress; // 0–100
  final int completedTasks;
  final int totalTasks;
  final DateTime capturedAt;

  factory GoalProgressSnapshot.fromJson(Map<String, dynamic> j) =>
      GoalProgressSnapshot(
        id: j['id'] as String,
        goalId: j['goal_id'] as String,
        userId: j['user_id'] as String,
        progress: (j['progress'] as num).toDouble(),
        completedTasks: (j['completed_tasks'] as num?)?.toInt() ?? 0,
        totalTasks: (j['total_tasks'] as num?)?.toInt() ?? 0,
        capturedAt: DateTime.parse(j['captured_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'goal_id': goalId,
        'user_id': userId,
        'progress': progress,
        'completed_tasks': completedTasks,
        'total_tasks': totalTasks,
        'captured_at': capturedAt.toIso8601String(),
      };
}

// ─── Momentum state ─────────────────────────────────────────────────────────

enum MomentumState { accelerating, steady, stalling, atRisk, noData }

/// Aggregated momentum analytics for a single goal, computed client-side from
/// its progress snapshot history.
class MomentumStats {
  const MomentumStats({
    required this.snapshots,
    required this.velocityPerWeek,
    required this.projectedCompletion,
    required this.state,
    required this.currentProgress,
    this.deadline,
  });

  final List<GoalProgressSnapshot> snapshots;
  final double velocityPerWeek; // %-points per 7 days (can be negative)
  final DateTime? projectedCompletion; // null when velocity ≤ 0 / not enough data
  final MomentumState state;
  final double currentProgress; // 0–100
  final DateTime? deadline;

  bool get hasEnoughData => snapshots.length >= 3;

  /// Days early (+) or late (−) versus the deadline. null when either side
  /// is unknown.
  int? get daysVsDeadline {
    if (deadline == null || projectedCompletion == null) return null;
    return deadline!.difference(projectedCompletion!).inDays;
  }

  static const empty = MomentumStats(
    snapshots: [],
    velocityPerWeek: 0,
    projectedCompletion: null,
    state: MomentumState.noData,
    currentProgress: 0,
    deadline: null,
  );
}

// ─── Pure computations ──────────────────────────────────────────────────────

/// Velocity in %-points per week, derived via least-squares linear regression
/// over the snapshots within the trailing [windowDays] window. Falls back to a
/// simple first/last delta when only two points are available.
double velocityPerWeek(List<GoalProgressSnapshot> snapshots,
    {int windowDays = 14}) {
  if (snapshots.length < 2) return 0;

  final sorted = [...snapshots]
    ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
  final latest = sorted.last.capturedAt;
  final cutoff = latest.subtract(Duration(days: windowDays));
  var window = sorted.where((s) => !s.capturedAt.isBefore(cutoff)).toList();
  if (window.length < 2) window = sorted; // widen if window too sparse

  // x = days since first point, y = progress.
  final t0 = window.first.capturedAt;
  final xs = window
      .map((s) => s.capturedAt.difference(t0).inMinutes / (60.0 * 24.0))
      .toList();
  final ys = window.map((s) => s.progress).toList();
  final n = xs.length;

  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;

  double num = 0, den = 0;
  for (var i = 0; i < n; i++) {
    num += (xs[i] - meanX) * (ys[i] - meanY);
    den += (xs[i] - meanX) * (xs[i] - meanX);
  }
  if (den == 0) {
    // All points on same day — use first/last delta over elapsed days.
    final days = sorted.last.capturedAt.difference(t0).inMinutes / (60.0 * 24.0);
    if (days <= 0) return 0;
    return (sorted.last.progress - sorted.first.progress) / days * 7.0;
  }
  final slopePerDay = num / den; // %-points per day
  return slopePerDay * 7.0;
}

/// Projected completion date from current progress and velocity.
/// Returns null when velocity is ≤ 0 (no forward momentum) or already complete.
DateTime? projectedCompletion(double currentProgress, double velPerWeek,
    {DateTime? from}) {
  final now = from ?? DateTime.now();
  if (currentProgress >= 100) return now;
  final perDay = velPerWeek / 7.0;
  if (perDay <= 0) return null;
  final remaining = 100 - currentProgress;
  final days = remaining / perDay;
  if (days.isInfinite || days.isNaN || days > 3650) return null; // cap 10y
  return now.add(Duration(days: days.ceil()));
}

/// The ideal burndown/up line as two endpoints: (createdAt, 0) → (deadline, 100).
/// Returns null when there is no deadline.
({DateTime start, DateTime end})? burndownSpan(Goal goal) {
  if (goal.deadline == null) return null;
  return (start: goal.createdAt, end: goal.deadline!);
}

/// Classifies a goal's momentum for the card badge.
MomentumState momentumState({
  required List<GoalProgressSnapshot> snapshots,
  required double velPerWeek,
  required double currentProgress,
  DateTime? deadline,
  DateTime? projected,
}) {
  if (snapshots.length < 3) return MomentumState.noData;
  if (currentProgress >= 100) return MomentumState.steady;

  // At risk: a deadline exists and either projection overshoots it, or there
  // is no forward momentum at all.
  if (deadline != null) {
    final overshoots = projected == null || projected.isAfter(deadline);
    if (overshoots && velPerWeek <= 2) return MomentumState.atRisk;
  }

  if (velPerWeek <= 0.5) return MomentumState.stalling;
  if (velPerWeek >= 8) return MomentumState.accelerating;
  return MomentumState.steady;
}

/// Builds full momentum analytics from raw snapshots + the live goal.
MomentumStats computeMomentum(Goal goal, List<GoalProgressSnapshot> snapshots) {
  final current = goalProgress(goal);
  final vel = velocityPerWeek(snapshots);
  final projected = snapshots.length >= 3
      ? projectedCompletion(current, vel)
      : null;
  final state = momentumState(
    snapshots: snapshots,
    velPerWeek: vel,
    currentProgress: current,
    deadline: goal.deadline,
    projected: projected,
  );
  return MomentumStats(
    snapshots: snapshots,
    velocityPerWeek: vel,
    projectedCompletion: projected,
    state: state,
    currentProgress: current,
    deadline: goal.deadline,
  );
}
