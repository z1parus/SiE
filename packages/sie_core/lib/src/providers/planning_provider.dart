import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/planning.dart';
import '../models/goal_analytics.dart';
import '../models/goal_collaborator.dart';
import '../models/public_profile.dart';
import '../models/mission_medal.dart';
import '../models/mission_template.dart';
import '../models/ai_decomposition.dart';
import '../services/notification_service.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';
import 'habits_provider.dart';
import 'mission_templates_provider.dart';
import 'notification_provider.dart';
import 'user_profile_provider.dart';
import 'user_timezone_provider.dart';

const _uuid = Uuid();

/// Outcome of attempting to add a task dependency (Stage 8).
enum DependencyResult { ok, cycle, duplicate, invalid }

/// Above this many map-position entries, JSON encoding is offloaded to a
/// background isolate via [compute] to keep the UI thread free.
const _kPositionsComputeThreshold = 120;

/// Top-level so it can be sent to a background isolate by [compute].
String _encodeJson(Object? data) => jsonEncode(data);

// ── Sub-goal tree helpers ─────────────────────────────────────────────────────

List<SubGoal> _updateSubGoalInTree(
    List<SubGoal> sgs, String id, SubGoal Function(SubGoal) fn) {
  return sgs.map((sg) {
    if (sg.id == id) return fn(sg);
    if (sg.children.isNotEmpty) {
      return sg.copyWith(
          children: _updateSubGoalInTree(sg.children, id, fn));
    }
    return sg;
  }).toList();
}

List<SubGoal> _addChildToSubGoal(
    List<SubGoal> sgs, String parentId, SubGoal child) {
  return sgs.map((sg) {
    if (sg.id == parentId) return sg.copyWith(children: [...sg.children, child]);
    if (sg.children.isNotEmpty) {
      return sg.copyWith(
          children: _addChildToSubGoal(sg.children, parentId, child));
    }
    return sg;
  }).toList();
}

List<SubGoal> _removeSubGoalFromTree(List<SubGoal> sgs, String id) {
  return sgs
      .where((sg) => sg.id != id)
      .map((sg) => sg.children.isNotEmpty
          ? sg.copyWith(children: _removeSubGoalFromTree(sg.children, id))
          : sg)
      .toList();
}

List<SubGoal> _allSubGoals(List<SubGoal> roots) {
  final result = <SubGoal>[];
  void visit(SubGoal sg) {
    result.add(sg);
    for (final child in sg.children) visit(child);
  }
  for (final sg in roots) visit(sg);
  return result;
}

final planningProvider =
    AsyncNotifierProvider.autoDispose<PlanningNotifier, PlanningState>(
  PlanningNotifier.new,
);

bool _isMetricAchieved(Milestone m) {
  if (!m.isMetric) return false;
  final current = m.currentValue;
  final target = m.targetValue;
  if (current == null || target == null) return false;
  return m.direction == 'up' ? current >= target : current <= target;
}

// Lazily loaded per-milestone log list.  Used by sparkline + history screen.
final milestoneLogsProvider = FutureProvider.autoDispose
    .family<List<MilestoneLog>, String>((ref, milestoneId) async {
  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  if (session == null) return [];

  final db = ref.read(appDatabaseProvider);
  final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

  if (isOnline) {
    try {
      final raw = await client
          .from('milestone_logs')
          .select()
          .eq('milestone_id', milestoneId)
          .order('recorded_at', ascending: true);
      final logs = (raw as List)
          .map((r) => MilestoneLog.fromJson(r as Map<String, dynamic>))
          .toList();
      for (final log in logs) {
        await db.insertMilestoneLog(LocalMilestoneLogsCompanion(
          id: Value(log.id),
          milestoneId: Value(log.milestoneId),
          userId: Value(log.userId),
          value: Value(log.value),
          recordedAtMs: Value(log.recordedAt.millisecondsSinceEpoch),
          synced: const Value(true),
        ));
      }
      return logs;
    } catch (_) {}
  }

  final rows = await db.logsForMilestone(milestoneId);
  return rows
      .map((r) => MilestoneLog(
            id: r.id,
            milestoneId: r.milestoneId,
            userId: r.userId,
            value: r.value,
            recordedAt: DateTime.fromMillisecondsSinceEpoch(r.recordedAtMs),
          ))
      .toList();
});

class PlanningNotifier extends AutoDisposeAsyncNotifier<PlanningState> {
  @override
  Future<PlanningState> build() async {
    ref.watch(authStateProvider);
    ref.watch(connectivityProvider);
    final s = await _load();
    // Re-arm local reminders from fresh state (fire-and-forget, never blocks UI).
    unawaited(_syncReminders(s));
    // Capture a daily progress snapshot per active goal (fire-and-forget).
    unawaited(_captureDailySnapshots(s));
    return s;
  }

  // ── Momentum snapshots ──────────────────────────────────────────────────────

  /// Records one progress snapshot per active goal per day. Cheap and enough
  /// to build velocity/projection trends (see goal_analytics.dart). Skips goals
  /// that already have a snapshot for today.
  Future<void> _captureDailySnapshots(PlanningState s) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;
    final userId = session.user.id;
    final db = ref.read(appDatabaseProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayKeyMs = today.millisecondsSinceEpoch;
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

    for (final goal in s.activeGoals) {
      // Only capture for goals the current user owns (avoid duplicate rows from
      // multiple collaborators racing on a shared goal).
      if (goal.userId != userId) continue;
      try {
        if (await db.hasGoalSnapshotForDay(goal.id, dayKeyMs)) continue;

        final id = _uuid.v4();
        final snapshot = GoalProgressSnapshot(
          id: id,
          goalId: goal.id,
          userId: userId,
          progress: goalProgress(goal),
          completedTasks: goal.completedTasks,
          totalTasks: goal.totalTasks,
          capturedAt: now,
        );

        await db.upsertGoalSnapshot(LocalGoalProgressSnapshotsCompanion(
          id: Value(id),
          goalId: Value(goal.id),
          userId: Value(userId),
          progress: Value(snapshot.progress),
          completedTasks: Value(snapshot.completedTasks),
          totalTasks: Value(snapshot.totalTasks),
          capturedAtMs: Value(now.millisecondsSinceEpoch),
          dayKeyMs: Value(dayKeyMs),
          synced: const Value(false),
        ));

        if (isOnline) {
          try {
            await client
                .from('goal_progress_snapshots')
                .insert(snapshot.toInsertJson());
            await db.markGoalSnapshotSynced(id);
          } catch (_) {
            await db.enqueueSyncOp(
                'insert_goal_snapshot', jsonEncode(snapshot.toInsertJson()));
          }
        } else {
          await db.enqueueSyncOp(
              'insert_goal_snapshot', jsonEncode(snapshot.toInsertJson()));
        }
      } catch (_) {
        // Snapshots are best-effort; never let them break module load.
      }
    }
  }

  // ── Notification helpers ────────────────────────────────────────────────────

  ReminderSettings? get _reminderSettings =>
      ref.read(reminderSettingsProvider).valueOrNull;

  NotificationService get _notif => ref.read(notificationServiceProvider);

  bool get _remindersOn => _reminderSettings?.remindersEnabled ?? false;

  void _syncNotifOffset() {
    final off = ref.read(userTimezoneProvider).valueOrNull;
    if (off != null) _notif.setOffset(off);
  }

  Goal? _goalById(String id) {
    final goals = state.valueOrNull?.goals;
    if (goals == null) return null;
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<void> _scheduleTaskNotif(String goalId, PlanningTask task) async {
    if (!_remindersOn || task.isCompleted || task.dueDate == null) return;
    final goal = _goalById(goalId);
    if (goal == null || goal.status != 'active') return;
    _syncNotifOffset();
    await _notif.scheduleTaskReminder(
      taskId: task.id,
      taskName: task.name,
      goalName: goal.name,
      dueDate: task.dueDate!,
      remindBeforeDays: goal.settings.remindBeforeDeadlineDays,
    );
  }

  Future<void> _cancelTaskNotif(String taskId) async {
    if (!_remindersOn) return;
    await _notif.cancelTaskReminder(taskId);
  }

  Future<void> _cancelGoalNotifs(Goal goal) async {
    if (!_remindersOn) return;
    await _notif.cancelGoalDeadline(goal.id);
    await _notif.cancelStagnationNudge(goal.id);
    for (final sg in _allSubGoals(goal.subGoals)) {
      for (final t in sg.tasks) {
        await _notif.cancelTaskReminder(t.id);
      }
    }
    for (final m in goal.milestones) {
      await _notif.cancelMilestoneReminder(m.id);
    }
  }

  // Bulk (re)scheduler — idempotent thanks to deterministic notification ids.
  Future<void> _syncReminders(PlanningState s) async {
    ReminderSettings settings;
    try {
      settings = await ref.read(reminderSettingsProvider.future);
    } catch (_) {
      return;
    }
    if (!settings.remindersEnabled) return;
    _syncNotifOffset();

    final svc = _notif;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var scheduled = 0;
    const cap = 50; // stay well under the iOS 64 pending-notification limit
    var todayCount = 0;

    for (final goal in s.activeGoals) {
      final remindDays = goal.settings.remindBeforeDeadlineDays;

      if (goal.deadline != null && goal.deadline!.isAfter(now)) {
        await svc.scheduleGoalDeadline(
          goalId: goal.id,
          goalName: goal.name,
          deadline: goal.deadline!,
          progressPercent: goalProgress(goal).round(),
          remindBeforeDays: remindDays,
        );
      }

      for (final sg in _allSubGoals(goal.subGoals)) {
        for (final t in sg.tasks) {
          if (t.isCompleted || t.dueDate == null) continue;
          final due = DateTime(
              t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
          if (due == today) todayCount++;
          if (scheduled < cap && !due.isBefore(today)) {
            await svc.scheduleTaskReminder(
              taskId: t.id,
              taskName: t.name,
              goalName: goal.name,
              dueDate: t.dueDate!,
              remindBeforeDays: remindDays,
            );
            scheduled++;
          }
        }
      }

      for (final m in goal.milestones) {
        if (m.isCompleted || m.targetDate == null) continue;
        if (scheduled < cap) {
          await svc.scheduleMilestoneReminder(
            milestoneId: m.id,
            milestoneName: m.name,
            goalName: goal.name,
            targetDate: m.targetDate!,
            remindBeforeDays: remindDays,
          );
          scheduled++;
        }
      }

      if (settings.stagnationNudge && isGoalFatigued(goal)) {
        // Nudge tomorrow morning; deterministic id avoids duplicates.
        await svc.scheduleStagnationNudge(
          goalId: goal.id,
          goalName: goal.name,
          when: DateTime(now.year, now.month, now.day + 1, 10, 0),
        );
      }
    }

    if (settings.dailyDigestEnabled) {
      await svc.scheduleDailyDigest(
        hour: settings.digestHour,
        minute: settings.digestMinute,
        taskCount: todayCount,
      );
    } else {
      await svc.cancelDailyDigest();
    }

    // Stage 9: weekly review ritual reminder.
    if (settings.weeklyReviewEnabled) {
      await svc.scheduleWeeklyReview(
        weekday: settings.reviewWeekday,
        hour: settings.reviewHour,
        minute: settings.reviewMinute,
      );
    } else {
      await svc.cancelWeeklyReview();
    }
  }

  /// Public entry-point so the UI can re-arm reminders after the user toggles
  /// settings or grants permission.
  Future<void> resyncReminders() async {
    final s = state.valueOrNull;
    if (s != null) await _syncReminders(s);
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<PlanningState> _load() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return PlanningState.empty;

    final userId = session.user.id;
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);

    if (isOnline) {
      try {
        final raw = await client
            .from('goals')
            .select(
                '*, sub_goals(*, planning_tasks(*)), milestones(*), goal_habit_links(*), goal_collaborators(*)')
            .neq('status', 'deleted')
            .order('created_at');

        final goals = (raw as List)
            .map((r) => Goal.fromJson(r as Map<String, dynamic>))
            .toList();

        // Batch-load owner profiles for shared goals
        final sharedOwnerIds = goals
            .where((g) => g.userId != userId)
            .map((g) => g.userId)
            .toSet()
            .toList();
        final ownerProfileMap = <String, PublicProfile>{};
        if (sharedOwnerIds.isNotEmpty) {
          final profiles = await client
              .from('profiles')
              .select('id, username, avatar_url, equipped_frame_id, '
                  'equipped_background_id, equipped_stat_style_id, total_xp, design_points')
              .inFilter('id', sharedOwnerIds);
          for (final p in profiles) {
            ownerProfileMap[p['id'] as String] = PublicProfile.fromJson(p);
          }
        }

        // Batch-load collaborator profiles
        final collabUserIds = goals
            .expand((g) => g.collaborators.map((c) => c.userId))
            .toSet()
            .toList();
        final collabProfileMap = <String, PublicProfile>{};
        if (collabUserIds.isNotEmpty) {
          final profiles = await client
              .from('profiles')
              .select('id, username, avatar_url, equipped_frame_id, '
                  'equipped_background_id, equipped_stat_style_id, total_xp, design_points')
              .inFilter('id', collabUserIds);
          for (final p in profiles) {
            collabProfileMap[p['id'] as String] = PublicProfile.fromJson(p);
          }
        }

        // Attach profiles to goals
        final enrichedGoals = goals.map((g) {
          final isShared = g.userId != userId;
          final enrichedCollabs = g.collaborators.map((c) =>
              c.copyWith(profile: collabProfileMap[c.userId])).toList();
          return g.copyWith(
            collaborators: enrichedCollabs,
            ownerProfile: isShared ? ownerProfileMap[g.userId] : null,
          );
        }).toList();

        await _mirrorToLocal(db, enrichedGoals, userId);
        await _mirrorDependencies(
            client, db, enrichedGoals.map((g) => g.id).toList());
        await db.cleanupRemovedSharedGoals(
            enrichedGoals.map((g) => g.id).toSet());
        return _loadFromLocal(db, userId, enrichedGoals);
      } catch (_) {
        // fall through to local
      }
    }

    return _loadFromLocal(db, userId);
  }

  /// Mirrors server task dependencies into the local store (Stage 8). Synced
  /// rows are replaced by the server's truth; unsynced local inserts are kept
  /// for the sync queue to push.
  Future<void> _mirrorDependencies(
      SupabaseClient client, AppDatabase db, List<String> goalIds) async {
    if (goalIds.isEmpty) return;
    try {
      final raw = await client
          .from('task_dependencies')
          .select('task_id, depends_on_task_id, goal_id')
          .inFilter('goal_id', goalIds);
      final serverKeys = <String>{};
      for (final r in (raw as List)) {
        final m = r as Map<String, dynamic>;
        final taskId = m['task_id'] as String;
        final dependsOn = m['depends_on_task_id'] as String;
        serverKeys.add('$taskId|$dependsOn');
        await db.upsertTaskDependency(LocalTaskDependenciesCompanion(
          taskId: Value(taskId),
          dependsOnTaskId: Value(dependsOn),
          goalId: Value(m['goal_id'] as String),
          synced: const Value(true),
          createdAtMs: Value(DateTime.now().millisecondsSinceEpoch),
        ));
      }
      // Drop synced-but-gone rows (deleted on another device).
      final local = await db.dependenciesForGoals(goalIds);
      for (final d in local) {
        if (d.synced && !serverKeys.contains('${d.taskId}|${d.dependsOnTaskId}')) {
          await db.deleteTaskDependency(d.taskId, d.dependsOnTaskId);
        }
      }
    } catch (_) {
      // best-effort; local data remains usable
    }
  }

  Future<void> _mirrorToLocal(AppDatabase db, List<Goal> goals, String userId) async {
    // Collect IDs that have local unsynced changes — server data must not overwrite them.
    final unsyncedIds = await db.unsyncedPlanningIds();

    for (final g in goals) {
      final isShared = g.userId != userId;
      // Determine current user's role in this shared goal
      String? myRole;
      if (isShared) {
        final myCollab = g.collaborators
            .where((c) => c.userId == userId && c.status == 'accepted')
            .firstOrNull;
        myRole = myCollab?.role;
      }

      if (!unsyncedIds.contains(g.id) || isShared) {
        await db.upsertGoal(LocalGoalsCompanion(
          id: Value(g.id),
          userId: Value(g.userId),
          name: Value(g.name),
          description: Value(g.description),
          deadlineMs: Value(g.deadline?.millisecondsSinceEpoch),
          priority: Value(g.priority),
          status: Value(g.status),
          colorHex: Value(g.colorHex),
          progress: Value(g.progress),
          synced: const Value(true),
          createdAtMs: Value(g.createdAt.millisecondsSinceEpoch),
          settingsJson: Value(jsonEncode(g.settings.toJson())),
          isPinned: Value(g.isPinned),
          isShared: Value(isShared),
          myRole: Value(myRole),
        ));
      }
      for (final sg in _allSubGoals(g.subGoals)) {
        if (!unsyncedIds.contains(sg.id)) {
          await db.upsertSubGoal(LocalSubGoalsCompanion(
            id: Value(sg.id),
            goalId: Value(sg.goalId),
            parentSubGoalId: Value(sg.parentSubGoalId),
            name: Value(sg.name),
            isCompleted: Value(sg.isCompleted),
            orderIndex: Value(sg.orderIndex),
            synced: const Value(true),
            createdAtMs: Value(sg.createdAt.millisecondsSinceEpoch),
          ));
        }
        for (final t in sg.tasks) {
          if (!unsyncedIds.contains(t.id)) {
            await db.upsertPlanningTask(LocalPlanningTasksCompanion(
              id: Value(t.id),
              subGoalId: Value(t.subGoalId),
              userId: Value(t.userId),
              name: Value(t.name),
              weight: Value(t.weight),
              isCompleted: Value(t.isCompleted),
              completedAtMs: Value(t.completedAt?.millisecondsSinceEpoch),
              dueDateMs: Value(t.dueDate?.millisecondsSinceEpoch),
              orderIndex: Value(t.orderIndex),
              recurrenceRule: Value(t.recurrenceRule),
              recurrenceUntilMs: Value(t.recurrenceUntil?.millisecondsSinceEpoch),
              recurrenceParentId: Value(t.recurrenceParentId),
              synced: const Value(true),
              createdAtMs: Value(t.createdAt.millisecondsSinceEpoch),
            ));
          }
        }
      }
      for (final m in g.milestones) {
        if (!unsyncedIds.contains(m.id)) {
          await db.upsertMilestone(LocalMilestonesCompanion(
            id: Value(m.id),
            goalId: Value(m.goalId),
            name: Value(m.name),
            targetDateMs: Value(m.targetDate?.millisecondsSinceEpoch),
            isCompleted: Value(m.isCompleted),
            synced: const Value(true),
            createdAtMs: Value(m.createdAt.millisecondsSinceEpoch),
            kind: Value(m.kind),
            unit: Value(m.unit),
            startValue: Value(m.startValue),
            targetValue: Value(m.targetValue),
            currentValue: Value(m.currentValue),
            direction: Value(m.direction),
          ));
        }
      }
      for (final l in g.habitLinks) {
        if (!unsyncedIds.contains(l.id)) {
          await db.upsertGoalHabitLink(LocalGoalHabitLinksCompanion(
            id: Value(l.id),
            goalId: Value(l.goalId),
            habitId: Value(l.habitId),
            synced: const Value(true),
            createdAtMs: Value(l.createdAt.millisecondsSinceEpoch),
          ));
        }
      }
    }
  }

  Future<PlanningState> _loadFromLocal(AppDatabase db, String userId,
      [List<Goal>? serverGoals]) async {
    // Build a lookup map from server data for collaborator/owner enrichment
    final serverMap = serverGoals != null
        ? {for (final g in serverGoals) g.id: g}
        : <String, Goal>{};
    final rawGoals = await db.goalsForUser(userId);
    if (rawGoals.isEmpty) return PlanningState(goals: const []);

    // Batch-load every related table in one query each (6 total), then group in
    // memory — replaces the previous N+1 cascade (1 + goals + sub-goals queries).
    final goalIds = [for (final g in rawGoals) g.id];
    final rawSubsAll = await db.subGoalsForGoals(goalIds);
    final subGoalIds = [for (final s in rawSubsAll) s.id];
    final rawTasksAll = await db.tasksForSubGoals(subGoalIds);
    final rawMsAll = await db.milestonesForGoals(goalIds);
    final rawLinksAll = await db.habitLinksForGoals(goalIds);
    final positionsByGoal = await db.mapPositionsForGoals(goalIds);
    final rawDeps = await db.dependenciesForGoals(goalIds);

    // taskId → ids it depends on (Stage 8).
    final dependsByTask = <String, List<String>>{};
    for (final d in rawDeps) {
      (dependsByTask[d.taskId] ??= []).add(d.dependsOnTaskId);
    }

    // Group by foreign key.
    final tasksBySubGoal = <String, List<PlanningTask>>{};
    for (final rt in rawTasksAll) {
      (tasksBySubGoal[rt.subGoalId] ??= []).add(PlanningTask(
        id: rt.id,
        subGoalId: rt.subGoalId,
        userId: rt.userId,
        name: rt.name,
        weight: rt.weight,
        isCompleted: rt.isCompleted,
        orderIndex: rt.orderIndex,
        completedAt: rt.completedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(rt.completedAtMs!)
            : null,
        dueDate: rt.dueDateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(rt.dueDateMs!)
            : null,
        recurrenceRule: rt.recurrenceRule,
        recurrenceUntil: rt.recurrenceUntilMs != null
            ? DateTime.fromMillisecondsSinceEpoch(rt.recurrenceUntilMs!)
            : null,
        recurrenceParentId: rt.recurrenceParentId,
        dependsOn: dependsByTask[rt.id] ?? const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(rt.createdAtMs),
      ));
    }

    final subsByGoal = <String, List<SubGoal>>{};
    for (final rs in rawSubsAll) {
      (subsByGoal[rs.goalId] ??= []).add(SubGoal(
        id: rs.id,
        goalId: rs.goalId,
        parentSubGoalId: rs.parentSubGoalId,
        name: rs.name,
        isCompleted: rs.isCompleted,
        orderIndex: rs.orderIndex,
        tasks: tasksBySubGoal[rs.id] ?? const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(rs.createdAtMs),
      ));
    }

    final msByGoal = <String, List<Milestone>>{};
    for (final rm in rawMsAll) {
      (msByGoal[rm.goalId] ??= []).add(Milestone(
        id: rm.id,
        goalId: rm.goalId,
        name: rm.name,
        targetDate: rm.targetDateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(rm.targetDateMs!)
            : null,
        isCompleted: rm.isCompleted,
        createdAt: DateTime.fromMillisecondsSinceEpoch(rm.createdAtMs),
        kind: rm.kind,
        unit: rm.unit,
        startValue: rm.startValue,
        targetValue: rm.targetValue,
        currentValue: rm.currentValue,
        direction: rm.direction,
      ));
    }

    final linksByGoal = <String, List<GoalHabitLink>>{};
    for (final rl in rawLinksAll) {
      (linksByGoal[rl.goalId] ??= []).add(GoalHabitLink(
        id: rl.id,
        goalId: rl.goalId,
        habitId: rl.habitId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(rl.createdAtMs),
      ));
    }

    final goals = <Goal>[];
    for (final rg in rawGoals) {
      goals.add(Goal(
        id: rg.id,
        userId: rg.userId,
        name: rg.name,
        description: rg.description,
        deadline: rg.deadlineMs != null
            ? DateTime.fromMillisecondsSinceEpoch(rg.deadlineMs!)
            : null,
        priority: rg.priority,
        status: rg.status,
        colorHex: rg.colorHex,
        progress: rg.progress,
        subGoals: buildSubGoalTree(subsByGoal[rg.id] ?? const []),
        milestones: msByGoal[rg.id] ?? const [],
        habitLinks: linksByGoal[rg.id] ?? const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(rg.createdAtMs),
        settings: rg.settingsJson != null
            ? GoalSettings.fromJson(
                jsonDecode(rg.settingsJson!) as Map<String, dynamic>)
            : GoalSettings.defaults,
        mapPositions: positionsByGoal[rg.id] ?? const {},
        isPinned: rg.isPinned,
        // Restore collaborators and ownerProfile from server data if available
        collaborators: serverMap[rg.id]?.collaborators ?? const [],
        ownerProfile: serverMap[rg.id]?.ownerProfile,
      ));
    }

    return PlanningState(goals: goals);
  }

  // ── Add Goal ──────────────────────────────────────────────────────────────

  Future<String?> addGoal({
    required String name,
    String? description,
    DateTime? deadline,
    int priority = 2,
    String colorHex = '#5AADA0',
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return null;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id = _uuid.v4();
    final userId = session.user.id;

    final newGoal = Goal(
      id: id,
      userId: userId,
      name: name,
      description: description,
      deadline: deadline,
      priority: priority,
      status: 'active',
      colorHex: colorHex,
      progress: 0,
      subGoals: const [],
      milestones: const [],
      habitLinks: const [],
      createdAt: now,
    );

    // Optimistic update
    final current = state.valueOrNull ?? PlanningState.empty;
    state = AsyncData(current.copyWith(goals: [...current.goals, newGoal]));

    await db.upsertGoal(LocalGoalsCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      description: Value(description),
      deadlineMs: Value(deadline?.millisecondsSinceEpoch),
      priority: Value(priority),
      status: const Value('active'),
      colorHex: Value(colorHex),
      progress: const Value(0),
      synced: const Value(false),
      createdAtMs: Value(now.millisecondsSinceEpoch),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final payload = jsonEncode(newGoal.toInsertJson());

    if (isOnline) {
      try {
        await client.from('goals').insert(newGoal.toInsertJson());
        await db.updateGoal(id, const LocalGoalsCompanion(synced: Value(true)));
        return id;
      } catch (_) {}
    }
    await db.enqueueSyncOp('insert_goal', payload);
    return id;
  }

  // ── Delete Goal ───────────────────────────────────────────────────────────

  Future<void> deleteGoal(String id) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final goal = _goalById(id);
    if (goal != null) await _cancelGoalNotifs(goal);

    state = AsyncData(
        current.copyWith(goals: current.goals.where((g) => g.id != id).toList()));

    await Future.wait([
      db.deleteGoalLocally(id),
      db.deleteMapPositionsForGoal(id),
    ]);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('goals').delete().eq('id', id);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('delete_goal', jsonEncode({'id': id}));
  }

  // ── Update Goal Status ────────────────────────────────────────────────────

  Future<MissionMedal?> updateGoalStatus(String id, String newStatus) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return null;

    final goal = current.goals.where((g) => g.id == id).firstOrNull;

    final idx = current.goals.indexWhere((g) => g.id == id);
    if (idx != -1) {
      final next = [...current.goals];
      next[idx] = next[idx].copyWith(status: newStatus);
      state = AsyncData(current.copyWith(goals: next));
    }

    await db.updateGoal(id, LocalGoalsCompanion(
        status: Value(newStatus), synced: const Value(false)));

    // Cancel all reminders when a goal leaves the active board.
    if (newStatus != 'active' && goal != null) {
      await _cancelGoalNotifs(goal);
    }

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

    MissionMedal? medal;
    if (newStatus == 'completed' && goal != null && session != null) {
      // Compute stats
      int totalWeight = 0;
      for (final sg in _allSubGoals(goal.subGoals)) {
        for (final t in sg.tasks) totalWeight += t.weight;
      }
      final durationDays =
          DateTime.now().difference(goal.createdAt).inDays;

      // Determine level
      final level = (totalWeight > 40 && durationDays > 30)
          ? 3
          : (totalWeight >= 15 || durationDays > 14)
              ? 2
              : 1;

      // Category-based DP
      final dp = switch (goal.settings.category) {
        GoalCategory.project    => 50,
        GoalCategory.learning   => 40,
        GoalCategory.health     => 35,
        GoalCategory.discipline => 30,
        GoalCategory.lifestyle  => 25,
        null                    => 20,
      };

      final xpBonus = medalXpBonus(level);
      await _awardXp(goalCompletionBaseXp(goal) + xpBonus, dp);

      medal = MissionMedal(
        id: _uuid.v4(),
        userId: session.user.id,
        goalId: id,
        goalName: goal.name,
        category: goal.settings.category,
        level: level,
        name: medalName(goal.settings.category, level),
        earnedAt: DateTime.now(),
        totalTaskWeight: totalWeight,
        durationDays: durationDays,
      );

      await db.upsertMedalLocally(LocalMissionMedalsCompanion(
        id: Value(medal.id),
        userId: Value(medal.userId),
        goalId: Value(medal.goalId),
        goalName: Value(medal.goalName),
        category: Value(medal.category?.name ?? 'none'),
        level: Value(medal.level),
        name: Value(medal.name),
        earnedAtMs: Value(medal.earnedAt.millisecondsSinceEpoch),
        totalTaskWeight: Value(medal.totalTaskWeight),
        durationDays: Value(medal.durationDays),
        synced: const Value(false),
      ));

      if (isOnline) {
        try {
          await client
              .from('mission_medals')
              .insert(medal.toInsertMap());
          await db.markMedalSynced(medal.id);
        } catch (_) {
          await db.enqueueSyncOp(
              'award_mission_medal', jsonEncode(medal.toInsertMap()));
        }
      } else {
        await db.enqueueSyncOp(
            'award_mission_medal', jsonEncode(medal.toInsertMap()));
      }
    } else if (newStatus == 'completed' && goal != null) {
      await _awardXp(goalCompletionBaseXp(goal), 20);
    }

    if (isOnline) {
      try {
        await client
            .from('goals')
            .update({'status': newStatus}).eq('id', id);
        await db.updateGoal(id,
            const LocalGoalsCompanion(synced: Value(true)));
        return medal;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'update_goal_status', jsonEncode({'id': id, 'status': newStatus}));
    return medal;
  }

  // ── State helper ──────────────────────────────────────────────────────────

  void _updateGoalInState(String goalId, Goal Function(Goal) updater) {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.goals.indexWhere((g) => g.id == goalId);
    if (idx == -1) return;
    final next = [...current.goals];
    next[idx] = updater(next[idx]);
    state = AsyncData(current.copyWith(goals: next));
  }

  // ── Add Sub-goal ──────────────────────────────────────────────────────────

  Future<void> addSubGoal(String goalId, String name,
      {String? parentSubGoalId}) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id = _uuid.v4();

    final currentGoal = state.valueOrNull?.goals
        .where((g) => g.id == goalId).firstOrNull;
    final orderIndex = parentSubGoalId == null
        ? (currentGoal?.subGoals.length ?? 0)
        : (_allSubGoals(currentGoal?.subGoals ?? [])
              .where((s) => s.id == parentSubGoalId)
              .firstOrNull?.children.length ?? 0);

    final newSg = SubGoal(
      id: id,
      goalId: goalId,
      parentSubGoalId: parentSubGoalId,
      name: name,
      isCompleted: false,
      orderIndex: orderIndex,
      tasks: const [],
      createdAt: now,
    );

    _updateGoalInState(goalId, (g) {
      if (parentSubGoalId == null) {
        return g.copyWith(subGoals: [...g.subGoals, newSg]);
      }
      return g.copyWith(
          subGoals: _addChildToSubGoal(g.subGoals, parentSubGoalId, newSg));
    });

    await db.upsertSubGoal(LocalSubGoalsCompanion(
      id: Value(id),
      goalId: Value(goalId),
      parentSubGoalId: Value(parentSubGoalId),
      name: Value(name),
      orderIndex: Value(orderIndex),
      synced: const Value(false),
      createdAtMs: Value(now.millisecondsSinceEpoch),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('sub_goals').insert({
          'id': id,
          'goal_id': goalId,
          if (parentSubGoalId != null) 'parent_sub_goal_id': parentSubGoalId,
          'name': name,
          'order_index': orderIndex,
          'created_at': now.toIso8601String(),
        });
        await db.updateSubGoal(id,
            const LocalSubGoalsCompanion(synced: Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'insert_sub_goal',
        jsonEncode({
          'id': id,
          'goal_id': goalId,
          if (parentSubGoalId != null) 'parent_sub_goal_id': parentSubGoalId,
          'name': name,
          'order_index': orderIndex,
        }));
  }

  // ── Delete Sub-goal ───────────────────────────────────────────────────────

  Future<void> deleteSubGoal(String subGoalId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(goalId,
        (g) => g.copyWith(
            subGoals: _removeSubGoalFromTree(g.subGoals, subGoalId)));

    await db.deleteSubGoalLocally(subGoalId);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('sub_goals').delete().eq('id', subGoalId);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'delete_sub_goal', jsonEncode({'id': subGoalId, 'goal_id': goalId}));
  }

  // ── Complete Sub-goal ─────────────────────────────────────────────────────

  Future<void> completeSubGoal(String subGoalId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(
            g.subGoals, subGoalId, (sg) => sg.copyWith(isCompleted: true))));

    await db.updateSubGoal(subGoalId, LocalSubGoalsCompanion(
        isCompleted: const Value(true),
        synced: const Value(false)));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    var syncedToServer = false;
    if (isOnline) {
      try {
        await client
            .from('sub_goals')
            .update({'is_completed': true}).eq('id', subGoalId);
        await db.updateSubGoal(subGoalId,
            const LocalSubGoalsCompanion(synced: Value(true)));
        syncedToServer = true;
      } catch (e) {
        debugPrint('SiE Planning: complete_sub_goal online failed — $e');
      }
    }
    if (!syncedToServer) {
      await db.enqueueSyncOp('complete_sub_goal',
          jsonEncode({'id': subGoalId, 'goal_id': goalId}));
    }
    await _awardXp(150, 0);
  }

  // ── Add Task ──────────────────────────────────────────────────────────────

  Future<void> addTask({
    required String goalId,
    required String subGoalId,
    required String name,
    int weight = 1,
    DateTime? dueDate,
    String? recurrenceRule,
    DateTime? recurrenceUntil,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final now = DateTime.now();
    final id = _uuid.v4();
    final userId = session.user.id;

    final currentSg = _allSubGoals(
            state.valueOrNull?.goals.expand((g) => g.subGoals).toList() ?? [])
        .where((s) => s.id == subGoalId).firstOrNull;
    final taskOrderIndex = currentSg?.tasks.length ?? 0;

    final newTask = PlanningTask(
      id: id,
      subGoalId: subGoalId,
      userId: userId,
      name: name,
      weight: weight,
      isCompleted: false,
      orderIndex: taskOrderIndex,
      completedAt: null,
      dueDate: dueDate,
      recurrenceRule: recurrenceRule,
      recurrenceUntil: recurrenceUntil,
      createdAt: now,
    );

    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
            (sg) => sg.copyWith(tasks: [...sg.tasks, newTask]))));

    await _scheduleTaskNotif(goalId, newTask);
    await _persistTaskInsert(newTask);
  }

  /// Shared insert persistence (local upsert → online insert → offline queue).
  /// Used by [addTask] and by recurrence spawning in [toggleTask].
  Future<void> _persistTaskInsert(PlanningTask t) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    await db.upsertPlanningTask(LocalPlanningTasksCompanion(
      id: Value(t.id),
      subGoalId: Value(t.subGoalId),
      userId: Value(t.userId),
      name: Value(t.name),
      weight: Value(t.weight),
      isCompleted: Value(t.isCompleted),
      orderIndex: Value(t.orderIndex),
      dueDateMs: Value(t.dueDate?.millisecondsSinceEpoch),
      recurrenceRule: Value(t.recurrenceRule),
      recurrenceUntilMs: Value(t.recurrenceUntil?.millisecondsSinceEpoch),
      recurrenceParentId: Value(t.recurrenceParentId),
      synced: const Value(false),
      createdAtMs: Value(t.createdAt.millisecondsSinceEpoch),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('planning_tasks').insert({
          'id': t.id,
          'sub_goal_id': t.subGoalId,
          'user_id': t.userId,
          'name': t.name,
          'weight': t.weight,
          'order_index': t.orderIndex,
          'due_date': t.dueDate?.toIso8601String(),
          'recurrence_rule': t.recurrenceRule,
          'recurrence_until': t.recurrenceUntil?.toIso8601String(),
          'recurrence_parent_id': t.recurrenceParentId,
          'created_at': t.createdAt.toIso8601String(),
        });
        await db.updatePlanningTask(t.id,
            const LocalPlanningTasksCompanion(synced: Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'insert_task',
        jsonEncode({
          'id': t.id,
          'sub_goal_id': t.subGoalId,
          'user_id': t.userId,
          'name': t.name,
          'weight': t.weight,
          'order_index': t.orderIndex,
          'due_date': t.dueDate?.toIso8601String(),
          'recurrence_rule': t.recurrenceRule,
          'recurrence_until': t.recurrenceUntil?.toIso8601String(),
          'recurrence_parent_id': t.recurrenceParentId,
        }));
  }

  // ── Delete Task ───────────────────────────────────────────────────────────

  Future<void> deleteTask(
      String taskId, String subGoalId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
            (sg) => sg.copyWith(
                tasks: sg.tasks.where((t) => t.id != taskId).toList()))));

    await db.deletePlanningTaskLocally(taskId);
    await _cancelTaskNotif(taskId);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('planning_tasks').delete().eq('id', taskId);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('delete_task',
        jsonEncode({'id': taskId, 'sub_goal_id': subGoalId, 'goal_id': goalId}));
  }

  // ── Toggle Task ───────────────────────────────────────────────────────────

  Future<void> toggleTask(
      String taskId, String subGoalId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final goal = current.goals.firstWhere((g) => g.id == goalId,
        orElse: () => throw StateError('goal not found'));
    final sg = _allSubGoals(goal.subGoals).firstWhere((s) => s.id == subGoalId,
        orElse: () => throw StateError('subgoal not found'));
    final task = sg.tasks.firstWhere((t) => t.id == taskId,
        orElse: () => throw StateError('task not found'));

    final nowCompleted = !task.isCompleted;
    final completedAt = nowCompleted ? DateTime.now() : null;

    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
            (s) => s.copyWith(
                tasks: s.tasks
                    .map((t) => t.id == taskId
                        ? t.copyWith(
                            isCompleted: nowCompleted,
                            completedAt: completedAt)
                        : t)
                    .toList()))));

    await db.updatePlanningTask(taskId, LocalPlanningTasksCompanion(
      isCompleted: Value(nowCompleted),
      completedAtMs: Value(completedAt?.millisecondsSinceEpoch),
      synced: const Value(false),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    var syncedToServer = false;
    if (isOnline) {
      try {
        await client.from('planning_tasks').update({
          'is_completed': nowCompleted,
          'completed_at': completedAt?.toIso8601String(),
        }).eq('id', taskId);
        await db.updatePlanningTask(taskId,
            LocalPlanningTasksCompanion(synced: const Value(true)));
        syncedToServer = true;
      } catch (e) {
        debugPrint('SiE Planning: toggle_task online failed — $e');
      }
    }
    if (!syncedToServer) {
      await db.enqueueSyncOp(
          'toggle_task',
          jsonEncode({
            'id': taskId,
            'is_completed': nowCompleted,
            'completed_at': completedAt?.toIso8601String(),
          }));
    }

    if (nowCompleted) await _awardXp(taskXp(task.weight), 0);
    await _touchGoalUpdatedAt(goalId);
    if (nowCompleted) await _autoCompleteParents(goalId);

    // Reminder lifecycle: cancel when done, re-arm when re-opened.
    if (nowCompleted) {
      await _cancelTaskNotif(taskId);
    } else {
      await _scheduleTaskNotif(goalId, task.copyWith(isCompleted: false));
    }

    // Recurrence: completing a recurring task spawns its next instance.
    if (nowCompleted && task.isRecurring) {
      await _spawnNextRecurrence(goalId, subGoalId, task);
    }
  }

  /// Creates the next instance of a recurring task when the current one is done.
  Future<void> _spawnNextRecurrence(
      String goalId, String subGoalId, PlanningTask task) async {
    final rule = task.recurrenceRule;
    if (rule == null || rule.isEmpty) return;
    final from = task.dueDate ?? DateTime.now();
    final next = nextOccurrence(rule, from);
    if (task.recurrenceUntil != null && next.isAfter(task.recurrenceUntil!)) {
      return; // series finished
    }

    final sg = _allSubGoals(_goalById(goalId)?.subGoals ?? const [])
        .where((s) => s.id == subGoalId)
        .firstOrNull;
    final orderIndex = sg?.tasks.length ?? 0;

    final instance = PlanningTask(
      id: _uuid.v4(),
      subGoalId: subGoalId,
      userId: task.userId,
      name: task.name,
      weight: task.weight,
      isCompleted: false,
      orderIndex: orderIndex,
      dueDate: next,
      recurrenceRule: rule,
      recurrenceUntil: task.recurrenceUntil,
      recurrenceParentId: task.recurrenceParentId ?? task.id,
      createdAt: DateTime.now(),
    );

    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
            (s) => s.copyWith(tasks: [...s.tasks, instance]))));

    await _persistTaskInsert(instance);
    await _scheduleTaskNotif(goalId, instance);
  }

  /// Stops a recurrence series — current instance stays, no more are spawned.
  Future<void> endRecurrence(
      String taskId, String subGoalId, String goalId) async {
    final db = ref.read(appDatabaseProvider);
    final client = Supabase.instance.client;

    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
            (s) => s.copyWith(
                tasks: s.tasks
                    .map((t) =>
                        t.id == taskId ? t.copyWith(recurrenceRule: null) : t)
                    .toList()))));

    await db.updatePlanningTask(taskId, const LocalPlanningTasksCompanion(
      recurrenceRule: Value(null),
      synced: Value(false),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    var synced = false;
    if (isOnline) {
      try {
        await client
            .from('planning_tasks')
            .update({'recurrence_rule': null}).eq('id', taskId);
        await db.updatePlanningTask(taskId,
            const LocalPlanningTasksCompanion(synced: Value(true)));
        synced = true;
      } catch (e) {
        debugPrint('SiE Planning: end_recurrence online failed — $e');
      }
    }
    if (!synced) {
      await db.enqueueSyncOp('end_recurrence', jsonEncode({'id': taskId}));
    }
  }

  // ── Task Dependencies (Stage 8) ─────────────────────────────────────────────

  /// Adds a "[taskId] depends on [dependsOnTaskId]" edge within one goal.
  /// Returns a result so the UI can explain a rejection (cycle / duplicate /
  /// invalid). Validates against cycles with a client-side DFS.
  Future<DependencyResult> addDependency(
      String goalId, String taskId, String dependsOnTaskId) async {
    if (taskId == dependsOnTaskId) return DependencyResult.invalid;
    final goal = _goalById(goalId);
    if (goal == null) return DependencyResult.invalid;

    final byId = tasksById(goal);
    // Both tasks must belong to this goal (no cross-goal deps in MVP).
    if (!byId.containsKey(taskId) || !byId.containsKey(dependsOnTaskId)) {
      return DependencyResult.invalid;
    }
    final task = byId[taskId]!;
    if (task.dependsOn.contains(dependsOnTaskId)) {
      return DependencyResult.duplicate;
    }

    // Cycle check over current adjacency (taskId → its dependsOn).
    final adjacency = <String, List<String>>{
      for (final t in byId.values) t.id: List<String>.from(t.dependsOn),
    };
    if (wouldCreateDependencyCycle(taskId, dependsOnTaskId, adjacency)) {
      return DependencyResult.cycle;
    }

    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return DependencyResult.invalid;
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();

    // Optimistic state update.
    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, task.subGoalId,
            (s) => s.copyWith(
                tasks: s.tasks
                    .map((t) => t.id == taskId
                        ? t.copyWith(
                            dependsOn: [...t.dependsOn, dependsOnTaskId])
                        : t)
                    .toList()))));

    await db.upsertTaskDependency(LocalTaskDependenciesCompanion(
      taskId: Value(taskId),
      dependsOnTaskId: Value(dependsOnTaskId),
      goalId: Value(goalId),
      synced: const Value(false),
      createdAtMs: Value(now.millisecondsSinceEpoch),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('task_dependencies').insert({
          'task_id': taskId,
          'depends_on_task_id': dependsOnTaskId,
          'goal_id': goalId,
          'user_id': session.user.id,
        });
        await db.markTaskDependencySynced(taskId, dependsOnTaskId);
        return DependencyResult.ok;
      } catch (_) {}
    }
    await db.enqueueSyncOp('insert_dependency', jsonEncode({
      'task_id': taskId,
      'depends_on_task_id': dependsOnTaskId,
      'goal_id': goalId,
      'user_id': session.user.id,
    }));
    return DependencyResult.ok;
  }

  Future<void> removeDependency(
      String goalId, String taskId, String dependsOnTaskId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final goal = _goalById(goalId);
    final subGoalId =
        goal == null ? null : tasksById(goal)[taskId]?.subGoalId;

    if (subGoalId != null) {
      _updateGoalInState(goalId, (g) => g.copyWith(
          subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
              (s) => s.copyWith(
                  tasks: s.tasks
                      .map((t) => t.id == taskId
                          ? t.copyWith(
                              dependsOn: t.dependsOn
                                  .where((d) => d != dependsOnTaskId)
                                  .toList())
                          : t)
                      .toList()))));
    }

    await db.deleteTaskDependency(taskId, dependsOnTaskId);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client
            .from('task_dependencies')
            .delete()
            .eq('task_id', taskId)
            .eq('depends_on_task_id', dependsOnTaskId);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('delete_dependency', jsonEncode({
      'task_id': taskId,
      'depends_on_task_id': dependsOnTaskId,
    }));
  }

  // Reschedule a task's due date (or clear it when [newDueDate] is null).
  // Used by the War Room agenda ("Отложить на завтра" / "Снять дедлайн").
  Future<void> rescheduleTask(
      String taskId, String subGoalId, String goalId, DateTime? newDueDate) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    // Locate the task within the goal's sub-goal tree.
    final goal = current.goals.firstWhere((g) => g.id == goalId,
        orElse: () => throw StateError('goal not found'));
    final sg = _allSubGoals(goal.subGoals).firstWhere((s) => s.id == subGoalId,
        orElse: () => throw StateError('subgoal not found'));
    final task = sg.tasks.firstWhere((t) => t.id == taskId,
        orElse: () => throw StateError('task not found'));

    // ── Optimistic update ──
    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
            (s) => s.copyWith(
                tasks: s.tasks
                    .map((t) => t.id == taskId
                        ? t.copyWith(dueDate: newDueDate)
                        : t)
                    .toList()))));

    // ── Local DB upsert ──
    await db.updatePlanningTask(taskId, LocalPlanningTasksCompanion(
      dueDateMs: Value(newDueDate?.millisecondsSinceEpoch),
      synced: const Value(false),
    ));

    // ── Try online sync ──
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    var syncedToServer = false;
    if (isOnline) {
      try {
        await client.from('planning_tasks').update({
          'due_date': newDueDate?.toIso8601String(),
        }).eq('id', taskId);
        await db.updatePlanningTask(taskId,
            const LocalPlanningTasksCompanion(synced: Value(true)));
        syncedToServer = true;
      } catch (e) {
        debugPrint('SiE Planning: reschedule_task online failed — $e');
      }
    }

    // ── Fallback to offline queue ──
    if (!syncedToServer) {
      await db.enqueueSyncOp(
          'reschedule_task',
          jsonEncode({
            'id': taskId,
            'due_date': newDueDate?.toIso8601String(),
          }));
    }

    // Re-arm the reminder for the new date (or clear it).
    await _cancelTaskNotif(taskId);
    if (newDueDate != null) {
      await _scheduleTaskNotif(
          goalId, task.copyWith(dueDate: newDueDate, isCompleted: false));
    }

    await _touchGoalUpdatedAt(goalId);
  }

  // Auto-complete sub-goals and goal when all children/tasks are done.
  Future<void> _autoCompleteParents(String goalId) async {
    bool anyChange = true;
    while (anyChange) {
      anyChange = false;
      // Read fresh state on every iteration so already-completed sub-goals
      // are visible and the loop terminates correctly.
      final current = state.valueOrNull;
      if (current == null) return;
      final updatedGoal = current.goals.firstWhere((g) => g.id == goalId,
          orElse: () => throw StateError('goal not found'));
      for (final sg in _allSubGoals(updatedGoal.subGoals)) {
        if (sg.isCompleted) continue;
        final allTasksDone = sg.tasks.isNotEmpty && sg.tasks.every((t) => t.isCompleted);
        final allChildrenDone = sg.children.isNotEmpty
            ? sg.children.every((c) => c.isCompleted)
            : true;
        final hasContent = sg.tasks.isNotEmpty || sg.children.isNotEmpty;
        if (hasContent && allTasksDone && allChildrenDone) {
          await completeSubGoal(sg.id, goalId);
          anyChange = true;
          break;
        }
      }
    }
  }

  // ── Add Milestone ─────────────────────────────────────────────────────────

  Future<void> addMilestone(
    String goalId,
    String name, {
    DateTime? targetDate,
    String kind = 'binary',
    String? unit,
    double? startValue,
    double? targetValue,
    String direction = 'up',
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id = _uuid.v4();

    final newMs = Milestone(
      id: id,
      goalId: goalId,
      name: name,
      targetDate: targetDate,
      isCompleted: false,
      createdAt: now,
      kind: kind,
      unit: unit,
      startValue: startValue,
      targetValue: targetValue,
      currentValue: startValue, // start at the beginning
      direction: direction,
    );

    _updateGoalInState(goalId,
        (g) => g.copyWith(milestones: [...g.milestones, newMs]));

    if (_remindersOn && targetDate != null) {
      final goal = _goalById(goalId);
      if (goal != null && goal.status == 'active') {
        _syncNotifOffset();
        await _notif.scheduleMilestoneReminder(
          milestoneId: id,
          milestoneName: name,
          goalName: goal.name,
          targetDate: targetDate,
          remindBeforeDays: goal.settings.remindBeforeDeadlineDays,
        );
      }
    }

    await db.upsertMilestone(LocalMilestonesCompanion(
      id: Value(id),
      goalId: Value(goalId),
      name: Value(name),
      targetDateMs: Value(targetDate?.millisecondsSinceEpoch),
      synced: const Value(false),
      createdAtMs: Value(now.millisecondsSinceEpoch),
      kind: Value(kind),
      unit: Value(unit),
      startValue: Value(startValue),
      targetValue: Value(targetValue),
      currentValue: Value(startValue),
      direction: Value(direction),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('milestones').insert({
          'id': id,
          'goal_id': goalId,
          'name': name,
          if (targetDate != null) 'target_date': targetDate.toIso8601String(),
          'kind': kind,
          if (unit != null) 'unit': unit,
          if (startValue != null) 'start_value': startValue,
          if (targetValue != null) 'target_value': targetValue,
          if (startValue != null) 'current_value': startValue,
          'direction': direction,
          'created_at': now.toIso8601String(),
        });
        await db.upsertMilestone(
            LocalMilestonesCompanion(id: Value(id), synced: const Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('insert_milestone', jsonEncode({
      'id': id,
      'goal_id': goalId,
      'name': name,
      if (targetDate != null) 'target_date': targetDate.toIso8601String(),
      'kind': kind,
      if (unit != null) 'unit': unit,
      if (startValue != null) 'start_value': startValue,
      if (targetValue != null) 'target_value': targetValue,
      if (startValue != null) 'current_value': startValue,
      'direction': direction,
    }));
  }

  // ── Add Milestone Log ─────────────────────────────────────────────────────

  Future<void> addMilestoneLog(
      String milestoneId, String goalId, double value) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id = _uuid.v4();
    final userId = session.user.id;

    // Capture milestone state before optimistic update to check completion.
    final msBefore = _goalById(goalId)
        ?.milestones
        .where((m) => m.id == milestoneId)
        .firstOrNull;

    // Optimistic: update currentValue in state.
    _updateGoalInState(goalId, (g) => g.copyWith(
        milestones: g.milestones
            .map((m) =>
                m.id == milestoneId ? m.copyWith(currentValue: value) : m)
            .toList()));

    // Invalidate logs provider so sparkline/history reloads.
    ref.invalidate(milestoneLogsProvider(milestoneId));

    // Persist log locally.
    await db.insertMilestoneLog(LocalMilestoneLogsCompanion(
      id: Value(id),
      milestoneId: Value(milestoneId),
      userId: Value(userId),
      value: Value(value),
      recordedAtMs: Value(now.millisecondsSinceEpoch),
      synced: const Value(false),
    ));
    await db.updateMilestoneCurrentValue(milestoneId, value);

    // Auto-complete when threshold is crossed.
    if (msBefore != null && !msBefore.isCompleted) {
      final updated = msBefore.copyWith(currentValue: value);
      if (_isMetricAchieved(updated)) {
        await completeMilestone(milestoneId, goalId);
      }
    }

    // Online sync.
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('milestone_logs').insert({
          'id': id,
          'milestone_id': milestoneId,
          'user_id': userId,
          'value': value,
          'recorded_at': now.toIso8601String(),
        });
        await client
            .from('milestones')
            .update({'current_value': value}).eq('id', milestoneId);
        await db.insertMilestoneLog(LocalMilestoneLogsCompanion(
            id: Value(id), synced: const Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('insert_milestone_log', jsonEncode({
      'id': id,
      'milestone_id': milestoneId,
      'user_id': userId,
      'value': value,
      'recorded_at': now.toIso8601String(),
    }));
  }

  // ── Delete Milestone Log ──────────────────────────────────────────────────

  Future<void> deleteMilestoneLog(
      String logId, String milestoneId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    await db.deleteMilestoneLogLocally(logId);
    ref.invalidate(milestoneLogsProvider(milestoneId));

    // Recalculate currentValue from the remaining logs.
    final remaining = await db.logsForMilestone(milestoneId);
    final latest = remaining.isEmpty
        ? null
        : remaining.reduce(
            (a, b) => a.recordedAtMs >= b.recordedAtMs ? a : b);
    final newCurrent = latest?.value;

    await db.updateMilestoneCurrentValue(milestoneId, newCurrent);
    _updateGoalInState(goalId, (g) => g.copyWith(
        milestones: g.milestones
            .map((m) => m.id == milestoneId
                ? m.copyWith(currentValue: newCurrent)
                : m)
            .toList()));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('milestone_logs').delete().eq('id', logId);
        await client.from('milestones').update(
            {'current_value': newCurrent}).eq('id', milestoneId);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('delete_milestone_log',
        jsonEncode({'id': logId, 'milestone_id': milestoneId}));
  }

  // ── Delete Milestone ──────────────────────────────────────────────────────

  Future<void> deleteMilestone(String milestoneId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(goalId,
        (g) => g.copyWith(
            milestones:
                g.milestones.where((m) => m.id != milestoneId).toList()));

    await db.deleteMilestoneLocally(milestoneId);
    if (_remindersOn) await _notif.cancelMilestoneReminder(milestoneId);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('milestones').delete().eq('id', milestoneId);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('delete_milestone',
        jsonEncode({'id': milestoneId, 'goal_id': goalId}));
  }

  // ── Complete Milestone ────────────────────────────────────────────────────

  Future<void> completeMilestone(String milestoneId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(
        goalId,
        (g) => g.copyWith(
            milestones: g.milestones
                .map((m) =>
                    m.id == milestoneId ? m.copyWith(isCompleted: true) : m)
                .toList()));

    await db.upsertMilestone(LocalMilestonesCompanion(
        id: Value(milestoneId),
        isCompleted: const Value(true),
        synced: const Value(false)));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    var syncedToServer = false;
    if (isOnline) {
      try {
        await client
            .from('milestones')
            .update({'is_completed': true}).eq('id', milestoneId);
        await db.upsertMilestone(LocalMilestonesCompanion(
            id: Value(milestoneId), synced: const Value(true)));
        syncedToServer = true;
      } catch (e) {
        debugPrint('SiE Planning: complete_milestone online failed — $e');
      }
    }
    if (!syncedToServer) {
      await db.enqueueSyncOp('complete_milestone',
          jsonEncode({'id': milestoneId, 'goal_id': goalId}));
    }
    if (_remindersOn) await _notif.cancelMilestoneReminder(milestoneId);
    await _awardXp(500, 0);
  }

  // ── Link Habit ────────────────────────────────────────────────────────────

  Future<void> linkHabit(String goalId, String habitId) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id = _uuid.v4();

    final newLink = GoalHabitLink(
        id: id, goalId: goalId, habitId: habitId, createdAt: now);

    _updateGoalInState(goalId,
        (g) => g.copyWith(habitLinks: [...g.habitLinks, newLink]));

    await db.upsertGoalHabitLink(LocalGoalHabitLinksCompanion(
      id: Value(id),
      goalId: Value(goalId),
      habitId: Value(habitId),
      synced: const Value(false),
      createdAtMs: Value(now.millisecondsSinceEpoch),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('goal_habit_links').insert({
          'id': id,
          'goal_id': goalId,
          'habit_id': habitId,
          'created_at': now.toIso8601String(),
        });
        await db.upsertGoalHabitLink(LocalGoalHabitLinksCompanion(
            id: Value(id), synced: const Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('insert_habit_link',
        jsonEncode({'id': id, 'goal_id': goalId, 'habit_id': habitId}));
  }

  // ── Unlink Habit ──────────────────────────────────────────────────────────

  Future<void> unlinkHabit(String linkId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(goalId,
        (g) => g.copyWith(
            habitLinks: g.habitLinks.where((l) => l.id != linkId).toList()));

    await db.deleteGoalHabitLinkLocally(linkId);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('goal_habit_links').delete().eq('id', linkId);
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('delete_habit_link',
        jsonEncode({'id': linkId, 'goal_id': goalId}));
  }

  // ── Strategic Advice ──────────────────────────────────────────────────────

  List<String> getStrategicAdvice(Goal g) {
    if (g.status != 'active') return const [];
    final advice = <String>[];
    final now = DateTime.now();

    final ref_ = g.updatedAt ?? g.createdAt;
    final daysSinceUpdate = now.difference(ref_).inDays;
    if (daysSinceUpdate >= 7 && g.progress < 100.0) {
      advice.add(
          'Цель не обновлялась $daysSinceUpdate дн. Попробуй выполнить хотя бы одну задачу.');
    }

    int overdue = 0;
    for (final sg in _allSubGoals(g.subGoals)) {
      for (final t in sg.tasks) {
        if (!t.isCompleted && t.dueDate != null && now.isAfter(t.dueDate!)) {
          overdue++;
        }
      }
    }
    if (overdue >= 2) {
      advice.add(
          '$overdue задач просрочено. Расставь приоритеты или перенеси дедлайны.');
    }

    if (g.deadline != null) {
      final daysLeft = g.deadline!.difference(now).inDays;
      if (daysLeft >= 0 && daysLeft <= 14 && g.progress < 50.0) {
        advice.add(
            'До дедлайна $daysLeft дн., а прогресс только ${g.progress.round()}%. Нужно ускориться!');
      }
    }

    return advice;
  }

  // ── XP helper ─────────────────────────────────────────────────────────────

  Future<void> _awardXp(int xp, int dp) async {
    try {
      await ref.read(userProfileProvider.notifier).applyLocalXpDelta(xp, dp);
    } catch (_) {}
  }

  // ── Touch updatedAt ───────────────────────────────────────────────────────

  Future<void> _touchGoalUpdatedAt(String goalId) async {
    final now = DateTime.now();
    _updateGoalInState(goalId, (g) => g.copyWith(updatedAt: now));
    final db = ref.read(appDatabaseProvider);
    await db.updateGoal(goalId, LocalGoalsCompanion(
      updatedAtMs: Value(now.millisecondsSinceEpoch),
      synced: const Value(false),
    ));
  }

  // ── Reorder Sub-goals ─────────────────────────────────────────────────────

  Future<void> reorderSubGoals(
      String goalId, String? parentId, List<String> newOrder) async {
    _updateGoalInState(goalId, (g) {
      final flat = _allSubGoals(g.subGoals).map((sg) {
        final idx = newOrder.indexOf(sg.id);
        return idx >= 0 ? sg.copyWith(orderIndex: idx) : sg;
      }).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return g.copyWith(subGoals: buildSubGoalTree(flat));
    });
    final db = ref.read(appDatabaseProvider);
    // Single transaction for all local order writes (was N separate UPDATEs).
    await db.batchUpdateSubGoalOrder(newOrder);
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    // Push order updates concurrently rather than one sequential RTT per row.
    await Future.wait([
      for (int i = 0; i < newOrder.length; i++)
        () async {
          if (isOnline) {
            try {
              await Supabase.instance.client
                  .from('sub_goals')
                  .update({'order_index': i}).eq('id', newOrder[i]);
              await db.updateSubGoal(newOrder[i],
                  const LocalSubGoalsCompanion(synced: Value(true)));
              return;
            } catch (_) {}
          }
          await db.enqueueSyncOp('reorder_sub_goal',
              jsonEncode({'id': newOrder[i], 'order_index': i}));
        }(),
    ]);
  }

  // ── Reorder Tasks ──────────────────────────────────────────────────────────

  Future<void> reorderTasks(
      String goalId, String subGoalId, List<String> newOrder) async {
    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId, (sg) {
          final reordered = List.of(sg.tasks)
            ..sort((a, b) =>
                newOrder.indexOf(a.id).compareTo(newOrder.indexOf(b.id)));
          return sg.copyWith(
              tasks: reordered.indexed
                  .map((e) => e.$2.copyWith(orderIndex: e.$1))
                  .toList());
        })));
    final db = ref.read(appDatabaseProvider);
    await db.batchUpdateTaskOrder(newOrder);
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    await Future.wait([
      for (int i = 0; i < newOrder.length; i++)
        () async {
          if (isOnline) {
            try {
              await Supabase.instance.client
                  .from('planning_tasks')
                  .update({'order_index': i}).eq('id', newOrder[i]);
              await db.updatePlanningTask(newOrder[i],
                  const LocalPlanningTasksCompanion(synced: Value(true)));
              return;
            } catch (_) {}
          }
          await db.enqueueSyncOp('reorder_task',
              jsonEncode({'id': newOrder[i], 'order_index': i}));
        }(),
    ]);
  }

  // ── Update Goal Settings ──────────────────────────────────────────────────

  Future<void> updateGoalSettings(String goalId, GoalSettings settings) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(goalId, (g) => g.copyWith(settings: settings));

    await db.updateGoalSettings(goalId, jsonEncode(settings.toJson()));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client
            .from('goals')
            .update({'settings': settings.toJson()}).eq('id', goalId);
        await db.updateGoal(
            goalId, const LocalGoalsCompanion(synced: Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('update_goal_settings',
        jsonEncode({'id': goalId, 'settings': settings.toJson()}));
  }

  // ── Pin Goal ──────────────────────────────────────────────────────────────

  Future<void> toggleGoalPin(String goalId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final goal = current.goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null) return;
    final newPinned = !goal.isPinned;

    // Optimistic update + re-sort (pinned first, then by createdAt)
    final updated = current.goals
        .map((g) => g.id == goalId ? g.copyWith(isPinned: newPinned) : g)
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    state = AsyncData(current.copyWith(goals: updated));

    final db = ref.read(appDatabaseProvider);
    await db.updateGoal(goalId, LocalGoalsCompanion(
        isPinned: Value(newPinned), synced: const Value(false)));

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('goals')
            .update({'is_pinned': newPinned})
            .eq('id', goalId)
            .eq('user_id', userId);
        await db.updateGoal(goalId,
            const LocalGoalsCompanion(synced: Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('update_goal_pin',
        jsonEncode({'id': goalId, 'is_pinned': newPinned}));
  }

  // ── Habit Boost ───────────────────────────────────────────────────────────

  Future<void> applyHabitBoost(String goalId, double boost,
      {String? habitId}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final goal = current.goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null || goal.status != 'active') return;

    double multiplier = 1.0;
    if (habitId != null) {
      final streak =
          ref.read(habitsProvider).valueOrNull?.streaks[habitId] ?? 0;
      multiplier = streak >= 30 ? 2.0 : streak >= 7 ? 1.5 : 1.0;
    }
    final boosted = boost * multiplier;

    final newProgress = (goal.progress + boosted).clamp(0.0, 100.0);
    final now = DateTime.now();
    _updateGoalInState(
        goalId, (g) => g.copyWith(progress: newProgress, updatedAt: now));
    final db = ref.read(appDatabaseProvider);
    await db.updateGoal(goalId, LocalGoalsCompanion(
      progress: Value(newProgress),
      updatedAtMs: Value(now.millisecondsSinceEpoch),
      synced: const Value(false),
    ));
    await db.enqueueSyncOp(
        'update_goal_progress', jsonEncode({'id': goalId, 'progress': newProgress}));
  }

  // ── Move Task (re-parent) ─────────────────────────────────────────────────

  Future<void> moveTask(String taskId, String newSubGoalId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    String? oldSubGoalId;
    PlanningTask? task;
    for (final g in current.goals) {
      for (final sg in _allSubGoals(g.subGoals)) {
        final found = sg.tasks.where((t) => t.id == taskId).firstOrNull;
        if (found != null) {
          task = found;
          oldSubGoalId = sg.id;
          break;
        }
      }
      if (task != null) break;
    }
    if (task == null || oldSubGoalId == null || oldSubGoalId == newSubGoalId) {
      return;
    }

    final movedTask = task.copyWith(subGoalId: newSubGoalId);
    state = AsyncData(current.copyWith(
      goals: current.goals.map((g) {
        final hasOld = _allSubGoals(g.subGoals).any((s) => s.id == oldSubGoalId);
        if (!hasOld) return g;
        // Remove from old sub-goal
        var updated = _updateSubGoalInTree(g.subGoals, oldSubGoalId!, (s) =>
            s.copyWith(tasks: s.tasks.where((t) => t.id != taskId).toList()));
        // Add to new sub-goal
        updated = _updateSubGoalInTree(updated, newSubGoalId, (s) =>
            s.copyWith(tasks: [...s.tasks, movedTask]));
        return g.copyWith(subGoals: updated);
      }).toList(),
    ));

    final db = ref.read(appDatabaseProvider);
    await db.updatePlanningTask(taskId, LocalPlanningTasksCompanion(
      subGoalId: Value(newSubGoalId),
      synced: const Value(false),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('planning_tasks')
            .update({'sub_goal_id': newSubGoalId}).eq('id', taskId);
        await db.updatePlanningTask(taskId,
            const LocalPlanningTasksCompanion(synced: Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'move_task', jsonEncode({'id': taskId, 'sub_goal_id': newSubGoalId}));
  }

  // ── Move SubGoal (re-parent) ──────────────────────────────────────────────

  Future<void> moveSubGoal(String subGoalId, String newParentSubGoalId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    SubGoal? sg;
    String? oldParentId;
    for (final g in current.goals) {
      for (final s in _allSubGoals(g.subGoals)) {
        if (s.id == subGoalId) {
          sg = s;
          oldParentId = s.parentSubGoalId;
          break;
        }
      }
      if (sg != null) break;
    }
    if (sg == null || oldParentId == newParentSubGoalId) return;

    final moved = sg.copyWith(parentSubGoalId: newParentSubGoalId);
    state = AsyncData(current.copyWith(
      goals: current.goals.map((g) {
        final allIds = _allSubGoals(g.subGoals).map((s) => s.id).toSet();
        if (!allIds.contains(subGoalId)) return g;
        List<SubGoal> updated;
        if (oldParentId == null) {
          updated = g.subGoals.where((s) => s.id != subGoalId).toList();
        } else {
          updated = _updateSubGoalInTree(g.subGoals, oldParentId!, (s) =>
              s.copyWith(children: s.children.where((c) => c.id != subGoalId).toList()));
        }
        updated = _updateSubGoalInTree(updated, newParentSubGoalId, (s) =>
            s.copyWith(children: [...s.children, moved]));
        return g.copyWith(subGoals: updated);
      }).toList(),
    ));

    final db = ref.read(appDatabaseProvider);
    await db.updateSubGoal(subGoalId, LocalSubGoalsCompanion(
      parentSubGoalId: Value(newParentSubGoalId),
      synced: const Value(false),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('sub_goals')
            .update({'parent_sub_goal_id': newParentSubGoalId}).eq('id', subGoalId);
        await db.updateSubGoal(subGoalId,
            const LocalSubGoalsCompanion(synced: Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'move_sub_goal', jsonEncode({'id': subGoalId, 'parent_sub_goal_id': newParentSubGoalId}));
  }

  // ── Unparent SubGoal (move up one level) ─────────────────────────────────

  Future<void> unparentSubGoal(String subGoalId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    SubGoal? sg;
    String? goalId;
    for (final g in current.goals) {
      for (final s in _allSubGoals(g.subGoals)) {
        if (s.id == subGoalId) {
          sg = s;
          goalId = g.id;
          break;
        }
      }
      if (sg != null) break;
    }
    if (sg == null || sg.parentSubGoalId == null) return;

    final oldParentId = sg.parentSubGoalId!;
    // Determine grandparent (the new parent after moving up)
    String? grandParentId;
    for (final g in current.goals) {
      for (final s in _allSubGoals(g.subGoals)) {
        if (s.id == oldParentId) { grandParentId = s.parentSubGoalId; break; }
      }
      if (grandParentId != null) break;
    }

    final moved = sg.copyWith(parentSubGoalId: grandParentId);
    state = AsyncData(current.copyWith(
      goals: current.goals.map((g) {
        if (g.id != goalId) return g;
        // Remove from old parent's children
        List<SubGoal> updated = _updateSubGoalInTree(g.subGoals, oldParentId, (s) =>
            s.copyWith(children: s.children.where((c) => c.id != subGoalId).toList()));
        // Add to grandparent or root
        if (grandParentId == null) {
          updated = [...updated, moved];
        } else {
          updated = _updateSubGoalInTree(updated, grandParentId!, (s) =>
              s.copyWith(children: [...s.children, moved]));
        }
        return g.copyWith(subGoals: updated);
      }).toList(),
    ));

    final db = ref.read(appDatabaseProvider);
    await db.updateSubGoal(subGoalId, LocalSubGoalsCompanion(
      parentSubGoalId: Value(grandParentId),
      synced: const Value(false),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .from('sub_goals')
            .update({'parent_sub_goal_id': grandParentId}).eq('id', subGoalId);
        await db.updateSubGoal(subGoalId,
            const LocalSubGoalsCompanion(synced: Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'move_sub_goal', jsonEncode({'id': subGoalId, 'parent_sub_goal_id': grandParentId}));
  }

  // ── AI Decomposition ─────────────────────────────────────────────────────

  Future<void> applyAiDecomposition(
      String goalId, DecompositionResult result) async {
    for (final sg in result.subGoals) {
      await addSubGoal(goalId, sg.name);
      final goal = state.valueOrNull?.goals
          .where((g) => g.id == goalId)
          .firstOrNull;
      final newSg = goal?.subGoals.lastOrNull;
      if (newSg == null) continue;
      for (final t in sg.tasks) {
        await addTask(
            goalId: goalId, subGoalId: newSg.id, name: t.name, weight: t.weight);
      }
    }
    for (final m in result.milestones) {
      await addMilestone(goalId, m.name);
    }
  }

  // ── Mission Templates ─────────────────────────────────────────────────────

  /// Instantiates a full goal (sub-goals + tasks + milestones) from a saved
  /// [template]. Reuses the existing add* methods so local persistence, online
  /// sync and the offline queue all behave exactly as for manual entry.
  /// Returns the new goal id, or null on failure.
  Future<String?> createGoalFromTemplate(
    MissionTemplate template, {
    required String name,
    DateTime? deadline,
  }) async {
    final goalId = await addGoal(
      name: name,
      deadline: deadline,
      colorHex: template.colorHex,
    );
    if (goalId == null) return null;

    if (template.category != null) {
      await updateGoalSettings(
          goalId, GoalSettings(category: template.category));
    }

    for (final sg in template.structure.subGoals) {
      await _instantiateTemplateSubGoal(goalId, null, sg);
    }
    for (final m in template.structure.milestones) {
      await addMilestone(
        goalId,
        m.name,
        kind: m.kind,
        unit: m.unit,
        startValue: m.startValue,
        targetValue: m.targetValue,
        direction: m.direction,
      );
    }
    return goalId;
  }

  Future<void> _instantiateTemplateSubGoal(
      String goalId, String? parentId, TemplateSubGoal tsg) async {
    await addSubGoal(goalId, tsg.name, parentSubGoalId: parentId);
    // addSubGoal appends optimistically, so the new node is the last child of
    // its parent (or the last root sub-goal).
    final created = parentId == null
        ? _goalById(goalId)?.subGoals.lastOrNull
        : _allSubGoals(_goalById(goalId)?.subGoals ?? const [])
            .where((s) => s.id == parentId)
            .firstOrNull
            ?.children
            .lastOrNull;
    if (created == null) return;

    for (final t in tsg.tasks) {
      await addTask(
          goalId: goalId,
          subGoalId: created.id,
          name: t.name,
          weight: t.weight);
    }
    for (final child in tsg.children) {
      await _instantiateTemplateSubGoal(goalId, created.id, child);
    }
  }

  /// Snapshots a goal's structure (no dates/progress/ids) into a reusable user
  /// template.
  Future<MissionTemplate?> saveGoalAsTemplate(
      String goalId, String name) async {
    final goal = _goalById(goalId);
    if (goal == null) return null;
    final structure = TemplateStructure.fromGoal(goal);
    return ref.read(missionTemplatesProvider.notifier).createTemplate(
          name: name,
          description: goal.description,
          category: goal.settings.category,
          colorHex: goal.colorHex,
          structure: structure,
        );
  }

  // ── Save map positions ────────────────────────────────────────────────────

  Future<void> saveMapPositions(String goalId, Map<String, Offset> positions) async {
    _updateGoalInState(goalId, (g) => g.copyWith(mapPositions: positions));

    // Row-level upsert — no JSON encoding; only this goal's rows are touched.
    final db = ref.read(appDatabaseProvider);
    await db.upsertMapPositionsBatch(goalId, positions);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        final posJson = positionsToJson(positions);
        await Supabase.instance.client
            .from('goals')
            .update({'map_positions': posJson}).eq('id', goalId);
        await db.updateGoal(goalId, const LocalGoalsCompanion(synced: Value(true)));
        return;
      } catch (_) {}
    }
    // Offline: enqueue sync op with JSON payload for later upload.
    final posJson = positionsToJson(positions);
    final heavy = positions.length > _kPositionsComputeThreshold;
    final encoded = heavy
        ? await compute(_encodeJson, {'id': goalId, 'map_positions': posJson})
        : jsonEncode({'id': goalId, 'map_positions': posJson});
    await db.enqueueSyncOp('save_map_positions', encoded);
  }
}
