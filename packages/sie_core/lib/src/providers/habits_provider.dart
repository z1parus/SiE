import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit.dart';
import 'auth_state_provider.dart';
import 'user_profile_provider.dart';

String _fmt(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

class HabitsNotifier extends AutoDisposeAsyncNotifier<HabitsState> {
  @override
  Future<HabitsState> build() async {
    ref.watch(authStateProvider);
    return _load();
  }

  Future<HabitsState> _load() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return HabitsState.empty;

    final userId = session.user.id;
    final cutoff = _fmt(DateTime.now().subtract(const Duration(days: 30)));

    final habitsRaw = await client
        .from('habits')
        .select()
        .eq('user_id', userId)
        .order('created_at');

    final logsRaw = await client
        .from('habit_logs')
        .select('habit_id, completed_at')
        .eq('user_id', userId)
        .gte('completed_at', cutoff);

    final habits = habitsRaw.map((r) => Habit.fromMap(r)).toList()
      // Pinned habits always appear first; relative order within each group
      // is preserved (habitsRaw is already ordered by created_at).
      ..sort((a, b) {
        if (a.isPinned == b.isPinned) return 0;
        return a.isPinned ? -1 : 1;
      });

    final logDates = <String, Set<String>>{};
    for (final row in logsRaw) {
      final hId = row['habit_id']?.toString() ?? '';
      final date = row['completed_at']?.toString() ?? '';
      if (hId.isNotEmpty && date.isNotEmpty) {
        logDates.putIfAbsent(hId, () => {}).add(date);
      }
    }

    final streaks = <String, int>{
      for (final h in habits) h.id: _streak(logDates[h.id] ?? {}),
    };

    return HabitsState(habits: habits, logDates: logDates, streaks: streaks);
  }

  int _streak(Set<String> dates) {
    var n = 0;
    var day = DateTime.now();
    while (dates.contains(_fmt(day))) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  // Returns true if the first-habit achievement was just awarded.
  Future<bool> addHabit({
    required String title,
    String? description,
    String color = '#00C8FF',
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;

    final prev = state.valueOrNull;

    // Optimistic insert with a temporary ID
    if (prev != null) {
      final temp = Habit(
        id: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        title: title,
        description: description,
        color: color,
        createdAt: DateTime.now(),
      );
      state = AsyncData(HabitsState(
        habits: [...prev.habits, temp],
        logDates: prev.logDates,
        streaks: {...prev.streaks, temp.id: 0},
      ));
    }

    final isFirstHabit = prev?.habits.isEmpty ?? true;

    try {
      await client.from('habits').insert({
        'user_id': userId,
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'color': color,
      });
      state = AsyncData(await _load());
      if (isFirstHabit) {
        final awarded = await _tryAwardFirstHabit(client, userId);
        if (awarded) ref.invalidate(userProfileProvider);
        return awarded;
      }
      return false;
    } catch (e, st) {
      if (prev != null) state = AsyncData(prev);
      Error.throwWithStackTrace(e, st);
    }
    return false;
  }

  Future<void> updateHabit({
    required String habitId,
    required String title,
    String? description,
    required String color,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final prev = state.valueOrNull;
    if (prev == null) return;

    final idx = prev.habits.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;

    final updated = prev.habits[idx].copyWith(
      title: title,
      description: description,
      color: color,
    );
    final newHabits = [...prev.habits]..[idx] = updated;

    state = AsyncData(HabitsState(
      habits: newHabits,
      logDates: prev.logDates,
      streaks: prev.streaks,
    ));

    try {
      await client.from('habits').update({
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description
        else
          'description': null,
        'color': color,
      }).eq('id', habitId).eq('user_id', userId);
    } catch (e, st) {
      state = AsyncData(prev);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> deleteHabit(String habitId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final prev = state.valueOrNull;
    if (prev == null) return;

    final newHabits = prev.habits.where((h) => h.id != habitId).toList();
    final newLogDates = Map<String, Set<String>>.from(prev.logDates)
      ..remove(habitId);
    final newStreaks = Map<String, int>.from(prev.streaks)..remove(habitId);

    state = AsyncData(HabitsState(
      habits: newHabits,
      logDates: newLogDates,
      streaks: newStreaks,
    ));

    try {
      await client
          .from('habits')
          .delete()
          .eq('id', habitId)
          .eq('user_id', userId);
    } catch (e, st) {
      state = AsyncData(prev);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> togglePin(String habitId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final prev = state.valueOrNull;
    if (prev == null) return;

    final idx = prev.habits.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;

    final newPinned = !prev.habits[idx].isPinned;
    final updated = prev.habits[idx].copyWith(isPinned: newPinned);

    final newHabits = ([...prev.habits]..[idx] = updated)
      ..sort((a, b) {
        if (a.isPinned == b.isPinned) return 0;
        return a.isPinned ? -1 : 1;
      });

    state = AsyncData(HabitsState(
      habits: newHabits,
      logDates: prev.logDates,
      streaks: prev.streaks,
    ));

    try {
      await client
          .from('habits')
          .update({'is_pinned': newPinned})
          .eq('id', habitId)
          .eq('user_id', userId);
    } catch (e, st) {
      state = AsyncData(prev);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> toggleHabit(String habitId, DateTime date) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final dateStr = _fmt(date);
    final prev = state.valueOrNull;
    if (prev == null) return;

    final isDone = prev.logDates[habitId]?.contains(dateStr) ?? false;

    // Optimistic update
    final newLogDates = {
      for (final e in prev.logDates.entries) e.key: Set<String>.from(e.value),
    };
    final habitDates = newLogDates.putIfAbsent(habitId, () => {});
    if (isDone) {
      habitDates.remove(dateStr);
    } else {
      habitDates.add(dateStr);
    }

    state = AsyncData(HabitsState(
      habits: prev.habits,
      logDates: newLogDates,
      streaks: {...prev.streaks, habitId: _streak(habitDates)},
    ));

    try {
      if (isDone) {
        await client
            .from('habit_logs')
            .delete()
            .eq('habit_id', habitId)
            .eq('user_id', userId)
            .eq('completed_at', dateStr);
      } else {
        await client.from('habit_logs').insert({
          'habit_id': habitId,
          'user_id': userId,
          'completed_at': dateStr,
          'xp_awarded': 50,
        });
        await Future.wait([
          client.rpc('increment_xp', params: {
            'p_user_id': userId,
            'p_amount': 50,
          }),
          addDesignPoints(10),
        ]);
      }
    } catch (e, st) {
      state = AsyncData(prev);
      Error.throwWithStackTrace(e, st);
    }
  }
}

final habitsProvider =
    AsyncNotifierProvider.autoDispose<HabitsNotifier, HabitsState>(
  HabitsNotifier.new,
);

Future<bool> _tryAwardFirstHabit(
    SupabaseClient client, String userId) async {
  try {
    final achRow = await client
        .from('achievements')
        .select()
        .eq('slug', 'first_habit_created')
        .maybeSingle();
    if (achRow == null) return false;

    final already = await client
        .from('user_achievements')
        .select('id')
        .eq('user_id', userId)
        .eq('achievement_id', achRow['id'] as String)
        .maybeSingle();
    if (already != null) return false;

    final xpReward = achRow['xp_reward'] as int? ?? 25;
    await Future.wait([
      client.from('user_achievements').insert({
        'user_id': userId,
        'achievement_id': achRow['id'],
      }),
      client.rpc('increment_xp', params: {
        'p_user_id': userId,
        'p_amount': xpReward,
      }),
    ]);
    return true;
  } catch (e) {
    debugPrint('SiE Habits: first_habit achievement error — $e');
    return false;
  }
}
