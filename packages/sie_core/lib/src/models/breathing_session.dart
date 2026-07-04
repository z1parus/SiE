/// A single completed breathing-practice session, including the metrics of the
/// practice itself and the user's optional post-practice reflection.
class BreathingSession {
  final String id;
  final String userId;
  final int durationSeconds;
  final int breaths; // total inhale/exhale cycles across all rounds
  final int rounds; // rounds completed
  final int longestHoldSeconds; // longest single exhale retention
  final int totalHoldSeconds; // summed exhale retentions
  final String? moodEmoji;
  final int? calmness; // 1..10
  final int? confidence; // 1..10
  final int xpAwarded;
  final int dpAwarded;
  /// Set when this breathing ran as the preliminary practice of a meditation
  /// session (Ecosystem Stage 1) — links to that meditation session's id.
  final String? meditationSessionId;
  final DateTime completedAt;

  const BreathingSession({
    required this.id,
    required this.userId,
    required this.durationSeconds,
    this.breaths = 0,
    this.rounds = 0,
    this.longestHoldSeconds = 0,
    this.totalHoldSeconds = 0,
    this.moodEmoji,
    this.calmness,
    this.confidence,
    this.xpAwarded = 0,
    this.dpAwarded = 0,
    this.meditationSessionId,
    required this.completedAt,
  });

  /// True when this session was part of a meditation chain.
  bool get isPartOfMeditation =>
      meditationSessionId != null && meditationSessionId!.isNotEmpty;

  bool get hasReflection =>
      (moodEmoji != null && moodEmoji!.isNotEmpty) ||
      calmness != null ||
      confidence != null;

  factory BreathingSession.fromMap(Map<String, dynamic> m) => BreathingSession(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        durationSeconds: (m['duration_seconds'] as num?)?.toInt() ?? 0,
        breaths: (m['breaths'] as num?)?.toInt() ?? 0,
        rounds: (m['rounds'] as num?)?.toInt() ?? 0,
        longestHoldSeconds: (m['longest_hold_seconds'] as num?)?.toInt() ?? 0,
        totalHoldSeconds: (m['total_hold_seconds'] as num?)?.toInt() ?? 0,
        moodEmoji: m['mood_emoji'] as String?,
        calmness: (m['calmness'] as num?)?.toInt(),
        confidence: (m['confidence'] as num?)?.toInt(),
        xpAwarded: (m['xp_awarded'] as num?)?.toInt() ?? 0,
        dpAwarded: (m['dp_awarded'] as num?)?.toInt() ?? 0,
        meditationSessionId: m['meditation_session_id'] as String?,
        completedAt:
            DateTime.tryParse('${m['completed_at']}')?.toLocal() ??
                DateTime.now(),
      );

  Map<String, dynamic> toUpsertJson() => {
        'id': id,
        'user_id': userId,
        'duration_seconds': durationSeconds,
        'breaths': breaths,
        'rounds': rounds,
        'longest_hold_seconds': longestHoldSeconds,
        'total_hold_seconds': totalHoldSeconds,
        'mood_emoji': moodEmoji,
        'calmness': calmness,
        'confidence': confidence,
        'xp_awarded': xpAwarded,
        'dp_awarded': dpAwarded,
        'completed_at': completedAt.toUtc().toIso8601String(),
      };
}
