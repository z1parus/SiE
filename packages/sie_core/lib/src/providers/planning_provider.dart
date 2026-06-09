import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/planning.dart';
import '../models/mission_medal.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';
import 'habits_provider.dart';
import 'user_profile_provider.dart';

const _uuid = Uuid();

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
    // Collect IDs that have local unsynced changes — server data must not overwrite them.
    final unsyncedIds = await db.unsyncedPlanningIds();

    for (final g in goals) {
      if (!unsyncedIds.contains(g.id)) {
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
        subGoals: buildSubGoalTree(subGoals),
        milestones: milestones,
        habitLinks: links,
        createdAt: DateTime.fromMillisecondsSinceEpoch(rg.createdAtMs),
        settings: rg.settingsJson != null
            ? GoalSettings.fromJson(
                jsonDecode(rg.settingsJson!) as Map<String, dynamic>)
            : GoalSettings.defaults,
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
        await db.updateGoal(id, const LocalGoalsCompanion(synced: Value(true)));
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

  Future<MissionMedal?> updateGoalStatus(String id, String newStatus) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final db = ref.read(appDatabaseProvider);
    final current = state.valueOrNull;
    if (current == null) return null;

    final goal = current.goals.where((g) => g.id == id).firstOrNull;

    final updated = current.goals
        .map((g) => g.id == id ? g.copyWith(status: newStatus) : g)
        .toList();
    state = AsyncData(current.copyWith(goals: updated));

    await db.updateGoal(id, LocalGoalsCompanion(
        status: Value(newStatus), synced: const Value(false)));

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
      await _awardXp(2000 + xpBonus, dp);

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
      await _awardXp(2000, 20);
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
    state = AsyncData(current.copyWith(
      goals: current.goals
          .map((g) => g.id == goalId ? updater(g) : g)
          .toList(),
    ));
  }

  // ── Add Sub-goal ──────────────────────────────────────────────────────────

  Future<void> addSubGoal(String goalId, String name,
      {int orderIndex = 0, String? parentSubGoalId}) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final id = _uuid.v4();

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

    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
            (sg) => sg.copyWith(tasks: [...sg.tasks, newTask]))));

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
        await db.updatePlanningTask(id,
            LocalPlanningTasksCompanion(synced: const Value(true)));
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

    _updateGoalInState(goalId, (g) => g.copyWith(
        subGoals: _updateSubGoalInTree(g.subGoals, subGoalId,
            (sg) => sg.copyWith(
                tasks: sg.tasks.where((t) => t.id != taskId).toList()))));

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
}
