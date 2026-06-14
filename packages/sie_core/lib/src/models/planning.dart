import 'dart:ui' show Offset;
import 'package:flutter/material.dart';
import 'goal_collaborator.dart';
import 'public_profile.dart';

const _unset = Object();

// ─── GoalCategory ─────────────────────────────────────────────────────────────

enum GoalCategory { learning, health, project, lifestyle, discipline }

// ─── GoalSettings ─────────────────────────────────────────────────────────────

class GoalSettings {
  const GoalSettings({
    this.isFogOfWarEnabled = false,
    this.autoRescheduleTasks = false,
    this.remindBeforeDeadlineDays = 1,
    this.hideCompletedTasks = false,
    this.category,
  });

  final bool isFogOfWarEnabled;
  final bool autoRescheduleTasks;
  final int remindBeforeDeadlineDays;
  final bool hideCompletedTasks;
  final GoalCategory? category;

  static const defaults = GoalSettings();

  GoalSettings copyWith({
    bool? isFogOfWarEnabled,
    bool? autoRescheduleTasks,
    int? remindBeforeDeadlineDays,
    bool? hideCompletedTasks,
    Object? category = _unset,
  }) =>
      GoalSettings(
        isFogOfWarEnabled: isFogOfWarEnabled ?? this.isFogOfWarEnabled,
        autoRescheduleTasks: autoRescheduleTasks ?? this.autoRescheduleTasks,
        remindBeforeDeadlineDays:
            remindBeforeDeadlineDays ?? this.remindBeforeDeadlineDays,
        hideCompletedTasks: hideCompletedTasks ?? this.hideCompletedTasks,
        category: category == _unset ? this.category : category as GoalCategory?,
      );

  factory GoalSettings.fromJson(Map<String, dynamic> j) {
    final catStr = j['category'] as String?;
    final cat = catStr != null
        ? GoalCategory.values.where((e) => e.name == catStr).firstOrNull
        : null;
    return GoalSettings(
      isFogOfWarEnabled: j['is_fog_of_war_enabled'] as bool? ?? false,
      autoRescheduleTasks: j['auto_reschedule_tasks'] as bool? ?? false,
      remindBeforeDeadlineDays:
          (j['remind_before_deadline_days'] as num?)?.toInt() ?? 1,
      hideCompletedTasks: j['hide_completed_tasks'] as bool? ?? false,
      category: cat,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_fog_of_war_enabled': isFogOfWarEnabled,
        'auto_reschedule_tasks': autoRescheduleTasks,
        'remind_before_deadline_days': remindBeforeDeadlineDays,
        'hide_completed_tasks': hideCompletedTasks,
        if (category != null) 'category': category!.name,
      };
}

// ─── Task ─────────────────────────────────────────────────────────────────────

class PlanningTask {
  const PlanningTask({
    required this.id,
    required this.subGoalId,
    required this.userId,
    required this.name,
    required this.weight,
    required this.isCompleted,
    required this.orderIndex,
    required this.createdAt,
    this.completedAt,
    this.dueDate,
    this.recurrenceRule,
    this.recurrenceUntil,
    this.recurrenceParentId,
    this.dependsOn = const [],
  });

  final String id;
  final String subGoalId;
  final String userId;
  final String name;
  final int weight; // 1 / 3 / 5
  final bool isCompleted;
  final int orderIndex;
  final DateTime? completedAt;
  final DateTime? dueDate;
  final DateTime createdAt;
  // Recurrence (stage 3). null = one-shot.
  final String? recurrenceRule; // 'daily'|'weekly:1,3'|'monthly:15'|'every:N'
  final DateTime? recurrenceUntil;
  final String? recurrenceParentId;
  // Dependencies (stage 8): ids of tasks that must be completed before this one.
  final List<String> dependsOn;

  bool get isRecurring => recurrenceRule != null && recurrenceRule!.isNotEmpty;
  bool get hasDependencies => dependsOn.isNotEmpty;

  PlanningTask copyWith({
    String? subGoalId,
    String? name,
    bool? isCompleted,
    int? orderIndex,
    Object? completedAt = _unset,
    Object? dueDate = _unset,
    Object? recurrenceRule = _unset,
    Object? recurrenceUntil = _unset,
    Object? recurrenceParentId = _unset,
    List<String>? dependsOn,
  }) =>
      PlanningTask(
        id: id,
        subGoalId: subGoalId ?? this.subGoalId,
        userId: userId,
        name: name ?? this.name,
        weight: weight,
        isCompleted: isCompleted ?? this.isCompleted,
        orderIndex: orderIndex ?? this.orderIndex,
        completedAt:
            completedAt == _unset ? this.completedAt : completedAt as DateTime?,
        dueDate: dueDate == _unset ? this.dueDate : dueDate as DateTime?,
        recurrenceRule: recurrenceRule == _unset
            ? this.recurrenceRule
            : recurrenceRule as String?,
        recurrenceUntil: recurrenceUntil == _unset
            ? this.recurrenceUntil
            : recurrenceUntil as DateTime?,
        recurrenceParentId: recurrenceParentId == _unset
            ? this.recurrenceParentId
            : recurrenceParentId as String?,
        dependsOn: dependsOn ?? this.dependsOn,
        createdAt: createdAt,
      );

  factory PlanningTask.fromJson(Map<String, dynamic> j) => PlanningTask(
        id: j['id'] as String,
        subGoalId: j['sub_goal_id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        weight: (j['weight'] as num?)?.toInt() ?? 1,
        isCompleted: j['is_completed'] as bool? ?? false,
        orderIndex: (j['order_index'] as num?)?.toInt() ?? 0,
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
        dueDate: j['due_date'] != null
            ? DateTime.parse(j['due_date'] as String)
            : null,
        recurrenceRule: j['recurrence_rule'] as String?,
        recurrenceUntil: j['recurrence_until'] != null
            ? DateTime.parse(j['recurrence_until'] as String)
            : null,
        recurrenceParentId: j['recurrence_parent_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'sub_goal_id': subGoalId,
        'user_id': userId,
        'name': name,
        'weight': weight,
        'is_completed': isCompleted,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
        if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
        if (recurrenceUntil != null)
          'recurrence_until': recurrenceUntil!.toIso8601String(),
        if (recurrenceParentId != null)
          'recurrence_parent_id': recurrenceParentId,
      };
}

// ─── SubGoal ──────────────────────────────────────────────────────────────────

class SubGoal {
  const SubGoal({
    required this.id,
    required this.goalId,
    required this.name,
    required this.isCompleted,
    required this.orderIndex,
    required this.tasks,
    required this.createdAt,
    this.parentSubGoalId,
    this.children = const [],
  });

  final String id;
  final String goalId;
  final String? parentSubGoalId;
  final String name;
  final bool isCompleted;
  final int orderIndex;
  final List<PlanningTask> tasks;
  final List<SubGoal> children;
  final DateTime createdAt;

  SubGoal copyWith({
    String? name,
    bool? isCompleted,
    int? orderIndex,
    List<PlanningTask>? tasks,
    List<SubGoal>? children,
    String? parentSubGoalId,
  }) =>
      SubGoal(
        id: id,
        goalId: goalId,
        parentSubGoalId: parentSubGoalId ?? this.parentSubGoalId,
        name: name ?? this.name,
        isCompleted: isCompleted ?? this.isCompleted,
        orderIndex: orderIndex ?? this.orderIndex,
        tasks: tasks ?? this.tasks,
        children: children ?? this.children,
        createdAt: createdAt,
      );

  factory SubGoal.fromJson(Map<String, dynamic> j) {
    final rawTasks = j['planning_tasks'];
    final tasks = rawTasks is List
        ? rawTasks
            .map((t) => PlanningTask.fromJson(t as Map<String, dynamic>))
            .toList()
        : <PlanningTask>[];
    return SubGoal(
      id: j['id'] as String,
      goalId: j['goal_id'] as String,
      parentSubGoalId: j['parent_sub_goal_id'] as String?,
      name: j['name'] as String,
      isCompleted: j['is_completed'] as bool? ?? false,
      orderIndex: (j['order_index'] as num?)?.toInt() ?? 0,
      tasks: tasks,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

// ─── Milestone ────────────────────────────────────────────────────────────────

class Milestone {
  const Milestone({
    required this.id,
    required this.goalId,
    required this.name,
    required this.isCompleted,
    required this.createdAt,
    this.targetDate,
    this.kind = 'binary',
    this.unit,
    this.startValue,
    this.targetValue,
    this.currentValue,
    this.direction = 'up',
  });

  final String id;
  final String goalId;
  final String name;
  final DateTime? targetDate;
  final bool isCompleted;
  final DateTime createdAt;
  // Stage 4: metric fields
  final String kind;        // 'binary' | 'metric'
  final String? unit;
  final double? startValue;
  final double? targetValue;
  final double? currentValue;
  final String direction;   // 'up' | 'down'

  bool get isMetric => kind == 'metric';

  Milestone copyWith({
    bool? isCompleted,
    Object? currentValue = _unset,
  }) =>
      Milestone(
        id: id,
        goalId: goalId,
        name: name,
        targetDate: targetDate,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
        kind: kind,
        unit: unit,
        startValue: startValue,
        targetValue: targetValue,
        currentValue:
            currentValue == _unset ? this.currentValue : currentValue as double?,
        direction: direction,
      );

  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
        id: j['id'] as String,
        goalId: j['goal_id'] as String,
        name: j['name'] as String,
        targetDate: j['target_date'] != null
            ? DateTime.parse(j['target_date'] as String)
            : null,
        isCompleted: j['is_completed'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        kind: j['kind'] as String? ?? 'binary',
        unit: j['unit'] as String?,
        startValue: (j['start_value'] as num?)?.toDouble(),
        targetValue: (j['target_value'] as num?)?.toDouble(),
        currentValue: (j['current_value'] as num?)?.toDouble(),
        direction: j['direction'] as String? ?? 'up',
      );
}

// ─── MilestoneLog ─────────────────────────────────────────────────────────────

class MilestoneLog {
  const MilestoneLog({
    required this.id,
    required this.milestoneId,
    required this.userId,
    required this.value,
    required this.recordedAt,
  });

  final String id;
  final String milestoneId;
  final String userId;
  final double value;
  final DateTime recordedAt;

  factory MilestoneLog.fromJson(Map<String, dynamic> j) => MilestoneLog(
        id: j['id'] as String,
        milestoneId: j['milestone_id'] as String,
        userId: j['user_id'] as String,
        value: (j['value'] as num).toDouble(),
        recordedAt: DateTime.parse(j['recorded_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'milestone_id': milestoneId,
        'user_id': userId,
        'value': value,
        'recorded_at': recordedAt.toIso8601String(),
      };
}

// ─── GoalHabitLink ────────────────────────────────────────────────────────────

class GoalHabitLink {
  const GoalHabitLink({
    required this.id,
    required this.goalId,
    required this.habitId,
    required this.createdAt,
    this.boostValue = 0.5,
  });

  final String id;
  final String goalId;
  final String habitId;
  final DateTime createdAt;
  final double boostValue;

  factory GoalHabitLink.fromJson(Map<String, dynamic> j) => GoalHabitLink(
        id: j['id'] as String,
        goalId: j['goal_id'] as String,
        habitId: j['habit_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        boostValue: (j['boost_value'] as num?)?.toDouble() ?? 0.5,
      );
}

// ─── Goal ─────────────────────────────────────────────────────────────────────

class Goal {
  const Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.priority,
    required this.status,
    required this.colorHex,
    required this.progress,
    required this.subGoals,
    required this.milestones,
    required this.habitLinks,
    required this.createdAt,
    this.description,
    this.deadline,
    this.updatedAt,
    this.settings = GoalSettings.defaults,
    this.mapPositions = const {},
    this.isPinned = false,
    this.collaborators = const [],
    this.ownerProfile,
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime? deadline;
  final int priority; // 1–4
  final String status; // active/completed/failed/frozen
  final String colorHex;
  final double progress; // 0–100, used when subGoals is empty
  final List<SubGoal> subGoals;
  final List<Milestone> milestones;
  final List<GoalHabitLink> habitLinks;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final GoalSettings settings;
  final Map<String, Offset> mapPositions;
  final bool isPinned;
  final List<GoalCollaborator> collaborators;
  final PublicProfile? ownerProfile; // populated for shared goals

  Color get color =>
      Color(int.parse('0xFF${colorHex.replaceAll('#', '')}'));

  int get completedTasks => _allSubGoals(subGoals).fold(
      0, (s, sg) => s + sg.tasks.where((t) => t.isCompleted).length);
  int get totalTasks =>
      _allSubGoals(subGoals).fold(0, (s, sg) => s + sg.tasks.length);
  int get completedSubGoals =>
      _allSubGoals(subGoals).where((sg) => sg.isCompleted).length;

  int? get daysUntilDeadline =>
      deadline?.difference(DateTime.now()).inDays;
  bool get isOverdue =>
      deadline != null &&
      DateTime.now().isAfter(deadline!) &&
      status == 'active';

  Goal copyWith({
    String? name,
    String? description,
    DateTime? deadline,
    int? priority,
    String? status,
    String? colorHex,
    double? progress,
    List<SubGoal>? subGoals,
    List<Milestone>? milestones,
    List<GoalHabitLink>? habitLinks,
    DateTime? updatedAt,
    GoalSettings? settings,
    Map<String, Offset>? mapPositions,
    bool? isPinned,
    List<GoalCollaborator>? collaborators,
    PublicProfile? ownerProfile,
  }) =>
      Goal(
        id: id,
        userId: userId,
        name: name ?? this.name,
        description: description ?? this.description,
        deadline: deadline ?? this.deadline,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        colorHex: colorHex ?? this.colorHex,
        progress: progress ?? this.progress,
        subGoals: subGoals ?? this.subGoals,
        milestones: milestones ?? this.milestones,
        habitLinks: habitLinks ?? this.habitLinks,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        settings: settings ?? this.settings,
        mapPositions: mapPositions ?? this.mapPositions,
        isPinned: isPinned ?? this.isPinned,
        collaborators: collaborators ?? this.collaborators,
        ownerProfile: ownerProfile ?? this.ownerProfile,
      );

  factory Goal.fromJson(Map<String, dynamic> j) {
    final rawSubs = j['sub_goals'];
    final subs = rawSubs is List
        ? rawSubs
            .map((s) => SubGoal.fromJson(s as Map<String, dynamic>))
            .toList()
        : <SubGoal>[];

    final rawMs = j['milestones'];
    final milestones = rawMs is List
        ? rawMs
            .map((m) => Milestone.fromJson(m as Map<String, dynamic>))
            .toList()
        : <Milestone>[];

    final rawLinks = j['goal_habit_links'];
    final links = rawLinks is List
        ? rawLinks
            .map((l) => GoalHabitLink.fromJson(l as Map<String, dynamic>))
            .toList()
        : <GoalHabitLink>[];

    final rawCollabs = j['goal_collaborators'];
    final collaborators = rawCollabs is List
        ? rawCollabs
            .map((c) => GoalCollaborator.fromJson(c as Map<String, dynamic>))
            .toList()
        : <GoalCollaborator>[];

    return Goal(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      deadline: j['deadline'] != null
          ? DateTime.parse(j['deadline'] as String)
          : null,
      priority: (j['priority'] as num?)?.toInt() ?? 2,
      status: j['status'] as String? ?? 'active',
      colorHex: j['color_hex'] as String? ?? '#5AADA0',
      progress: (j['progress'] as num?)?.toDouble() ?? 0.0,
      subGoals: buildSubGoalTree(subs),
      milestones: milestones,
      habitLinks: links,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: j['updated_at'] != null
          ? DateTime.parse(j['updated_at'] as String)
          : null,
      settings: j['settings'] is Map<String, dynamic>
          ? GoalSettings.fromJson(j['settings'] as Map<String, dynamic>)
          : GoalSettings.defaults,
      mapPositions: positionsFromJson(j['map_positions'] as Map<String, dynamic>?),
      isPinned: j['is_pinned'] as bool? ?? false,
      collaborators: collaborators,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        if (description != null) 'description': description,
        if (deadline != null) 'deadline': deadline!.toIso8601String(),
        'priority': priority,
        'status': status,
        'color_hex': colorHex,
        'progress': progress,
        'settings': settings.toJson(),
        if (mapPositions.isNotEmpty) 'map_positions': positionsToJson(mapPositions),
      };
}

// ─── PlanningState ────────────────────────────────────────────────────────────

class PlanningState {
  PlanningState({required this.goals});

  final List<Goal> goals;

  // Lazily computed once per instance — avoids repeated .where().toList() on each access.
  late final List<Goal> activeGoals =
      goals.where((g) => g.status == 'active').toList();
  late final List<Goal> archivedGoals =
      goals.where((g) => g.status != 'active').toList();

  static final PlanningState empty = PlanningState(goals: const []);

  PlanningState copyWith({List<Goal>? goals}) =>
      PlanningState(goals: goals ?? this.goals);
}

// ─── Helper functions ─────────────────────────────────────────────────────────

// Public flatten of an entire sub-goal tree (used by the agenda aggregator).
List<SubGoal> flattenSubGoals(List<SubGoal> roots) => _allSubGoals(roots);

// Flatten entire sub-goal tree into a list
List<SubGoal> _allSubGoals(List<SubGoal> roots) {
  final result = <SubGoal>[];
  void visit(SubGoal sg) {
    result.add(sg);
    for (final child in sg.children) visit(child);
  }
  for (final sg in roots) visit(sg);
  return result;
}

// Build recursive tree from a flat list using parentSubGoalId
SubGoal _buildNode(String id, Map<String, SubGoal> byId, List<SubGoal> flat) {
  final children = flat
      .where((sg) => sg.parentSubGoalId == id)
      .map((sg) => _buildNode(sg.id, byId, flat))
      .toList();
  return byId[id]!.copyWith(children: children);
}

List<SubGoal> buildSubGoalTree(List<SubGoal> flat) {
  final byId = {for (final sg in flat) sg.id: sg.copyWith(children: const [])};
  return flat
      .where((sg) => sg.parentSubGoalId == null)
      .map((sg) => _buildNode(sg.id, byId, flat))
      .toList();
}

Map<String, Offset> positionsFromJson(Map<String, dynamic>? j) {
  if (j == null) return const {};
  return j.map((k, v) {
    final m = v as Map<String, dynamic>;
    return MapEntry(k, Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()));
  });
}

Map<String, dynamic> positionsToJson(Map<String, Offset> pos) =>
    pos.map((k, v) => MapEntry(k, {'x': v.dx, 'y': v.dy}));

double subGoalProgress(SubGoal sg) {
  // Recurring tasks are an engine, not a measure of completion — exclude them
  // from the progress denominator so a goal with a recurring task can still
  // reach 100%.
  final progressTasks = sg.tasks.where((t) => !t.isRecurring).toList();
  final hasTasks    = progressTasks.isNotEmpty;
  final hasChildren = sg.children.isNotEmpty;

  if (!hasTasks && !hasChildren) return sg.isCompleted ? 100.0 : 0.0;

  double? taskSlot;
  if (hasTasks) {
    final total = progressTasks.fold(0, (s, t) => s + t.weight);
    final done  = progressTasks
        .where((t) => t.isCompleted)
        .fold(0, (s, t) => s + t.weight);
    taskSlot = total == 0 ? 0.0 : (done / total) * 100.0;
  }

  if (!hasChildren) return taskSlot!;

  final childValues = sg.children.map(subGoalProgress).toList();
  if (!hasTasks) {
    return childValues.reduce((a, b) => a + b) / childValues.length;
  }

  // tasks form 1 slot alongside each child slot
  final slots = [taskSlot!, ...childValues];
  return slots.reduce((a, b) => a + b) / slots.length;
}

double goalProgress(Goal g) {
  if (g.subGoals.isEmpty) return g.progress;
  final list = g.subGoals.map(subGoalProgress).toList();
  return list.reduce((a, b) => a + b) / list.length;
}

// Returns 2000 only when goal qualifies (age ≥ 1 day, has tasks, all done).
int goalCompletionBaseXp(Goal goal) {
  final ageQualifies = DateTime.now().difference(goal.createdAt).inDays >= 1;
  final hasTasks = goal.totalTasks > 0;
  final allTasksDone = goal.completedTasks == goal.totalTasks;
  return (ageQualifies && hasTasks && allTasksDone) ? 2000 : 0;
}

int taskXp(int weight) => switch (weight) {
      1 => 5,
      3 => 10,
      5 => 15,
      _ => 5,
    };

// ─── Recurrence ───────────────────────────────────────────────────────────────

/// Computes the next due date for a recurring task, given its [rule] and the
/// reference date [from] (typically the current dueDate, or `now`).
///
/// Supported compact formats:
///  - `daily`            → next day
///  - `weekly:1,3,5`     → next listed weekday (1=Mon … 7=Sun) after [from]
///  - `monthly:15`       → the given day-of-month next month (clamped to month length)
///  - `every:N`          → [from] + N days
///
/// Returns the date at midnight. Falls back to +1 day for unknown rules.
DateTime nextOccurrence(String rule, DateTime from) {
  final base = DateTime(from.year, from.month, from.day);
  final parts = rule.split(':');
  final kind = parts[0];
  final arg = parts.length > 1 ? parts[1] : '';

  switch (kind) {
    case 'daily':
      return base.add(const Duration(days: 1));

    case 'every':
      final n = int.tryParse(arg) ?? 1;
      return base.add(Duration(days: n < 1 ? 1 : n));

    case 'weekly':
      final days = arg
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .where((d) => d >= 1 && d <= 7)
          .toList()
        ..sort();
      if (days.isEmpty) return base.add(const Duration(days: 7));
      // Find the next listed weekday strictly after [base].
      for (var i = 1; i <= 7; i++) {
        final cand = base.add(Duration(days: i));
        if (days.contains(cand.weekday)) return cand;
      }
      return base.add(const Duration(days: 7));

    case 'monthly':
      final dom = int.tryParse(arg) ?? base.day;
      var year = base.year;
      var month = base.month + 1;
      if (month > 12) {
        month = 1;
        year++;
      }
      final lastDay = DateTime(year, month + 1, 0).day; // day 0 of next month
      final day = dom > lastDay ? lastDay : dom;
      return DateTime(year, month, day);

    default:
      return base.add(const Duration(days: 1));
  }
}

// Returns 0–1 progress for a metric milestone.
// For binary milestones returns 1.0 if completed, else 0.0.
double metricProgress(Milestone m) {
  if (!m.isMetric) return m.isCompleted ? 1.0 : 0.0;
  final start = m.startValue;
  final target = m.targetValue;
  final current = m.currentValue;
  if (start == null || target == null || current == null) return 0.0;
  final range = target - start;
  if (range == 0) return current == target ? 1.0 : 0.0;
  return ((current - start) / range).clamp(0.0, 1.0);
}

// ─── Task dependencies (Stage 8) ────────────────────────────────────────────

/// Flattens every task of a goal into an id→task lookup.
Map<String, PlanningTask> tasksById(Goal goal) {
  final map = <String, PlanningTask>{};
  for (final sg in _allSubGoals(goal.subGoals)) {
    for (final t in sg.tasks) {
      map[t.id] = t;
    }
  }
  return map;
}

/// A task is unblocked when all of its (still-existing) prerequisites are done.
/// Prerequisites that no longer exist are treated as satisfied.
bool isTaskUnblocked(PlanningTask task, Map<String, PlanningTask> byId) {
  for (final depId in task.dependsOn) {
    final dep = byId[depId];
    if (dep != null && !dep.isCompleted) return false;
  }
  return true;
}

/// The incomplete prerequisites still blocking [task] (for the "Ждёт: …" hint).
List<PlanningTask> taskBlockers(
    PlanningTask task, Map<String, PlanningTask> byId) {
  final blockers = <PlanningTask>[];
  for (final depId in task.dependsOn) {
    final dep = byId[depId];
    if (dep != null && !dep.isCompleted) blockers.add(dep);
  }
  return blockers;
}

/// Incomplete tasks of [goal] whose prerequisites are all done.
List<PlanningTask> readyTasks(Goal goal) {
  final byId = tasksById(goal);
  final ready = <PlanningTask>[];
  for (final t in byId.values) {
    if (!t.isCompleted && isTaskUnblocked(t, byId)) ready.add(t);
  }
  return ready;
}

/// Whether adding edge [taskId] depends-on [dependsOnTaskId] would create a
/// cycle, given the current adjacency (taskId → its dependsOn list). A cycle
/// forms if [dependsOnTaskId] can already reach [taskId] by following deps.
bool wouldCreateDependencyCycle(
  String taskId,
  String dependsOnTaskId,
  Map<String, List<String>> adjacency,
) {
  if (taskId == dependsOnTaskId) return true;
  final visited = <String>{};
  bool dfs(String node) {
    if (node == taskId) return true;
    if (!visited.add(node)) return false;
    for (final next in adjacency[node] ?? const <String>[]) {
      if (dfs(next)) return true;
    }
    return false;
  }

  return dfs(dependsOnTaskId);
}

bool isGoalFatigued(Goal g) {
  if (g.status != 'active') return false;
  if (g.isOverdue) return true;
  // Stagnation: no progress update for 7+ days
  final ref = g.updatedAt ?? g.createdAt;
  if (DateTime.now().difference(ref).inDays >= 7) return true;
  // 2+ tasks with missed deadlines (search entire tree)
  int missed = 0;
  for (final sg in _allSubGoals(g.subGoals)) {
    for (final t in sg.tasks) {
      if (!t.isCompleted && t.dueDate != null && DateTime.now().isAfter(t.dueDate!)) {
        if (++missed >= 2) return true;
      }
    }
  }
  return false;
}
