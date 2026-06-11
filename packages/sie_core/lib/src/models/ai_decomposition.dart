import 'dart:convert';

class AiTask {
  final String name;
  final int weight;

  const AiTask({required this.name, required this.weight});

  factory AiTask.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['weight'];
    int w = 1;
    if (rawWeight is int) w = rawWeight;
    else if (rawWeight is double) w = rawWeight.round();
    else if (rawWeight is String) w = int.tryParse(rawWeight) ?? 1;
    // Snap to nearest valid weight: 1, 3, or 5
    if (w <= 2) w = 1;
    else if (w <= 4) w = 3;
    else w = 5;
    return AiTask(
      name: (json['name'] as String? ?? 'Задача').trim(),
      weight: w,
    );
  }
}

class AiSubGoal {
  final String name;
  final List<AiTask> tasks;

  const AiSubGoal({required this.name, required this.tasks});

  factory AiSubGoal.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'];
    final tasks = rawTasks is List
        ? rawTasks
            .whereType<Map<String, dynamic>>()
            .map(AiTask.fromJson)
            .toList()
        : <AiTask>[];
    return AiSubGoal(
      name: (json['name'] as String? ?? 'Этап').trim(),
      tasks: tasks,
    );
  }

  int get totalTaskWeight => tasks.fold(0, (s, t) => s + t.weight);
}

class AiMilestone {
  final String name;

  const AiMilestone({required this.name});

  factory AiMilestone.fromJson(Map<String, dynamic> json) =>
      AiMilestone(name: (json['name'] as String? ?? 'Контрольная точка').trim());
}

class DecompositionResult {
  final List<AiSubGoal> subGoals;
  final List<AiMilestone> milestones;

  const DecompositionResult({required this.subGoals, required this.milestones});

  int get totalTasks => subGoals.fold(0, (s, sg) => s + sg.tasks.length);
  int get totalWeight => subGoals.fold(0, (s, sg) => s + sg.totalTaskWeight);

  factory DecompositionResult.fromJson(Map<String, dynamic> json) {
    final rawSgs = json['sub_goals'];
    final rawMs = json['milestones'];

    final subGoals = rawSgs is List
        ? rawSgs.whereType<Map<String, dynamic>>().map(AiSubGoal.fromJson).toList()
        : <AiSubGoal>[];

    final milestones = rawMs is List
        ? rawMs.whereType<Map<String, dynamic>>().map(AiMilestone.fromJson).toList()
        : <AiMilestone>[];

    return DecompositionResult(subGoals: subGoals, milestones: milestones);
  }

  factory DecompositionResult.fromRawString(String raw) {
    // Try to extract JSON even if model added extra text
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw FormatException('No JSON object found in AI response');
    }
    final jsonStr = raw.substring(start, end + 1);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    return DecompositionResult.fromJson(decoded);
  }
}

class GroqRateLimitException implements Exception {
  const GroqRateLimitException();
  @override
  String toString() =>
      'Достигнут дневной лимит AI-запросов. Попробуй завтра.';
}

class GroqApiException implements Exception {
  final String message;
  const GroqApiException(this.message);
  @override
  String toString() => message;
}
