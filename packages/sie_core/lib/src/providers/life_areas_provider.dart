import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import '../models/life_area.dart';

/// Ecosystem Pillar 3 — cross-module rollup by life area.
///
/// Aggregates, per [LifeArea], how much of the user's life is invested there:
/// habits and active goals tagged with the area, plus practice/focus sessions
/// over the last 7 days. Focus sessions inherit their goal's area; breathing
/// and meditation fall back to a sensible module default.
class LifeAreaStat {
  final int habits;
  final int goals;
  final int sessions;
  final int minutes;
  const LifeAreaStat({
    this.habits = 0,
    this.goals = 0,
    this.sessions = 0,
    this.minutes = 0,
  });

  /// A simple "how alive is this area" score for balance comparisons.
  int get score => habits * 2 + goals * 2 + sessions;

  LifeAreaStat copyAdd({int habits = 0, int goals = 0, int sessions = 0, int minutes = 0}) =>
      LifeAreaStat(
        habits: this.habits + habits,
        goals: this.goals + goals,
        sessions: this.sessions + sessions,
        minutes: this.minutes + minutes,
      );
}

class LifeAreasData {
  final Map<LifeArea, LifeAreaStat> byArea;
  const LifeAreasData(this.byArea);

  LifeAreaStat statFor(LifeArea a) => byArea[a] ?? const LifeAreaStat();

  int get maxScore =>
      byArea.values.fold(0, (m, s) => s.score > m ? s.score : m);

  bool get hasAnyActivity => byArea.values.any((s) => s.score > 0);

  /// The most neglected area — only surfaced when there *is* activity elsewhere
  /// (so we never nag an empty profile). Null when nothing to suggest.
  LifeArea? get neglected {
    if (!hasAnyActivity) return null;
    LifeArea? worst;
    int worstScore = 1 << 30;
    for (final a in LifeArea.values) {
      final s = statFor(a).score;
      if (s < worstScore) {
        worstScore = s;
        worst = a;
      }
    }
    // Only flag a real imbalance: neglected area is clearly behind the leader.
    return (worstScore == 0 && maxScore >= 3) ? worst : null;
  }
}

/// Default area for a module's practice session when there's no goal context.
const LifeArea _kBreathingArea = LifeArea.health;
const LifeArea _kMeditationArea = LifeArea.spirit;

final lifeAreasProvider = FutureProvider.autoDispose<LifeAreasData>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final map = <LifeArea, LifeAreaStat>{
    for (final a in LifeArea.values) a: const LifeAreaStat(),
  };
  void add(LifeArea? area,
      {int habits = 0, int goals = 0, int sessions = 0, int minutes = 0}) {
    if (area == null) return;
    map[area] = (map[area] ?? const LifeAreaStat())
        .copyAdd(habits: habits, goals: goals, sessions: sessions, minutes: minutes);
  }

  // Habits (already carry an area).
  final habits = await db.habitsForWidget();
  for (final h in habits) {
    add(LifeAreaX.fromString(h.area), habits: 1);
  }

  // Active goals (area added in this stage). Build a goalId → area map so focus
  // sessions can inherit it.
  final goals = await db.goalsForWidget();
  final goalArea = <String, LifeArea?>{};
  for (final g in goals) {
    final a = LifeAreaX.fromString(g.area);
    goalArea[g.id] = a;
    add(a, goals: 1);
  }

  // Sessions over the last 7 days.
  final sinceMs =
      DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;

  final focus = await db.focusSessionsSince(sinceMs);
  for (final f in focus) {
    final a = f.goalId != null ? goalArea[f.goalId] : null;
    add(a, sessions: 1, minutes: f.durationSeconds ~/ 60);
  }

  final breathing = await db.breathingSessionsForWidget();
  for (final b in breathing.where((s) => s.completedAtMs >= sinceMs)) {
    add(_kBreathingArea, sessions: 1, minutes: b.durationSeconds ~/ 60);
  }

  final meditation = await db.meditationSessionsForWidget();
  for (final m in meditation.where((s) => s.completedAtMs >= sinceMs)) {
    add(_kMeditationArea, sessions: 1, minutes: m.durationSeconds ~/ 60);
  }

  return LifeAreasData(map);
});
