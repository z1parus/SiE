import 'public_profile.dart';

class GoalCollaborator {
  final String id;
  final String goalId;
  final String userId;
  final String invitedBy;
  final String role;   // 'viewer' | 'editor'
  final String status; // 'pending' | 'accepted' | 'declined'
  final PublicProfile? profile;
  final DateTime createdAt;

  const GoalCollaborator({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.invitedBy,
    required this.role,
    required this.status,
    this.profile,
    required this.createdAt,
  });

  factory GoalCollaborator.fromJson(Map<String, dynamic> j) => GoalCollaborator(
        id: j['id'] as String,
        goalId: j['goal_id'] as String,
        userId: j['user_id'] as String,
        invitedBy: j['invited_by'] as String,
        role: j['role'] as String,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  GoalCollaborator copyWith({
    String? role,
    String? status,
    PublicProfile? profile,
  }) =>
      GoalCollaborator(
        id: id,
        goalId: goalId,
        userId: userId,
        invitedBy: invitedBy,
        role: role ?? this.role,
        status: status ?? this.status,
        profile: profile ?? this.profile,
        createdAt: createdAt,
      );
}
