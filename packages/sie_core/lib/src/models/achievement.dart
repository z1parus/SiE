class Achievement {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final String iconEmoji;
  final int xpReward;

  const Achievement({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.iconEmoji = '🏆',
    required this.xpReward,
  });

  factory Achievement.fromMap(Map<dynamic, dynamic> map) => Achievement(
        id: map['id']?.toString() ?? '',
        slug: map['slug']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        description: map['description']?.toString(),
        iconEmoji: map['icon_emoji']?.toString() ?? '🏆',
        xpReward: int.tryParse('${map['xp_reward'] ?? 0}') ?? 0,
      );
}

/// Achievement enriched with per-user earn status.
class UserAchievement {
  final Achievement achievement;
  final bool earned;
  final DateTime? earnedAt;

  const UserAchievement({
    required this.achievement,
    required this.earned,
    this.earnedAt,
  });
}
