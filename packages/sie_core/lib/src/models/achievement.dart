class Achievement {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final int xpReward;

  const Achievement({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.xpReward,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        xpReward: json['xp_reward'] as int? ?? 0,
      );
}
