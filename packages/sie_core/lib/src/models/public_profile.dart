class PublicProfile {
  final String id;
  final String? username;
  final String? avatarUrl;
  final int totalXp;

  int get level => (totalXp ~/ 1000) + 1;
  int get xpInLevel => totalXp % 1000;

  const PublicProfile({
    required this.id,
    this.username,
    this.avatarUrl,
    required this.totalXp,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        id: json['id'] as String,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        totalXp: json['total_xp'] as int? ?? 0,
      );
}
