class VanguardResult {
  final int place;
  final String userId;
  final String? username;
  final String? avatarUrl;
  final int xpEarned;
  final int dpAwarded;

  const VanguardResult({
    required this.place,
    required this.userId,
    this.username,
    this.avatarUrl,
    required this.xpEarned,
    required this.dpAwarded,
  });

  factory VanguardResult.fromJson(Map<String, dynamic> j) => VanguardResult(
        place: (j['place'] as num).toInt(),
        userId: j['winner_id'] as String,
        username: j['winner_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        xpEarned: (j['xp_earned'] as num?)?.toInt() ?? 0,
        dpAwarded: (j['dp_awarded'] as num?)?.toInt() ?? 0,
      );
}
