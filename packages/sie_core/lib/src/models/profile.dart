class Profile {
  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final int totalXp;
  final bool isLabMember;
  final bool hasSeenWelcome;
  final bool hasSeenOnboardingBreathing;
  final bool hasSeenOnboardingHabits;
  final bool hasSeenOnboardingFocus;
  final String? equippedFrameId;
  final String? equippedBackgroundId;
  final String? equippedStatStyleId;
  final int designPoints;

  const Profile({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
    required this.totalXp,
    required this.isLabMember,
    this.hasSeenWelcome = false,
    this.hasSeenOnboardingBreathing = false,
    this.hasSeenOnboardingHabits = false,
    this.hasSeenOnboardingFocus = false,
    this.equippedFrameId,
    this.equippedBackgroundId,
    this.equippedStatStyleId,
    this.designPoints = 0,
  });

  Profile copyWith({
    int? totalXp,
    int? designPoints,
    String? avatarUrl,
    String? username,
    String? fullName,
  }) =>
      Profile(
        id: id,
        username: username ?? this.username,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        totalXp: totalXp ?? this.totalXp,
        isLabMember: isLabMember,
        hasSeenWelcome: hasSeenWelcome,
        hasSeenOnboardingBreathing: hasSeenOnboardingBreathing,
        hasSeenOnboardingHabits: hasSeenOnboardingHabits,
        hasSeenOnboardingFocus: hasSeenOnboardingFocus,
        equippedFrameId: equippedFrameId,
        equippedBackgroundId: equippedBackgroundId,
        equippedStatStyleId: equippedStatStyleId,
        designPoints: designPoints ?? this.designPoints,
      );

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String?,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        totalXp: json['total_xp'] as int? ?? 0,
        isLabMember: json['is_lab_member'] as bool? ?? false,
        hasSeenWelcome: json['has_seen_welcome'] as bool? ?? false,
        hasSeenOnboardingBreathing:
            json['has_seen_onboarding_breathing'] as bool? ?? false,
        hasSeenOnboardingHabits:
            json['has_seen_onboarding_habits'] as bool? ?? false,
        hasSeenOnboardingFocus:
            json['has_seen_onboarding_focus'] as bool? ?? false,
        equippedFrameId: json['equipped_frame_id'] as String?,
        equippedBackgroundId: json['equipped_background_id'] as String?,
        equippedStatStyleId: json['equipped_stat_style_id'] as String?,
        designPoints: json['design_points'] as int? ?? 0,
      );
}
