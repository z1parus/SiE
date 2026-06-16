class PublicProfile {
  final String id;
  final String? username;
  final String? avatarUrl;
  final String? equippedFrameId;
  final String? equippedBackgroundId;
  final String? equippedStatStyleId;
  final String? equippedPatternId;
  final int totalXp;
  final int designPoints;

  int get level => (totalXp ~/ 1000) + 1;
  int get xpInLevel => totalXp % 1000;

  const PublicProfile({
    required this.id,
    this.username,
    this.avatarUrl,
    this.equippedFrameId,
    this.equippedBackgroundId,
    this.equippedStatStyleId,
    this.equippedPatternId,
    required this.totalXp,
    this.designPoints = 0,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        id: json['id'] as String,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        equippedFrameId: json['equipped_frame_id'] as String?,
        equippedBackgroundId: json['equipped_background_id'] as String?,
        equippedStatStyleId: json['equipped_stat_style_id'] as String?,
        equippedPatternId: json['equipped_pattern_id'] as String?,
        totalXp: json['total_xp'] as int? ?? 0,
        designPoints: json['design_points'] as int? ?? 0,
      );
}

class PublicProfileStats {
  final int habitCompletions;
  final int focusTotalSeconds;

  const PublicProfileStats({
    required this.habitCompletions,
    required this.focusTotalSeconds,
  });

  factory PublicProfileStats.fromJson(Map<String, dynamic> json) =>
      PublicProfileStats(
        habitCompletions: json['habit_completions'] as int? ?? 0,
        focusTotalSeconds: json['focus_total_seconds'] as int? ?? 0,
      );

  factory PublicProfileStats.zero() =>
      const PublicProfileStats(habitCompletions: 0, focusTotalSeconds: 0);

  String get focusTime {
    final h = focusTotalSeconds ~/ 3600;
    final m = (focusTotalSeconds % 3600) ~/ 60;
    if (h > 0) return '$hч ${m.toString().padLeft(2, '0')}м';
    if (m > 0) return '$mм';
    return '0м';
  }
}
