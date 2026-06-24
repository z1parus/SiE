import 'dart:convert';

/// A single round of a breathing session. Mirrors the per-round parameters of
/// the legacy uniform `BreathingSettings`, but each round in a [BreathingSequence]
/// carries its own values so a session can vary round-to-round.
class BreathingRound {
  final int cyclesPerRound;
  final int inhaleSecs;
  final int exhaleSecs;
  final int exhaustRetentionSecs; // hold after exhale
  final int recoveryHoldSecs;     // hold after recovery inhale

  const BreathingRound({
    this.cyclesPerRound = 30,
    this.inhaleSecs = 2,
    this.exhaleSecs = 2,
    this.exhaustRetentionSecs = 90,
    this.recoveryHoldSecs = 15,
  });

  BreathingRound copyWith({
    int? cyclesPerRound,
    int? inhaleSecs,
    int? exhaleSecs,
    int? exhaustRetentionSecs,
    int? recoveryHoldSecs,
  }) =>
      BreathingRound(
        cyclesPerRound: cyclesPerRound ?? this.cyclesPerRound,
        inhaleSecs: inhaleSecs ?? this.inhaleSecs,
        exhaleSecs: exhaleSecs ?? this.exhaleSecs,
        exhaustRetentionSecs: exhaustRetentionSecs ?? this.exhaustRetentionSecs,
        recoveryHoldSecs: recoveryHoldSecs ?? this.recoveryHoldSecs,
      );

  /// Approximate duration of this round in seconds: breathing cycles + the
  /// exhale-retention hold + the recovery inhale (~3s) and its hold.
  int get estimatedSeconds =>
      cyclesPerRound * (inhaleSecs + exhaleSecs) +
      exhaustRetentionSecs +
      3 +
      recoveryHoldSecs;

  Map<String, dynamic> toJson() => {
        'cyclesPerRound': cyclesPerRound,
        'inhaleSecs': inhaleSecs,
        'exhaleSecs': exhaleSecs,
        'exhaustRetentionSecs': exhaustRetentionSecs,
        'recoveryHoldSecs': recoveryHoldSecs,
      };

  factory BreathingRound.fromJson(Map<String, dynamic> j) => BreathingRound(
        cyclesPerRound: (j['cyclesPerRound'] as num?)?.toInt().clamp(5, 60) ?? 30,
        inhaleSecs: (j['inhaleSecs'] as num?)?.toInt().clamp(1, 10) ?? 2,
        exhaleSecs: (j['exhaleSecs'] as num?)?.toInt().clamp(1, 10) ?? 2,
        exhaustRetentionSecs:
            (j['exhaustRetentionSecs'] as num?)?.toInt().clamp(10, 300) ?? 90,
        recoveryHoldSecs:
            (j['recoveryHoldSecs'] as num?)?.toInt().clamp(5, 120) ?? 15,
      );
}

/// A named, user-built sequence of breathing rounds. Synced to Supabase
/// (`breathing_sequences`) and cached locally for offline use.
class BreathingSequence {
  final String id;
  final String userId;
  final String name;
  final List<BreathingRound> rounds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BreathingSequence({
    required this.id,
    required this.userId,
    required this.name,
    required this.rounds,
    required this.createdAt,
    required this.updatedAt,
  });

  int get roundCount => rounds.length;
  int get totalCycles => rounds.fold(0, (s, r) => s + r.cyclesPerRound);
  int get estimatedSeconds => rounds.fold(0, (s, r) => s + r.estimatedSeconds);

  BreathingSequence copyWith({
    String? name,
    List<BreathingRound>? rounds,
    DateTime? updatedAt,
  }) =>
      BreathingSequence(
        id: id,
        userId: userId,
        name: name ?? this.name,
        rounds: rounds ?? this.rounds,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static List<BreathingRound> roundsFromRaw(Object? raw) {
    final List list;
    if (raw is String) {
      list = jsonDecode(raw) as List;
    } else if (raw is List) {
      list = raw;
    } else {
      return const [];
    }
    return list
        .map((e) => BreathingRound.fromJson(
            (e as Map).map((k, v) => MapEntry(k.toString(), v))))
        .toList();
  }

  factory BreathingSequence.fromMap(Map<String, dynamic> m) => BreathingSequence(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String? ?? '',
        rounds: roundsFromRaw(m['rounds']),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toUpsertJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'rounds': rounds.map((r) => r.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  String roundsJsonString() =>
      jsonEncode(rounds.map((r) => r.toJson()).toList());
}
