import 'habit.dart';

/// A routine / habit stack — an ordered group of habits.
///
/// Stage 8b generalises the original morning/evening routines into named
/// **stacks** with an optional anchor cue (Atomic Habits: "After I [anchor],
/// I will [habit]"). [routineType] keeps the legacy `'morning'`/`'evening'`
/// values for backward compatibility; user-created stacks use `'stack'`.
class HabitRoutine {
  final String id;
  final String userId;
  final String routineType; // 'morning' | 'evening' | 'stack'
  final String? name; // custom name for stacks (null for legacy routines)
  final String? anchorCue; // trigger cue, e.g. "После утреннего кофе"
  final List<Habit> habits; // ordered by position ascending
  final DateTime createdAt;

  const HabitRoutine({
    required this.id,
    required this.userId,
    required this.routineType,
    this.name,
    this.anchorCue,
    required this.habits,
    required this.createdAt,
  });

  /// True for user-created named stacks (not the legacy morning/evening).
  bool get isStack => routineType == 'stack';

  /// Human-facing title: custom [name] when set, otherwise a label derived
  /// from [routineType].
  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return switch (routineType) {
      'morning' => 'Утренняя рутина',
      'evening' => 'Вечерняя рутина',
      _ => 'Стэк привычек',
    };
  }

  HabitRoutine copyWith({
    List<Habit>? habits,
    String? name,
    String? anchorCue,
  }) =>
      HabitRoutine(
        id: id,
        userId: userId,
        routineType: routineType,
        name: name ?? this.name,
        anchorCue: anchorCue ?? this.anchorCue,
        habits: habits ?? this.habits,
        createdAt: createdAt,
      );
}

class HabitRoutinesState {
  /// All routines for the user, including legacy morning/evening and stacks,
  /// ordered by creation time.
  final List<HabitRoutine> stacks;

  const HabitRoutinesState({this.stacks = const []});

  static const empty = HabitRoutinesState();

  HabitRoutine? get morning => _byType('morning');
  HabitRoutine? get evening => _byType('evening');

  /// User-created named stacks (excludes legacy morning/evening).
  List<HabitRoutine> get namedStacks =>
      stacks.where((s) => s.routineType == 'stack').toList();

  HabitRoutine? _byType(String type) {
    for (final s in stacks) {
      if (s.routineType == type) return s;
    }
    return null;
  }

  HabitRoutine? byId(String id) {
    for (final s in stacks) {
      if (s.id == id) return s;
    }
    return null;
  }
}
