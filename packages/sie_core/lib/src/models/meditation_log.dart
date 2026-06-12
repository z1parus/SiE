class MeditationLog {
  final String id;
  final String userId;
  final String? presetId;
  final int durationSeconds;
  final int xpAwarded;
  final int dpAwarded;
  final int? stateBefore;
  final int? stateAfter;
  final DateTime completedAt;

  const MeditationLog({
    required this.id,
    required this.userId,
    this.presetId,
    required this.durationSeconds,
    this.xpAwarded = 0,
    this.dpAwarded = 0,
    this.stateBefore,
    this.stateAfter,
    required this.completedAt,
  });

  factory MeditationLog.fromMap(Map<String, dynamic> m) => MeditationLog(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        presetId: m['preset_id'] as String?,
        durationSeconds: (m['duration_seconds'] as num).toInt(),
        xpAwarded: (m['xp_awarded'] as num?)?.toInt() ?? 0,
        dpAwarded: (m['dp_awarded'] as num?)?.toInt() ?? 0,
        stateBefore: (m['state_before'] as num?)?.toInt(),
        stateAfter: (m['state_after'] as num?)?.toInt(),
        completedAt:
            DateTime.tryParse(m['completed_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'preset_id': presetId,
        'duration_seconds': durationSeconds,
        'xp_awarded': xpAwarded,
        'dp_awarded': dpAwarded,
        'state_before': stateBefore,
        'state_after': stateAfter,
        'completed_at': completedAt.toIso8601String(),
      };
}
