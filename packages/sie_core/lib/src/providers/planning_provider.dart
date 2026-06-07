import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/planning.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';
import 'user_profile_provider.dart';

const _uuid = Uuid();

final planningProvider =
    AsyncNotifierProvider.autoDispose<PlanningNotifier, PlanningState>(
  PlanningNotifier.new,
);

class PlanningNotifier extends AutoDisposeAsyncNotifier<PlanningState> {
  @override
  Future<PlanningState> build() async {
    ref.watch(authStateProvider);
    ref.watch(connectivityProvider);
    return _load();
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
                '*, sub_goals(*, planning_tasks(*)), milestones(*), goal_habit_links(*)')
            .eq('user_id', userId)
            .neq('status', 'deleted')
            .order('created_at');

        final goals = (raw as List)
            .map((r) => Goal.fromJson(r as Map<String, dynamic>))
            .toList();

        await _mirrorToLocal(db, goals);
        return _loadFromLocal(db, userId);
      } catch (_) {
        // fall through to local
      }
    }

    return _loadFromLocal(db, userId);
  }

  Future<void> _mirrorToLocal(AppDatabase db, List<Goal> goals) async {
    for (final g in goals) {
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
      ));
      for (final sg in g.subGoals) {
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
        for (final t in sg.tasks) {
          await db.upsertPlanningTask(LocalPlanningTasksCompanion(
            id: Value(t.id),
            subGoalId: Value(t.subGoalId),
            userId: Value(t.userId),
            name: Value(t.name),
            weight: Value(t.weight),
            isCompleted: Value(t.isCompleted),
            completedAtMs: Value(t.completedAt?.millisecondsSinceEpoch),
            dueDateMs: Value(t.dueDate?.millisecondsSinceEpoch),
            synced: const Value(true),
            createdAtMs: Value(t.createdAt.millisecondsSinceEpoch),
          ));
        }
      }
      for (final m in g.milestones) {
        await db.upsertMilestone(LocalMilestonesCompanion(
          id: Value(m.id),
          goalId: Value(m.goalId),
          name: Value(m.name),
          targetDateMs: Value(m.targetDate?.millisecondsSinceEpoch),
          isCompleted: Value(m.isCompleted),
          synced: const Value(true),
          createdAtMs: Value(m.createdAt.millisecondsSinceEpoch),
        ));
      }
      for (final l in g.habitLinks) {
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

  Future<PlanningState> _loadFromLocal(AppDatabase db, String userId) async {
    final rawGoals = await db.goalsForUser(userId);
    final goals = <Goal>[];

    for (final rg in rawGoals) {
      final rawSubs = await db.subGoalsForGoal(rg.id);
      final subGoals = <SubGoal>[];

      for (final rs in rawSubs) {
        final rawTasks = await db.tasksForSubGoal(rs.id);
        final tasks = rawTasks
            .map((rt) => PlanningTask(
                  id: rt.id,
                  subGoalId: rt.subGoalId,
                  userId: rt.userId,
                  name: rt.name,
                  weight: rt.weight,
                  isCompleted: rt.isCompleted,
                  completedAt: rt.completedAtMs != null
                      ? DateTime.fromMillisecondsSinceEpoch(rt.completedAtMs!)
                      : null,
                  dueDate: rt.dueDateMs != null
                      ? DateTime.fromMillisecondsSinceEpoch(rt.dueDateMs!)
                      : null,
                  createdAt:
                      DateTime.fromMillisecondsSinceEpoch(rt.createdAtMs),
                ))
            .toList();

        subGoals.add(SubGoal(
          id: rs.id,
          goalId: rs.goalId,
          parentSubGoalId: rs.parentSubGoalId,
          name: rs.name,
          isCompleted: rs.isCompleted,
          orderIndex: rs.orderIndex,
          tasks: tasks,
          createdAt: DateTime.fromMillisecondsSinceEpoch(rs.createdAtMs),
        ));
      }

      final rawMs = await db.milestonesForGoal(rg.id);
      final milestones = rawMs
          .map((rm) => Milestone(
                id: rm.id,
                goalId: rm.goalId,
                name: rm.name,
                targetDate: rm.targetDateMs != null
                    ? DateTime.fromMillisecondsSinceEpoch(rm.targetDateMs!)
                    : null,
                isCompleted: rm.isCompleted,
                createdAt:
                    DateTime.fromMillisecondsSinceEpoch(rm.createdAtMs),
              ))
          .toList();

      final rawLinks = await db.habitLinksForGoal(rg.id);
      final links = rawLinks
          .map((rl) => GoalHabitLink(
                id: rl.id,
                goalId: rl.goalId,
                habitId: rl.habitId,
                createdAt:
                    DateTime.fromMillisecondsSinceEpoch(rl.createdAtMs),
              ))
          .toList();

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
        subGoals: subGoals,
        milestones: milestones,
        habitLinks: links,
        createdAt: DateTime.fromMillisecondsSinceEpoch(rg.createdAtMs),
      ));
    }

    return PlanningState(goals: goals);
  }

  // ── Add Goal ──────────────────────────────────────────────────────────────

  Future<void> addGoal({
    required String name,
    String? description,
    DateTime? deadline,
    int priority = 2,
    String colorHex = '#5AADA0',
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

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
        await db.upsertGoal(
            LocalGoalsCompanion(id: Value(id), synced: const Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('insert_goal', payload);
  }

  // ── Delete Goal ───────────────────────────────────────────────────────────

  Future<void> deleteGoal(String id) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(
        current.copyWith(goals: current.goals.where((g) => g.id != id).toList()));

    await db.deleteGoalLocally(id);

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

  Future<void> updateGoalStatus(String id, String newStatus) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.goals
        .map((g) => g.id == id ? g.copyWith(status: newStatus) : g)
        .toList();
    state = AsyncData(current.copyWith(goals: updated));

    await db.upsertGoal(LocalGoalsCompanion(
        id: Value(id), status: Value(newStatus), synced: const Value(false)));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client
            .from('goals')
            .update({'status': newStatus}).eq('id', id);
        await db.upsertGoal(
            LocalGoalsCompanion(id: Value(id), synced: const Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'update_goal_status', jsonEncode({'id': id, 'status': newStatus}));
  }

  // ── State helper ──────────────────────────────────────────────────────────

  void _updateGoalInState(String goalId, Goal Function(Goal) updater) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      goals: current.goals
          .map((g) => g.id == goalId ? updater(g) : g)
          .toList(),
    ));
  }

  // ── Add Sub-goal ──────────────────────────────────────────────────────────

  Future<void> addSubGoal(String goalId, String name,
      {int orderIndex = 0}) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id = _uuid.v4();

    final newSg = SubGoal(
      id: id,
      goalId: goalId,
      parentSubGoalId: null,
      name: name,
      isCompleted: false,
      orderIndex: orderIndex,
      tasks: const [],
      createdAt: now,
    );

    _updateGoalInState(goalId,
        (g) => g.copyWith(subGoals: [...g.subGoals, newSg]));

    await db.upsertSubGoal(LocalSubGoalsCompanion(
      id: Value(id),
      goalId: Value(goalId),
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
          'name': name,
          'order_index': orderIndex,
          'created_at': now.toIso8601String(),
        });
        await db.upsertSubGoal(
            LocalSubGoalsCompanion(id: Value(id), synced: const Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'insert_sub_goal',
        jsonEncode(
            {'id': id, 'goal_id': goalId, 'name': name, 'order_index': orderIndex}));
  }

  // ── Delete Sub-goal ───────────────────────────────────────────────────────

  Future<void> deleteSubGoal(String subGoalId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(goalId,
        (g) => g.copyWith(
            subGoals: g.subGoals.where((sg) => sg.id != subGoalId).toList()));

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

    _updateGoalInState(
        goalId,
        (g) => g.copyWith(
            subGoals: g.subGoals
                .map((sg) =>
                    sg.id == subGoalId ? sg.copyWith(isCompleted: true) : sg)
                .toList()));

    await db.upsertSubGoal(LocalSubGoalsCompanion(
        id: Value(subGoalId),
        isCompleted: const Value(true),
        synced: const Value(false)));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client
            .from('sub_goals')
            .update({'is_completed': true}).eq('id', subGoalId);
        await db.upsertSubGoal(LocalSubGoalsCompanion(
            id: Value(subGoalId), synced: const Value(true)));
      } catch (_) {}
    } else {
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
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id = _uuid.v4();
    final userId = session.user.id;

    final newTask = PlanningTask(
      id: id,
      subGoalId: subGoalId,
      userId: userId,
      name: name,
      weight: weight,
      isCompleted: false,
      completedAt: null,
      dueDate: dueDate,
      createdAt: now,
    );

    _updateGoalInState(
        goalId,
        (g) => g.copyWith(
            subGoals: g.subGoals
                .map((sg) => sg.id == subGoalId
                    ? sg.copyWith(tasks: [...sg.tasks, newTask])
                    : sg)
                .toList()));

    await db.upsertPlanningTask(LocalPlanningTasksCompanion(
      id: Value(id),
      subGoalId: Value(subGoalId),
      userId: Value(userId),
      name: Value(name),
      weight: Value(weight),
      dueDateMs: Value(dueDate?.millisecondsSinceEpoch),
      synced: const Value(false),
      createdAtMs: Value(now.millisecondsSinceEpoch),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('planning_tasks').insert({
          'id': id,
          'sub_goal_id': subGoalId,
          'user_id': userId,
          'name': name,
          'weight': weight,
          'due_date': dueDate?.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
        await db.upsertPlanningTask(
            LocalPlanningTasksCompanion(id: Value(id), synced: const Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp(
        'insert_task',
        jsonEncode({
          'id': id,
          'sub_goal_id': subGoalId,
          'user_id': userId,
          'name': name,
          'weight': weight,
        }));
  }

  // ── Delete Task ───────────────────────────────────────────────────────────

  Future<void> deleteTask(
      String taskId, String subGoalId, String goalId) async {
    final client = Supabase.instance.client;
    final db = ref.read(appDatabaseProvider);

    _updateGoalInState(
        goalId,
        (g) => g.copyWith(
            subGoals: g.subGoals
                .map((sg) => sg.id == subGoalId
                    ? sg.copyWith(
                        tasks: sg.tasks.where((t) => t.id != taskId).toList())
                    : sg)
                .toList()));

    await db.deletePlanningTaskLocally(taskId);

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
    final sg = goal.subGoals.firstWhere((s) => s.id == subGoalId,
        orElse: () => throw StateError('subgoal not found'));
    final task = sg.tasks.firstWhere((t) => t.id == taskId,
        orElse: () => throw StateError('task not found'));

    final nowCompleted = !task.isCompleted;
    final completedAt = nowCompleted ? DateTime.now() : null;

    _updateGoalInState(
        goalId,
        (g) => g.copyWith(
            subGoals: g.subGoals
                .map((s) => s.id == subGoalId
                    ? s.copyWith(
                        tasks: s.tasks
                            .map((t) => t.id == taskId
                                ? t.copyWith(
                                    isCompleted: nowCompleted,
                                    completedAt: completedAt)
                                : t)
                            .toList())
                    : s)
                .toList()));

    await db.upsertPlanningTask(LocalPlanningTasksCompanion(
      id: Value(taskId),
      isCompleted: Value(nowCompleted),
      completedAtMs: Value(completedAt?.millisecondsSinceEpoch),
      synced: const Value(false),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('planning_tasks').update({
          'is_completed': nowCompleted,
          'completed_at': completedAt?.toIso8601String(),
        }).eq('id', taskId);
        await db.upsertPlanningTask(
            LocalPlanningTasksCompanion(id: Value(taskId), synced: const Value(true)));
      } catch (_) {}
    } else {
      await db.enqueueSyncOp('toggle_task',
          jsonEncode({'id': taskId, 'is_completed': nowCompleted}));
    }

    if (nowCompleted) await _awardXp(taskXp(task.weight), 0);
  }

  // ── Add Milestone ─────────────────────────────────────────────────────────

  Future<void> addMilestone(String goalId, String name,
      {DateTime? targetDate}) async {
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
    );

    _updateGoalInState(goalId,
        (g) => g.copyWith(milestones: [...g.milestones, newMs]));

    await db.upsertMilestone(LocalMilestonesCompanion(
      id: Value(id),
      goalId: Value(goalId),
      name: Value(name),
      targetDateMs: Value(targetDate?.millisecondsSinceEpoch),
      synced: const Value(false),
      createdAtMs: Value(now.millisecondsSinceEpoch),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await client.from('milestones').insert({
          'id': id,
          'goal_id': goalId,
          'name': name,
          'target_date': targetDate?.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
        await db.upsertMilestone(
            LocalMilestonesCompanion(id: Value(id), synced: const Value(true)));
        return;
      } catch (_) {}
    }
    await db.enqueueSyncOp('insert_milestone',
        jsonEncode({'id': id, 'goal_id': goalId, 'name': name}));
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
    if (isOnline) {
      try {
        await client
            .from('milestones')
            .update({'is_completed': true}).eq('id', milestoneId);
        await db.upsertMilestone(LocalMilestonesCompanion(
            id: Value(milestoneId), synced: const Value(true)));
      } catch (_) {}
    } else {
      await db.enqueueSyncOp('complete_milestone',
          jsonEncode({'id': milestoneId, 'goal_id': goalId}));
    }
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

  // ── XP helper ─────────────────────────────────────────────────────────────

  Future<void> _awardXp(int xp, int dp) async {
    try {
      await ref.read(userProfileProvider.notifier).applyLocalXpDelta(xp, dp);
    } catch (_) {}
  }
}
