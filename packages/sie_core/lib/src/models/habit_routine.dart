import 'habit.dart';

class HabitRoutine {
  final String id;
  final String userId;
  final String routineType; // 'morning' | 'evening'
  final List<Habit> habits; // ordered by position ascending
  final DateTime createdAt;

  const HabitRoutine({
    required this.id,
    required this.userId,
    required this.routineType,
    required this.habits,
    required this.createdAt,
  });

  HabitRoutine copyWith({List<Habit>? habits}) => HabitRoutine(
        id: id,
        userId: userId,
        routineType: routineType,
        habits: habits ?? this.habits,
        createdAt: createdAt,
      );
}

class HabitRoutinesState {
  final HabitRoutine? morning;
  final HabitRoutine? evening;

  const HabitRoutinesState({this.morning, this.evening});

  static const empty = HabitRoutinesState(morning: null, evening: null);

  HabitRoutinesState copyWith({
    HabitRoutine? morning,
    HabitRoutine? evening,
    bool clearMorning = false,
    bool clearEvening = false,
  }) =>
      HabitRoutinesState(
        morning: clearMorning ? null : (morning ?? this.morning),
        evening: clearEvening ? null : (evening ?? this.evening),
      );
}
