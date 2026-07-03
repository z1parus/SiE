import 'dart:convert';

/// Quick Wim-Hof-style breathing parameters embedded in a meditation preset
/// (the "быстрые параметры" mode). When a preset instead points at a saved
/// [breathingSequenceId], this is ignored.
class MeditationBreathingConfig {
  final int rounds;
  final int cyclesPerRound;
  final int inhaleSecs;
  final int exhaleSecs;
  final int exhaustRetentionSecs;
  final int recoveryHoldSecs;

  const MeditationBreathingConfig({
    this.rounds = 3,
    this.cyclesPerRound = 30,
    this.inhaleSecs = 2,
    this.exhaleSecs = 2,
    this.exhaustRetentionSecs = 90,
    this.recoveryHoldSecs = 15,
  });

  MeditationBreathingConfig copyWith({
    int? rounds,
    int? cyclesPerRound,
    int? inhaleSecs,
    int? exhaleSecs,
    int? exhaustRetentionSecs,
    int? recoveryHoldSecs,
  }) =>
      MeditationBreathingConfig(
        rounds: rounds ?? this.rounds,
        cyclesPerRound: cyclesPerRound ?? this.cyclesPerRound,
        inhaleSecs: inhaleSecs ?? this.inhaleSecs,
        exhaleSecs: exhaleSecs ?? this.exhaleSecs,
        exhaustRetentionSecs: exhaustRetentionSecs ?? this.exhaustRetentionSecs,
        recoveryHoldSecs: recoveryHoldSecs ?? this.recoveryHoldSecs,
      );

  Map<String, dynamic> toMap() => {
        'rounds': rounds,
        'cycles_per_round': cyclesPerRound,
        'inhale_secs': inhaleSecs,
        'exhale_secs': exhaleSecs,
        'exhaust_retention_secs': exhaustRetentionSecs,
        'recovery_hold_secs': recoveryHoldSecs,
      };

  factory MeditationBreathingConfig.fromMap(Map<String, dynamic> m) =>
      MeditationBreathingConfig(
        rounds: (m['rounds'] as num?)?.toInt() ?? 3,
        cyclesPerRound: (m['cycles_per_round'] as num?)?.toInt() ?? 30,
        inhaleSecs: (m['inhale_secs'] as num?)?.toInt() ?? 2,
        exhaleSecs: (m['exhale_secs'] as num?)?.toInt() ?? 2,
        exhaustRetentionSecs: (m['exhaust_retention_secs'] as num?)?.toInt() ?? 90,
        recoveryHoldSecs: (m['recovery_hold_secs'] as num?)?.toInt() ?? 15,
      );

  String toJsonString() => jsonEncode(toMap());

  static MeditationBreathingConfig fromJsonString(String? s) {
    if (s == null || s.isEmpty) return const MeditationBreathingConfig();
    try {
      return MeditationBreathingConfig.fromMap(
          jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const MeditationBreathingConfig();
    }
  }

  /// Rough estimate of how long the breathing block runs, in minutes — used
  /// only for display/total-duration hints (actual length varies with holds).
  int get estimatedMinutes {
    final perRound =
        cyclesPerRound * (inhaleSecs + exhaleSecs) + exhaustRetentionSecs + recoveryHoldSecs;
    return ((rounds * perRound) / 60).ceil().clamp(1, 120);
  }
}

class MeditationPreset {
  final String id;
  final String? userId;
  final String name;
  final String? description;
  final bool isSystem;
  final bool hasBreathing;
  // ── Preliminary breathing (Ecosystem Stage 1) ───────────────────────────────
  // Either a reference to a saved breathing sequence, or embedded quick params
  // in [breathingConfigJson]. When both are null a default quick config is used.
  final String? breathingSequenceId;
  final String? breathingConfigJson;
  // ── Legacy paced-pattern fields (deprecated, kept for schema compat) ─────────
  final String? breathingPatternId; // legacy: 'box' | '4-7-8' | 'coherence'
  final int breathingDurationMin;
  final String meditationType; // 'unguided' | 'affirmations'
  final int meditationDurationMin;
  final String? baseMusicId;
  final String? ambientFxId;
  final double baseVolume;
  final double ambientVolume;
  final double voiceVolume;
  final String? affirmationPackId;
  final int affirmationIntervalSecs;
  final DateTime createdAt;

  const MeditationPreset({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.isSystem = false,
    this.hasBreathing = false,
    this.breathingSequenceId,
    this.breathingConfigJson,
    this.breathingPatternId,
    this.breathingDurationMin = 5,
    this.meditationType = 'unguided',
    this.meditationDurationMin = 15,
    this.baseMusicId,
    this.ambientFxId,
    this.baseVolume = 0.7,
    this.ambientVolume = 0.5,
    this.voiceVolume = 0.6,
    this.affirmationPackId,
    this.affirmationIntervalSecs = 30,
    required this.createdAt,
  });

  /// The quick breathing params for this preset (used when no [breathingSequenceId]).
  MeditationBreathingConfig get breathingQuickConfig =>
      MeditationBreathingConfig.fromJsonString(breathingConfigJson);

  /// True when the breathing block runs a saved sequence rather than quick params.
  bool get usesBreathingSequence =>
      breathingSequenceId != null && breathingSequenceId!.isNotEmpty;

  int get totalDurationMin =>
      (hasBreathing && !usesBreathingSequence
          ? breathingQuickConfig.estimatedMinutes
          : 0) +
      meditationDurationMin;

  factory MeditationPreset.fromMap(Map<String, dynamic> m) => MeditationPreset(
        id: m['id'] as String,
        userId: m['user_id'] as String?,
        name: m['name'] as String,
        description: m['description'] as String?,
        isSystem: m['is_system'] as bool? ?? false,
        hasBreathing: m['has_breathing'] as bool? ?? false,
        breathingSequenceId: m['breathing_sequence_id'] as String?,
        breathingConfigJson: m['breathing_config_json'] as String?,
        breathingPatternId: m['breathing_pattern_id'] as String?,
        breathingDurationMin:
            (m['breathing_duration_min'] as num?)?.toInt() ?? 5,
        meditationType: m['meditation_type'] as String? ?? 'unguided',
        meditationDurationMin:
            (m['meditation_duration_min'] as num?)?.toInt() ?? 15,
        baseMusicId: m['base_music_id'] as String?,
        ambientFxId: m['ambient_fx_id'] as String?,
        baseVolume: (m['base_volume'] as num?)?.toDouble() ?? 0.7,
        ambientVolume: (m['ambient_volume'] as num?)?.toDouble() ?? 0.5,
        voiceVolume: (m['voice_volume'] as num?)?.toDouble() ?? 0.6,
        affirmationPackId: m['affirmation_pack_id'] as String?,
        affirmationIntervalSecs:
            (m['affirmation_interval_secs'] as num?)?.toInt() ?? 30,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'description': description,
        'is_system': isSystem,
        'has_breathing': hasBreathing,
        'breathing_sequence_id': breathingSequenceId,
        'breathing_config_json': breathingConfigJson,
        'breathing_pattern_id': breathingPatternId,
        'breathing_duration_min': breathingDurationMin,
        'meditation_type': meditationType,
        'meditation_duration_min': meditationDurationMin,
        'base_music_id': baseMusicId,
        'ambient_fx_id': ambientFxId,
        'base_volume': baseVolume,
        'ambient_volume': ambientVolume,
        'voice_volume': voiceVolume,
        'affirmation_pack_id': affirmationPackId,
        'affirmation_interval_secs': affirmationIntervalSecs,
        'created_at': createdAt.toIso8601String(),
      };

  MeditationPreset copyWith({
    String? id,
    Object? userId = _sentinel,
    String? name,
    Object? description = _sentinel,
    bool? isSystem,
    bool? hasBreathing,
    Object? breathingSequenceId = _sentinel,
    Object? breathingConfigJson = _sentinel,
    Object? breathingPatternId = _sentinel,
    int? breathingDurationMin,
    String? meditationType,
    int? meditationDurationMin,
    Object? baseMusicId = _sentinel,
    Object? ambientFxId = _sentinel,
    double? baseVolume,
    double? ambientVolume,
    double? voiceVolume,
    Object? affirmationPackId = _sentinel,
    int? affirmationIntervalSecs,
    DateTime? createdAt,
  }) =>
      MeditationPreset(
        id: id ?? this.id,
        userId: identical(userId, _sentinel) ? this.userId : userId as String?,
        name: name ?? this.name,
        description: identical(description, _sentinel)
            ? this.description
            : description as String?,
        isSystem: isSystem ?? this.isSystem,
        hasBreathing: hasBreathing ?? this.hasBreathing,
        breathingSequenceId: identical(breathingSequenceId, _sentinel)
            ? this.breathingSequenceId
            : breathingSequenceId as String?,
        breathingConfigJson: identical(breathingConfigJson, _sentinel)
            ? this.breathingConfigJson
            : breathingConfigJson as String?,
        breathingPatternId: identical(breathingPatternId, _sentinel)
            ? this.breathingPatternId
            : breathingPatternId as String?,
        breathingDurationMin: breathingDurationMin ?? this.breathingDurationMin,
        meditationType: meditationType ?? this.meditationType,
        meditationDurationMin:
            meditationDurationMin ?? this.meditationDurationMin,
        baseMusicId: identical(baseMusicId, _sentinel)
            ? this.baseMusicId
            : baseMusicId as String?,
        ambientFxId: identical(ambientFxId, _sentinel)
            ? this.ambientFxId
            : ambientFxId as String?,
        baseVolume: baseVolume ?? this.baseVolume,
        ambientVolume: ambientVolume ?? this.ambientVolume,
        voiceVolume: voiceVolume ?? this.voiceVolume,
        affirmationPackId: identical(affirmationPackId, _sentinel)
            ? this.affirmationPackId
            : affirmationPackId as String?,
        affirmationIntervalSecs:
            affirmationIntervalSecs ?? this.affirmationIntervalSecs,
        createdAt: createdAt ?? this.createdAt,
      );
}

const _sentinel = Object();
