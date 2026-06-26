/// A quick note (memo) in a goal's journal — something the user doesn't want
/// to forget about that goal. Notes are shared with the goal: every accepted
/// collaborator sees them.
class GoalNote {
  const GoalNote({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.title,
  });

  final String id;
  final String goalId;
  final String userId; // author
  final String? title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  GoalNote copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
  }) =>
      GoalNote(
        id: id,
        goalId: goalId,
        userId: userId,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory GoalNote.fromMap(Map<String, dynamic> m) => GoalNote(
        id: m['id'] as String,
        goalId: m['goal_id'] as String,
        userId: m['user_id'] as String,
        title: (m['title'] as String?)?.trim().isEmpty ?? true
            ? null
            : (m['title'] as String).trim(),
        body: m['body'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toUpsertJson() => {
        'id': id,
        'goal_id': goalId,
        'user_id': userId,
        if (title != null) 'title': title,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
