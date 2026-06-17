class HabitLogEntry {
  final String habitId;
  final String userId;
  final String completedAt; // 'YYYY-MM-DD'
  final String? note;
  final String? emoji;
  // Stage 2: accumulated value for the day (count/duration habits). For
  // binary habits this is 1 when the day is logged.
  final double value;
  // Stage 5: 'done' (default) | 'rest' (explicit rest day, doesn't break streak).
  final String entryType;

  const HabitLogEntry({
    required this.habitId,
    required this.userId,
    required this.completedAt,
    this.note,
    this.emoji,
    this.value = 1,
    this.entryType = 'done',
  });

  bool get isRest => entryType == 'rest';

  factory HabitLogEntry.fromMap(Map<dynamic, dynamic> map) => HabitLogEntry(
        habitId: map['habit_id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        completedAt: map['completed_at']?.toString() ?? '',
        note: map['note']?.toString(),
        emoji: map['emoji']?.toString(),
        value: (map['value'] as num?)?.toDouble() ?? 1,
        entryType: map['entry_type']?.toString() ?? 'done',
      );

  HabitLogEntry copyWith({
    String? note,
    String? emoji,
    double? value,
    String? entryType,
  }) =>
      HabitLogEntry(
        habitId: habitId,
        userId: userId,
        completedAt: completedAt,
        note: note ?? this.note,
        emoji: emoji ?? this.emoji,
        value: value ?? this.value,
        entryType: entryType ?? this.entryType,
      );
}
