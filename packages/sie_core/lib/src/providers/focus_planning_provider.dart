import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import '../local/app_database.dart';
import '../models/planning.dart';
import 'connectivity_provider.dart';
import 'planning_provider.dart';

/// Aggregated focus time invested into a goal, plus a per-task breakdown
/// (Stage 7). The local Drift store is the source of truth; when online the
/// server's cross-device focus_sessions are merged in first.
class GoalFocusStats {
  const GoalFocusStats({
    required this.totalSeconds,
    required this.topTasks,
  });

  final int totalSeconds;
  // Descending by seconds; taskName resolved from the live planning tree.
  final List<({String taskId, String taskName, int seconds})> topTasks;

  static const empty = GoalFocusStats(totalSeconds: 0, topTasks: []);
}

/// Mirrors the server's focus_sessions rows for [goalId] into Drift so offline
/// aggregation stays correct across devices. No-op when offline / unauthenticated.
Future<void> _mirrorGoalFocusSessions(Ref ref, String goalId) async {
  final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
  if (!isOnline) return;
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return;
  final db = ref.read(appDatabaseProvider);
  try {
    final raw = await client
        .from('focus_sessions')
        .select('id, user_id, duration_seconds, xp_gained, task_id, goal_id')
        .eq('goal_id', goalId);
    for (final r in (raw as List)) {
      final m = r as Map<String, dynamic>;
      await db.insertFocusSession(LocalFocusSessionsCompanion(
        id: Value(m['id'] as String),
        userId: Value(m['user_id'] as String),
        durationSeconds: Value((m['duration_seconds'] as num?)?.toInt() ?? 0),
        completedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
        xpAwarded: Value((m['xp_gained'] as num?)?.toInt() ?? 0),
        dpAwarded: const Value(0),
        synced: const Value(true),
        taskId: Value(m['task_id'] as String?),
        goalId: Value(m['goal_id'] as String?),
      ));
    }
  } catch (_) {
    // best-effort; local data remains usable
  }
}

/// Total focus seconds invested into a single task.
final taskFocusSecondsProvider =
    FutureProvider.autoDispose.family<int, String>((ref, taskId) async {
  // Recompute when planning state changes (e.g. a session just landed).
  ref.watch(planningProvider);
  final db = ref.read(appDatabaseProvider);
  return db.focusSecondsForTask(taskId);
});

/// Aggregate focus stats for a goal: total time + top tasks by time.
final goalFocusStatsProvider = FutureProvider.autoDispose
    .family<GoalFocusStats, String>((ref, goalId) async {
  final planning = ref.watch(planningProvider);
  await _mirrorGoalFocusSessions(ref, goalId);

  final db = ref.read(appDatabaseProvider);
  final total = await db.focusSecondsForGoal(goalId);
  final byTask = await db.focusSecondsByTaskForGoal(goalId);

  // Resolve task names from the live planning tree.
  final goal = planning.valueOrNull?.goals
      .where((g) => g.id == goalId)
      .firstOrNull;
  final nameById = <String, String>{};
  if (goal != null) {
    for (final sg in flattenSubGoals(goal.subGoals)) {
      for (final t in sg.tasks) {
        nameById[t.id] = t.name;
      }
    }
  }

  final entries = byTask.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topTasks = [
    for (final e in entries.take(5))
      (
        taskId: e.key,
        taskName: nameById[e.key] ?? 'Удалённая задача',
        seconds: e.value,
      ),
  ];

  return GoalFocusStats(totalSeconds: total, topTasks: topTasks);
});

/// Formats a focus duration as a compact RU label, e.g. "1ч 15м", "45м".
String formatFocusDuration(int seconds) {
  if (seconds <= 0) return '0м';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0 && m > 0) return '${h}ч ${m}м';
  if (h > 0) return '${h}ч';
  return '${m}м';
}
