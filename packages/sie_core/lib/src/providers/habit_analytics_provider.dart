import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit_analytics.dart';
import 'habits_provider.dart';

/// Per-habit analytics derived from the loaded habits state (no extra DB calls).
final habitAnalyticsProvider =
    Provider.autoDispose.family<HabitMetrics, String>((ref, habitId) {
  final state = ref.watch(habitsProvider).valueOrNull;
  if (state == null) return HabitMetrics.empty;

  final habit = state.habits.where((h) => h.id == habitId).firstOrNull;
  if (habit == null) return HabitMetrics.empty;

  return HabitMetrics.compute(
    habit,
    state.logDates[habitId] ?? const {},
    state.logValues[habitId] ?? const {},
  );
});

/// Aggregated dashboard across all active habits.
final habitsDashboardProvider =
    Provider.autoDispose<HabitsDashboard>((ref) {
  final state = ref.watch(habitsProvider).valueOrNull;
  if (state == null) return HabitsDashboard.empty;
  return HabitsDashboard.compute(state.habits, state.logDates);
});
