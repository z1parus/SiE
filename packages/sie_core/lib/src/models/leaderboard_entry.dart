class LeaderboardEntry {
  final String userId;
  final String? username;
  final String? avatarUrl;
  final String? equippedFrameId;
  final String? equippedBackgroundId;
  final String? equippedStatStyleId;
  final int totalXp;
  final int dailyXp;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    this.username,
    this.avatarUrl,
    this.equippedFrameId,
    this.equippedBackgroundId,
    this.equippedStatStyleId,
    required this.totalXp,
    required this.dailyXp,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        userId: json['user_id'] as String,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        equippedFrameId: json['equipped_frame_id'] as String?,
        equippedBackgroundId: json['equipped_background_id'] as String?,
        equippedStatStyleId: json['equipped_stat_style_id'] as String?,
        totalXp: json['total_xp'] as int? ?? 0,
        dailyXp: json['daily_xp'] as int? ?? 0,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
      );
}
