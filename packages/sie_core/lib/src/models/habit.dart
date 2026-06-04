class Habit {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String color;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.color = '#00C8FF',
    this.isPinned = false,
    this.isArchived = false,
    required this.createdAt,
  });

  factory Habit.fromMap(Map<dynamic, dynamic> map) => Habit(
        id: map['id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        description: map['description']?.toString(),
        color: map['color']?.toString() ?? '#00C8FF',
        isPinned: map['is_pinned'] == true,
        isArchived: map['is_archived'] == true,
        createdAt:
            DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  Habit copyWith({
    String? title,
    String? description,
    String? color,
    bool? isPinned,
    bool? isArchived,
  }) =>
      Habit(
        id: id,
        userId: userId,
        title: title ?? this.title,
        description: description ?? this.description,
        color: color ?? this.color,
        isPinned: isPinned ?? this.isPinned,
        isArchived: isArchived ?? this.isArchived,
        createdAt: createdAt,
      );
}

class HabitsState {
  final List<Habit> habits;

  /// habitId → set of 'yyyy-MM-dd' strings completed in last 30 days
  final Map<String, Set<String>> logDates;

  /// habitId → consecutive-day streak count (ending today)
  final Map<String, int> streaks;

  const HabitsState({
    required this.habits,
    required this.logDates,
    required this.streaks,
  });

  static const empty = HabitsState(habits: [], logDates: {}, streaks: {});
}
