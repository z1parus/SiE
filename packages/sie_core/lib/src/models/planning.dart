import 'package:flutter/material.dart';

const _unset = Object();

// ─── Task ─────────────────────────────────────────────────────────────────────

class PlanningTask {
  const PlanningTask({
    required this.id,
    required this.subGoalId,
    required this.userId,
    required this.name,
    required this.weight,
    required this.isCompleted,
    required this.createdAt,
    this.completedAt,
    this.dueDate,
  });

  final String id;
  final String subGoalId;
  final String userId;
  final String name;
  final int weight; // 1 / 3 / 5
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? dueDate;
  final DateTime createdAt;

  PlanningTask copyWith({
    String? subGoalId,
    String? name,
    bool? isCompleted,
    Object? completedAt = _unset,
    DateTime? dueDate,
  }) =>
      PlanningTask(
        id: id,
        subGoalId: subGoalId ?? this.subGoalId,
        userId: userId,
        name: name ?? this.name,
        weight: weight,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt:
            completedAt == _unset ? this.completedAt : completedAt as DateTime?,
        dueDate: dueDate ?? this.dueDate,
        createdAt: createdAt,
      );

  factory PlanningTask.fromJson(Map<String, dynamic> j) => PlanningTask(
        id: j['id'] as String,
        subGoalId: j['sub_goal_id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        weight: (j['weight'] as num?)?.toInt() ?? 1,
        isCompleted: j['is_completed'] as bool? ?? false,
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
        dueDate: j['due_date'] != null
            ? DateTime.parse(j['due_date'] as String)
            : null,
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
    List<PlanningTask>? tasks,
    List<SubGoal>? children,
  }) =>
      SubGoal(
        id: id,
        goalId: goalId,
        parentSubGoalId: parentSubGoalId,
        name: name ?? this.name,
        isCompleted: isCompleted ?? this.isCompleted,
        orderIndex: orderIndex,
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
  });

  final String id;
  final String goalId;
  final String name;
  final DateTime? targetDate;
  final bool isCompleted;
  final DateTime createdAt;

  Milestone copyWith({bool? isCompleted}) => Milestone(
        id: id,
        goalId: goalId,
        name: name,
        targetDate: targetDate,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
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
      );
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
      };
}

// ─── PlanningState ────────────────────────────────────────────────────────────

class PlanningState {
  const PlanningState({required this.goals});

  final List<Goal> goals;

  static const empty = PlanningState(goals: []);

  PlanningState copyWith({List<Goal>? goals}) =>
      PlanningState(goals: goals ?? this.goals);

  List<Goal> get activeGoals =>
      goals.where((g) => g.status == 'active').toList();
  List<Goal> get archivedGoals =>
      goals.where((g) => g.status != 'active').toList();
}

// ─── Helper functions ─────────────────────────────────────────────────────────

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

double subGoalProgress(SubGoal sg) {
  if (sg.children.isNotEmpty) {
    final list = sg.children.map(subGoalProgress).toList();
    return list.reduce((a, b) => a + b) / list.length;
  }
  if (sg.tasks.isEmpty) return sg.isCompleted ? 100.0 : 0.0;
  final total = sg.tasks.fold(0, (s, t) => s + t.weight);
  final done =
      sg.tasks.where((t) => t.isCompleted).fold(0, (s, t) => s + t.weight);
  return total == 0 ? 0.0 : (done / total) * 100.0;
}

double goalProgress(Goal g) {
  if (g.subGoals.isEmpty) return g.progress;
  final list = g.subGoals.map(subGoalProgress).toList();
  return list.reduce((a, b) => a + b) / list.length;
}

int taskXp(int weight) => switch (weight) {
      1 => 5,
      3 => 10,
      5 => 15,
      _ => 5,
    };

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
