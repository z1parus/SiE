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
  final bool hasSeenTour;
  final bool hasSeenCoursePlanning;
  final bool hasSeenCourseHabits;
  final bool hasSeenCourseFocus;
  final bool hasSeenCourseBreathing;
  final String? equippedFrameId;
  final String? equippedBackgroundId;
  final String? equippedStatStyleId;
  final String? equippedPatternId;
  final int designPoints;
  final bool isAdmin;
  final int? telegramId;
  final String? telegramUsername;

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
    this.hasSeenTour = false,
    this.hasSeenCoursePlanning = false,
    this.hasSeenCourseHabits = false,
    this.hasSeenCourseFocus = false,
    this.hasSeenCourseBreathing = false,
    this.equippedFrameId,
    this.equippedBackgroundId,
    this.equippedStatStyleId,
    this.equippedPatternId,
    this.designPoints = 0,
    this.isAdmin = false,
    this.telegramId,
    this.telegramUsername,
  });

  Profile copyWith({
    int? totalXp,
    int? designPoints,
    String? avatarUrl,
    String? username,
    String? fullName,
    bool? hasSeenTour,
    bool? hasSeenCoursePlanning,
    bool? hasSeenCourseHabits,
    bool? hasSeenCourseFocus,
    bool? hasSeenCourseBreathing,
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
        hasSeenTour: hasSeenTour ?? this.hasSeenTour,
        hasSeenCoursePlanning:
            hasSeenCoursePlanning ?? this.hasSeenCoursePlanning,
        hasSeenCourseHabits: hasSeenCourseHabits ?? this.hasSeenCourseHabits,
        hasSeenCourseFocus: hasSeenCourseFocus ?? this.hasSeenCourseFocus,
        hasSeenCourseBreathing:
            hasSeenCourseBreathing ?? this.hasSeenCourseBreathing,
        equippedFrameId: equippedFrameId,
        equippedBackgroundId: equippedBackgroundId,
        equippedStatStyleId: equippedStatStyleId,
        equippedPatternId: equippedPatternId,
        designPoints: designPoints ?? this.designPoints,
        isAdmin: isAdmin,
        telegramId: telegramId ?? this.telegramId,
        telegramUsername: telegramUsername ?? this.telegramUsername,
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
        hasSeenTour: json['has_seen_tour'] as bool? ?? false,
        hasSeenCoursePlanning:
            json['has_seen_course_planning'] as bool? ?? false,
        hasSeenCourseHabits:
            json['has_seen_course_habits'] as bool? ?? false,
        hasSeenCourseFocus: json['has_seen_course_focus'] as bool? ?? false,
        hasSeenCourseBreathing:
            json['has_seen_course_breathing'] as bool? ?? false,
        equippedFrameId: json['equipped_frame_id'] as String?,
        equippedBackgroundId: json['equipped_background_id'] as String?,
        equippedStatStyleId: json['equipped_stat_style_id'] as String?,
        equippedPatternId: json['equipped_pattern_id'] as String?,
        designPoints: json['design_points'] as int? ?? 0,
        isAdmin: json['is_admin'] as bool? ?? false,
        telegramId: json['telegram_id'] as int?,
        telegramUsername: json['telegram_username'] as String?,
      );
}
