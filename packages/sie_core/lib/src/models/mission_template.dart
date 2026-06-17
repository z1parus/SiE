import 'dart:convert';
import 'planning.dart';

// ─── Template structure (serialised blueprint, no ids/dates/progress) ─────────

const int _kMaxDepth = 4;

class TemplateTask {
  const TemplateTask({required this.name, required this.weight});

  final String name;
  final int weight; // 1 / 3 / 5

  factory TemplateTask.fromJson(Map<String, dynamic> j) {
    var w = (j['weight'] as num?)?.toInt() ?? 1;
    if (w <= 2) {
      w = 1;
    } else if (w <= 4) {
      w = 3;
    } else {
      w = 5;
    }
    return TemplateTask(name: (j['name'] as String? ?? 'Задача').trim(), weight: w);
  }

  Map<String, dynamic> toJson() => {'name': name, 'weight': weight};
}

class TemplateSubGoal {
  const TemplateSubGoal({
    required this.name,
    this.tasks = const [],
    this.children = const [],
  });

  final String name;
  final List<TemplateTask> tasks;
  final List<TemplateSubGoal> children;

  factory TemplateSubGoal.fromJson(Map<String, dynamic> j, {int depth = 0}) {
    final rawTasks = j['tasks'];
    final tasks = rawTasks is List
        ? rawTasks
            .whereType<Map<String, dynamic>>()
            .map(TemplateTask.fromJson)
            .toList()
        : <TemplateTask>[];
    final rawChildren = j['children'];
    final children = (rawChildren is List && depth < _kMaxDepth)
        ? rawChildren
            .whereType<Map<String, dynamic>>()
            .map((c) => TemplateSubGoal.fromJson(c, depth: depth + 1))
            .toList()
        : <TemplateSubGoal>[];
    return TemplateSubGoal(
      name: (j['name'] as String? ?? 'Этап').trim(),
      tasks: tasks,
      children: children,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tasks': [for (final t in tasks) t.toJson()],
        if (children.isNotEmpty)
          'children': [for (final c in children) c.toJson()],
      };

  int get taskCount =>
      tasks.length + children.fold(0, (s, c) => s + c.taskCount);
  int get subGoalCount =>
      1 + children.fold(0, (s, c) => s + c.subGoalCount);
}

class TemplateMilestone {
  const TemplateMilestone({
    required this.name,
    this.kind = 'binary',
    this.unit,
    this.startValue,
    this.targetValue,
    this.direction = 'up',
  });

  final String name;
  final String kind; // 'binary' | 'metric'
  final String? unit;
  final double? startValue;
  final double? targetValue;
  final String direction;

  factory TemplateMilestone.fromJson(Map<String, dynamic> j) =>
      TemplateMilestone(
        name: (j['name'] as String? ?? 'Контрольная точка').trim(),
        kind: j['kind'] as String? ?? 'binary',
        unit: j['unit'] as String?,
        startValue: (j['start_value'] as num?)?.toDouble(),
        targetValue: (j['target_value'] as num?)?.toDouble(),
        direction: j['direction'] as String? ?? 'up',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
        if (unit != null) 'unit': unit,
        if (startValue != null) 'start_value': startValue,
        if (targetValue != null) 'target_value': targetValue,
        'direction': direction,
      };
}

class TemplateStructure {
  const TemplateStructure({
    this.subGoals = const [],
    this.milestones = const [],
  });

  final List<TemplateSubGoal> subGoals;
  final List<TemplateMilestone> milestones;

  factory TemplateStructure.fromJson(Map<String, dynamic> j) {
    final rawSgs = j['subGoals'] ?? j['sub_goals'];
    final rawMs = j['milestones'];
    return TemplateStructure(
      subGoals: rawSgs is List
          ? rawSgs
              .whereType<Map<String, dynamic>>()
              .map((s) => TemplateSubGoal.fromJson(s))
              .toList()
          : const [],
      milestones: rawMs is List
          ? rawMs
              .whereType<Map<String, dynamic>>()
              .map(TemplateMilestone.fromJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'subGoals': [for (final s in subGoals) s.toJson()],
        'milestones': [for (final m in milestones) m.toJson()],
      };

  int get subGoalCount => subGoals.fold(0, (s, sg) => s + sg.subGoalCount);
  int get taskCount => subGoals.fold(0, (s, sg) => s + sg.taskCount);
  int get milestoneCount => milestones.length;

  /// Builds a template blueprint from a live goal, stripping all personal data
  /// (ids, dates, progress, completed flags, current metric values).
  factory TemplateStructure.fromGoal(Goal goal) {
    TemplateSubGoal mapSg(SubGoal sg) => TemplateSubGoal(
          name: sg.name,
          tasks: [
            for (final t in sg.tasks)
              TemplateTask(name: t.name, weight: t.weight),
          ],
          children: [for (final c in sg.children) mapSg(c)],
        );
    return TemplateStructure(
      subGoals: [for (final sg in goal.subGoals) mapSg(sg)],
      milestones: [
        for (final m in goal.milestones)
          TemplateMilestone(
            name: m.name,
            kind: m.kind,
            unit: m.unit,
            startValue: m.startValue,
            targetValue: m.targetValue,
            direction: m.direction,
          ),
      ],
    );
  }
}

// ─── Mission template ─────────────────────────────────────────────────────────

class MissionTemplate {
  const MissionTemplate({
    required this.id,
    required this.name,
    required this.isSystem,
    required this.structure,
    required this.createdAt,
    this.userId,
    this.description,
    this.category,
    this.colorHex = '#5AADA0',
    this.isPublic = false,
  });

  final String id;
  final String? userId; // null = system
  final String name;
  final String? description;
  final GoalCategory? category;
  final bool isSystem;
  final bool isPublic;
  final String colorHex;
  final TemplateStructure structure;
  final DateTime createdAt;

  factory MissionTemplate.fromJson(Map<String, dynamic> j) {
    final catStr = j['category'] as String?;
    final cat = catStr != null
        ? GoalCategory.values.where((e) => e.name == catStr).firstOrNull
        : null;
    final rawStruct = j['structure_json'];
    final structMap = rawStruct is String
        ? jsonDecode(rawStruct) as Map<String, dynamic>
        : (rawStruct as Map?)?.cast<String, dynamic>() ?? const {};
    return MissionTemplate(
      id: j['id'] as String,
      userId: j['user_id'] as String?,
      name: j['name'] as String,
      description: j['description'] as String?,
      category: cat,
      isSystem: j['is_system'] as bool? ?? false,
      isPublic: j['is_public'] as bool? ?? false,
      colorHex: j['color_hex'] as String? ?? '#5AADA0',
      structure: TemplateStructure.fromJson(structMap),
      createdAt: j['created_at'] != null
          ? DateTime.parse(j['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        if (userId != null) 'user_id': userId,
        'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category!.name,
        'is_system': isSystem,
        'is_public': isPublic,
        'color_hex': colorHex,
        'structure_json': structure.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  String get structureJsonString => jsonEncode(structure.toJson());

  MissionTemplate copyWith({
    String? id,
    String? userId,
    String? name,
    bool? isSystem,
  }) =>
      MissionTemplate(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        description: description,
        category: category,
        isSystem: isSystem ?? this.isSystem,
        isPublic: isPublic,
        colorHex: colorHex,
        structure: structure,
        createdAt: createdAt,
      );
}
