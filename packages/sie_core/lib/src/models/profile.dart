class Profile {
  final String id;
  final String? username;
  final String? fullName;
  final int totalXp;
  final bool isLabMember;

  const Profile({
    required this.id,
    this.username,
    this.fullName,
    required this.totalXp,
    required this.isLabMember,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String?,
        fullName: json['full_name'] as String?,
        totalXp: json['total_xp'] as int? ?? 0,
        isLabMember: json['is_lab_member'] as bool? ?? false,
      );
}
