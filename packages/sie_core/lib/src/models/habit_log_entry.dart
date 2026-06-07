class HabitLogEntry {
  final String habitId;
  final String userId;
  final String completedAt; // 'YYYY-MM-DD'
  final String? note;
  final String? emoji;

  const HabitLogEntry({
    required this.habitId,
    required this.userId,
    required this.completedAt,
    this.note,
    this.emoji,
  });

  factory HabitLogEntry.fromMap(Map<dynamic, dynamic> map) => HabitLogEntry(
        habitId: map['habit_id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        completedAt: map['completed_at']?.toString() ?? '',
        note: map['note']?.toString(),
        emoji: map['emoji']?.toString(),
      );

  HabitLogEntry copyWith({String? note, String? emoji}) => HabitLogEntry(
        habitId: habitId,
        userId: userId,
        completedAt: completedAt,
        note: note ?? this.note,
        emoji: emoji ?? this.emoji,
      );
}
