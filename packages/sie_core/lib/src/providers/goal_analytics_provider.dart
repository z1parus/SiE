import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import '../local/app_database.dart';
import '../models/goal_analytics.dart';
import '../models/planning.dart';
import 'connectivity_provider.dart';
import 'planning_provider.dart';

/// Momentum analytics for a single goal, keyed by goalId.
///
/// Snapshots are read from the local Drift store (the source of truth, kept
/// fresh by [PlanningNotifier]'s daily capture). When online, the server's
/// cross-device history is merged in first. All velocity/projection math runs
/// client-side (see goal_analytics.dart).
final goalAnalyticsProvider = FutureProvider.autoDispose
    .family<MomentumStats, String>((ref, goalId) async {
  // Recompute whenever planning state changes (e.g. a fresh snapshot landed).
  final planning = ref.watch(planningProvider);
  final goal = planning.valueOrNull?.goals
      .where((g) => g.id == goalId)
      .firstOrNull;
  if (goal == null) return MomentumStats.empty;

  final db = ref.read(appDatabaseProvider);
  final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

  if (isOnline) {
    try {
      final raw = await Supabase.instance.client
          .from('goal_progress_snapshots')
          .select()
          .eq('goal_id', goalId)
          .order('captured_at', ascending: true);
      final remote = (raw as List)
          .map((r) => GoalProgressSnapshot.fromJson(r as Map<String, dynamic>))
          .toList();
      // Mirror into local store for offline access.
      for (final s in remote) {
        final day = DateTime(
            s.capturedAt.year, s.capturedAt.month, s.capturedAt.day);
        await db.upsertGoalSnapshot(LocalGoalProgressSnapshotsCompanion(
          id: Value(s.id),
          goalId: Value(s.goalId),
          userId: Value(s.userId),
          progress: Value(s.progress),
          completedTasks: Value(s.completedTasks),
          totalTasks: Value(s.totalTasks),
          capturedAtMs: Value(s.capturedAt.millisecondsSinceEpoch),
          dayKeyMs: Value(day.millisecondsSinceEpoch),
          synced: const Value(true),
        ));
      }
    } catch (_) {
      // fall through to local
    }
  }

  final rows = await db.snapshotsForGoal(goalId);
  final snapshots = rows
      .map((r) => GoalProgressSnapshot(
            id: r.id,
            goalId: r.goalId,
            userId: r.userId,
            progress: r.progress,
            completedTasks: r.completedTasks,
            totalTasks: r.totalTasks,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(r.capturedAtMs),
          ))
      .toList();

  return computeMomentum(goal, snapshots);
});

/// Local-only momentum for the goal-list card badge. Reads snapshots straight
/// from Drift (no network) so rendering a long list of cards stays cheap; the
/// full analytics screen ([goalAnalyticsProvider]) handles cross-device sync.
final goalMomentumStateProvider = FutureProvider.autoDispose
    .family<MomentumState, String>((ref, goalId) async {
  final planning = ref.watch(planningProvider);
  final goal = planning.valueOrNull?.goals
      .where((g) => g.id == goalId)
      .firstOrNull;
  if (goal == null) return MomentumState.noData;

  final db = ref.read(appDatabaseProvider);
  final rows = await db.snapshotsForGoal(goalId);
  final snapshots = rows
      .map((r) => GoalProgressSnapshot(
            id: r.id,
            goalId: r.goalId,
            userId: r.userId,
            progress: r.progress,
            completedTasks: r.completedTasks,
            totalTasks: r.totalTasks,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(r.capturedAtMs),
          ))
      .toList();

  return computeMomentum(goal, snapshots).state;
});
