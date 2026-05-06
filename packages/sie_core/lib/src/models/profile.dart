class Profile {
  final String id;
  final String? username;
  final String? fullName;
  final int totalXp;
  final bool isLabMember;
  final bool hasSeenWelcome;
  final bool hasSeenOnboardingBreathing;
  final bool hasSeenOnboardingHabits;
  final bool hasSeenOnboardingFocus;

  const Profile({
    required this.id,
    this.username,
    this.fullName,
    required this.totalXp,
    required this.isLabMember,
    this.hasSeenWelcome = false,
    this.hasSeenOnboardingBreathing = false,
    this.hasSeenOnboardingHabits = false,
    this.hasSeenOnboardingFocus = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String?,
        fullName: json['full_name'] as String?,
        totalXp: json['total_xp'] as int? ?? 0,
        isLabMember: json['is_lab_member'] as bool? ?? false,
        hasSeenWelcome: json['has_seen_welcome'] as bool? ?? false,
        hasSeenOnboardingBreathing:
            json['has_seen_onboarding_breathing'] as bool? ?? false,
        hasSeenOnboardingHabits:
            json['has_seen_onboarding_habits'] as bool? ?? false,
        hasSeenOnboardingFocus:
            json['has_seen_onboarding_focus'] as bool? ?? false,
      );
}
