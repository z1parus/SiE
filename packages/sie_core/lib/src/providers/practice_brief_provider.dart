import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';

/// Summary of a single practice module (focus / breathing / meditation) for the
/// Operational Brief: when the last session happened and how long it ran.
class PracticeBriefEntry {
  final DateTime? lastAt;
  final int lastDurationSeconds;

  const PracticeBriefEntry({this.lastAt, this.lastDurationSeconds = 0});

  bool get hasSessions => lastAt != null;
}

/// Latest-session summaries for the three practice modules, read from the local
/// Drift cache (offline-first — sessions are mirrored locally on completion).
class PracticeBriefData {
  final PracticeBriefEntry focus;
  final PracticeBriefEntry breathing;
  final PracticeBriefEntry meditation;

  const PracticeBriefData({
    required this.focus,
    required this.breathing,
    required this.meditation,
  });

  static const empty = PracticeBriefData(
    focus: PracticeBriefEntry(),
    breathing: PracticeBriefEntry(),
    meditation: PracticeBriefEntry(),
  );
}

PracticeBriefEntry _entry(int? durationSeconds, int? completedAtMs) {
  if (completedAtMs == null) return const PracticeBriefEntry();
  return PracticeBriefEntry(
    lastAt: DateTime.fromMillisecondsSinceEpoch(completedAtMs),
    lastDurationSeconds: durationSeconds ?? 0,
  );
}

/// Aggregates the most recent focus / breathing / meditation session for the
/// brief. Auto-disposes with the brief view; re-reads on rebuild so returning
/// to the screen after a session reflects the new "last session".
final practiceBriefProvider =
    FutureProvider.autoDispose<PracticeBriefData>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final focus = await db.latestFocusSession();
  final breathing = await db.latestBreathingSession();
  final meditation = await db.latestMeditationSession();
  return PracticeBriefData(
    focus: _entry(focus?.durationSeconds, focus?.completedAtMs),
    breathing: _entry(breathing?.durationSeconds, breathing?.completedAtMs),
    meditation: _entry(meditation?.durationSeconds, meditation?.completedAtMs),
  );
});
