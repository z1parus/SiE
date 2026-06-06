import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/habit.dart';
import '../models/habit_log_entry.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';
import 'user_profile_provider.dart';

String _fmt(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

const _uuid = Uuid();
const _noChange = Object();

class HabitsNotifier extends AutoDisposeAsyncNotifier<HabitsState> {
  // Guards against concurrent toggles for the same habit+date (double-tap).
  final _inProgress = <String>{};
  // Guards against concurrent restores for the same habit (rapid tap).
  final _inProgressRestore = <String>{};

  @override
  Future<HabitsState> build() async {
    ref.watch(authStateProvider);
    ref.watch(connectivityProvider); // reload when connectivity changes
    return _load();
  }

  Future<HabitsState> _load() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return HabitsState.empty;

    final userId = session.user.id;
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final cutoff = _fmt(DateTime.now().subtract(const Duration(days: 366)));

    if (isOnline) {
      try {
        final habitsRaw = await client
            .from('habits')
            .select()
            .eq('user_id', userId)
            .eq('is_archived', false)
            .order('created_at');

        final logsRaw = await client
            .from('habit_logs')
            .select('habit_id, completed_at, note, emoji')
            .eq('user_id', userId)
            .gte('completed_at', cutoff);

        final allHabits = habitsRaw.map((r) => Habit.fromMap(r)).toList();
        final habits = (allHabits.where((h) => !h.isArchived).toList())
          ..sort((a, b) {
            if (a.isPinned == b.isPinned) return 0;
            return a.isPinned ? -1 : 1;
          });

        // Mirror to local DB.
        for (final h in allHabits) {
          await db.upsertHabit(LocalHabitsCompanion(
            id: Value(h.id),
            userId: Value(h.userId),
            title: Value(h.title),
            description: Value(h.description),
            color: Value(h.color),
            icon: Value(h.icon),
            isPinned: Value(h.isPinned),
            isArchived: Value(h.isArchived),
            createdAtMs: Value(h.createdAt.millisecondsSinceEpoch),
            synced: const Value(true),
          ));
        }

        final logDates = <String, Set<String>>{};
        final logEntries = <String, List<HabitLogEntry>>{};
        for (final row in logsRaw) {
          final hId = row['habit_id']?.toString() ?? '';
          final date = row['completed_at']?.toString() ?? '';
          if (hId.isNotEmpty && date.isNotEmpty) {
            logDates.putIfAbsent(hId, () => {}).add(date);
            final entry = HabitLogEntry.fromMap({...row, 'user_id': userId});
            logEntries.putIfAbsent(hId, () => []).add(entry);
            await db.upsertHabitLog(LocalHabitLogsCompanion(
              habitId: Value(hId),
              userId: Value(userId),
              completedAt: Value(date),
              note: Value(row['note']?.toString()),
              emoji: Value(row['emoji']?.toString()),
              synced: const Value(true),
            ));
          }
        }

        final streaks = <String, int>{
          for (final h in habits) h.id: _streak(logDates[h.id] ?? {}),
        };
        return HabitsState(
            habits: habits,
            logDates: logDates,
            streaks: streaks,
            logEntries: logEntries);
      } catch (e) {
        debugPrint('SiE Habits: online load failed, falling back to local — $e');
      }
    }

    // Offline (or online fetch failed) — read from local DB.
    final localHabits = await db.habitsForUser(userId);
    final localLogs = await db.habitLogsForUser(userId, cutoff);

    final habits = localHabits
        .map((h) => Habit(
              id: h.id,
              userId: h.userId,
              title: h.title,
              description: h.description,
              color: h.color,
              icon: h.icon,
              isPinned: h.isPinned,
              isArchived: h.isArchived,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(h.createdAtMs),
            ))
        .toList()
      ..sort((a, b) {
        if (a.isPinned == b.isPinned) return 0;
        return a.isPinned ? -1 : 1;
      });

    final logDates = <String, Set<String>>{};
    final logEntries = <String, List<HabitLogEntry>>{};
    for (final log in localLogs) {
      logDates.putIfAbsent(log.habitId, () => {}).add(log.completedAt);
      logEntries.putIfAbsent(log.habitId, () => []).add(HabitLogEntry(
            habitId: log.habitId,
            userId: log.userId,
            completedAt: log.completedAt,
            note: log.note,
            emoji: log.emoji,
          ));
    }

    final streaks = <String, int>{
      for (final h in habits) h.id: _streak(logDates[h.id] ?? {}),
    };
    return HabitsState(
        habits: habits,
        logDates: logDates,
        streaks: streaks,
        logEntries: logEntries);
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
    String? icon,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final habitId = _uuid.v4();
    final now = DateTime.now();
    final prev = state.valueOrNull;
    final isFirstHabit = prev?.habits.isEmpty ?? true;

    // Optimistic UI update.
    final optimistic = Habit(
      id: habitId,
      userId: userId,
      title: title,
      description: description,
      color: color,
      icon: icon,
      createdAt: now,
    );
    if (prev != null) {
      state = AsyncData(HabitsState(
        habits: [...prev.habits, optimistic],
        logDates: prev.logDates,
        streaks: {...prev.streaks, habitId: 0},
        logEntries: prev.logEntries,
      ));
    }

    // Always write to local DB first.
    await db.upsertHabit(LocalHabitsCompanion(
      id: Value(habitId),
      userId: Value(userId),
      title: Value(title),
      description: Value(description),
      color: Value(color),
      icon: Value(icon),
      createdAtMs: Value(now.millisecondsSinceEpoch),
      synced: Value(isOnline),
    ));

    try {
      if (isOnline) {
        await client.from('habits').insert({
          'id': habitId,
          'user_id': userId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'color': color,
          if (icon != null) 'icon': icon,
        });
        state = AsyncData(await _load());
        if (isFirstHabit) {
          final awarded = await _tryAwardFirstHabit(client, userId);
          return awarded;
        }
      } else {
        await db.enqueueSyncOp('insert_habit', jsonEncode({
          'id': habitId,
          'user_id': userId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'color': color,
          if (icon != null) 'icon': icon,
        }));
        state = AsyncData(await _load());
      }
      return false;
    } catch (e, st) {
      if (prev != null) state = AsyncData(prev);
      // Clean up orphaned local record so it doesn't linger unsynced.
      await db.markHabitDeleted(habitId);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> updateHabit({
    required String habitId,
    required String title,
    String? description,
    required String color,
    Object? icon = _noChange,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final prev = state.valueOrNull;
    if (prev == null) return;

    final idx = prev.habits.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;

    final updated = prev.habits[idx].copyWith(
      title: title,
      description: description,
      color: color,
      icon: icon,
    );
    final newHabits = [...prev.habits]..[idx] = updated;

    state = AsyncData(HabitsState(
      habits: newHabits,
      logDates: prev.logDates,
      streaks: prev.streaks,
      logEntries: prev.logEntries,
    ));

    final resolvedIcon = icon == _noChange ? updated.icon : icon as String?;
    // Update local DB.
    await db.upsertHabit(LocalHabitsCompanion(
      id: Value(habitId),
      userId: Value(userId),
      title: Value(title),
      description: Value(description?.isNotEmpty == true ? description : null),
      color: Value(color),
      icon: Value(resolvedIcon),
      createdAtMs: Value(
          prev.habits[idx].createdAt.millisecondsSinceEpoch),
      synced: Value(isOnline),
    ));

    try {
      if (isOnline) {
        await client.from('habits').update({
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description
          else
            'description': null,
          'color': color,
          if (resolvedIcon != null) 'icon': resolvedIcon,
        }).eq('id', habitId).eq('user_id', userId);
      } else {
        await db.enqueueSyncOp('update_habit', jsonEncode({
          'id': habitId,
          'title': title,
          'description':
              description?.isNotEmpty == true ? description : null,
          'color': color,
          if (resolvedIcon != null) 'icon': resolvedIcon,
        }));
      }
    } catch (e, st) {
      state = AsyncData(prev);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> deleteHabit(String habitId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final prev = state.valueOrNull;
    if (prev == null) return;

    final newHabits = prev.habits.where((h) => h.id != habitId).toList();
    final newLogDates = Map<String, Set<String>>.from(prev.logDates)
      ..remove(habitId);
    final newStreaks = Map<String, int>.from(prev.streaks)
      ..remove(habitId);
    final newLogEntriesDel =
        Map<String, List<HabitLogEntry>>.from(prev.logEntries)
          ..remove(habitId);

    state = AsyncData(HabitsState(
      habits: newHabits,
      logDates: newLogDates,
      streaks: newStreaks,
      logEntries: newLogEntriesDel,
    ));

    await db.markHabitDeleted(habitId);

    try {
      if (isOnline) {
        await client
            .from('habits')
            .delete()
            .eq('id', habitId)
            .eq('user_id', userId);
      } else {
        await db.enqueueSyncOp('delete_habit',
            jsonEncode({'id': habitId, 'user_id': userId}));
      }
    } catch (e, st) {
      state = AsyncData(prev);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> togglePin(String habitId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
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
      logEntries: prev.logEntries,
    ));

    await db.upsertHabit(LocalHabitsCompanion(
      id: Value(habitId),
      userId: Value(userId),
      title: Value(prev.habits[idx].title),
      description: Value(prev.habits[idx].description),
      color: Value(prev.habits[idx].color),
      icon: Value(prev.habits[idx].icon),
      isPinned: Value(newPinned),
      createdAtMs:
          Value(prev.habits[idx].createdAt.millisecondsSinceEpoch),
      synced: Value(isOnline),
    ));

    try {
      if (isOnline) {
        await client
            .from('habits')
            .update({'is_pinned': newPinned})
            .eq('id', habitId)
            .eq('user_id', userId);
      } else {
        await db.enqueueSyncOp('update_habit', jsonEncode({
          'id': habitId,
          'is_pinned': newPinned,
        }));
      }
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
    final toggleKey = '$habitId-$dateStr';
    if (_inProgress.contains(toggleKey)) return;
    _inProgress.add(toggleKey);

    final prev = state.valueOrNull;
    if (prev == null) {
      _inProgress.remove(toggleKey);
      return;
    }

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final isDone = prev.logDates[habitId]?.contains(dateStr) ?? false;

    // Write to local DB first to prevent race condition on rapid double-tap.
    if (isDone) {
      await db.deleteHabitLog(habitId, userId, dateStr);
    } else {
      await db.upsertHabitLog(LocalHabitLogsCompanion(
        habitId: Value(habitId),
        userId: Value(userId),
        completedAt: Value(dateStr),
        note: const Value(null),
        emoji: const Value(null),
        synced: Value(isOnline),
      ));
    }

    // Optimistic UI update (now consistent with local DB).
    final newLogDates = {
      for (final e in prev.logDates.entries)
        e.key: Set<String>.from(e.value),
    };
    final habitDates = newLogDates.putIfAbsent(habitId, () => {});

    final newLogEntries = {
      for (final e in prev.logEntries.entries)
        e.key: List<HabitLogEntry>.from(e.value),
    };
    if (isDone) {
      habitDates.remove(dateStr);
      newLogEntries[habitId]?.removeWhere((e) => e.completedAt == dateStr);
    } else {
      habitDates.add(dateStr);
      newLogEntries
          .putIfAbsent(habitId, () => [])
          .add(HabitLogEntry(
              habitId: habitId, userId: userId, completedAt: dateStr));
    }

    state = AsyncData(HabitsState(
      habits: prev.habits,
      logDates: newLogDates,
      streaks: {...prev.streaks, habitId: _streak(habitDates)},
      logEntries: newLogEntries,
    ));

    try {
      if (isDone) {
        if (isOnline) {
          await client
              .from('habit_logs')
              .delete()
              .eq('habit_id', habitId)
              .eq('user_id', userId)
              .eq('completed_at', dateStr);
        } else {
          await db.enqueueSyncOp('delete_habit_log', jsonEncode({
            'habit_id': habitId,
            'user_id': userId,
            'completed_at': dateStr,
          }));
        }
      } else {
        if (isOnline) {
          try {
            await client.from('habit_logs').insert({
              'habit_id': habitId,
              'user_id': userId,
              'completed_at': dateStr,
              'xp_awarded': 50,
            });
          } on PostgrestException catch (e) {
            // 23505 = unique_violation: log already exists, treat as no-op.
            if (e.code != '23505') rethrow;
            _inProgress.remove(toggleKey);
            return;
          }
          await Future.wait([
            client.rpc('increment_xp',
                params: {'p_user_id': userId, 'p_amount': 50}),
            client.rpc('add_design_points', params: {'p_amount': 10}),
          ]);
        } else {
          await db.enqueueSyncOp('insert_habit_log', jsonEncode({
            'habit_id': habitId,
            'user_id': userId,
            'completed_at': dateStr,
          }));
        }
        // Always update local XP immediately (online: mirrors server;
        // offline: accumulates pending delta for later sync).
        await ref
            .read(userProfileProvider.notifier)
            .applyLocalXpDelta(50, 10);
      }
    } catch (e, st) {
      state = AsyncData(prev);
      _inProgress.remove(toggleKey);
      Error.throwWithStackTrace(e, st);
    }
    _inProgress.remove(toggleKey);
  }

  Future<void> archiveHabit(String habitId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final prev = state.valueOrNull;
    if (prev == null) return;

    final habit = prev.habits.firstWhere((h) => h.id == habitId,
        orElse: () => throw StateError('habit not found'));

    final newHabits = prev.habits.where((h) => h.id != habitId).toList();
    final newLogDates = Map<String, Set<String>>.from(prev.logDates)..remove(habitId);
    final newStreaks   = Map<String, int>.from(prev.streaks)..remove(habitId);
    final newLogEntriesArc =
        Map<String, List<HabitLogEntry>>.from(prev.logEntries)
          ..remove(habitId);

    state = AsyncData(HabitsState(
      habits: newHabits,
      logDates: newLogDates,
      streaks: newStreaks,
      logEntries: newLogEntriesArc,
    ));

    await db.upsertHabit(LocalHabitsCompanion(
      id: Value(habitId),
      userId: Value(userId),
      title: Value(habit.title),
      description: Value(habit.description),
      color: Value(habit.color),
      icon: Value(habit.icon),
      isPinned: Value(habit.isPinned),
      isArchived: const Value(true),
      createdAtMs: Value(habit.createdAt.millisecondsSinceEpoch),
      synced: Value(isOnline),
    ));

    try {
      if (isOnline) {
        await client
            .from('habits')
            .update({'is_archived': true})
            .eq('id', habitId)
            .eq('user_id', userId);
      } else {
        await db.enqueueSyncOp('archive_habit',
            jsonEncode({'id': habitId, 'user_id': userId}));
      }
    } catch (e) {
      await db.enqueueSyncOp('archive_habit',
          jsonEncode({'id': habitId, 'user_id': userId}));
      debugPrint('SiE archiveHabit: Supabase failed, queued — $e');
    }
  }

  Future<void> updateHabitLog({
    required String habitId,
    required DateTime date,
    String? note,
    String? emoji,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final dateStr = _fmt(date);
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final prev = state.valueOrNull;
    if (prev == null) return;

    // Optimistic update of logEntries.
    final updatedEntries = {
      for (final e in prev.logEntries.entries)
        e.key: List<HabitLogEntry>.from(e.value),
    };
    final list = updatedEntries.putIfAbsent(habitId, () => []);
    final idx = list.indexWhere((e) => e.completedAt == dateStr);
    final updated = HabitLogEntry(
      habitId: habitId,
      userId: userId,
      completedAt: dateStr,
      note: note,
      emoji: emoji,
    );
    if (idx >= 0) {
      list[idx] = updated;
    } else {
      list.add(updated);
    }

    // If this is a brand-new entry (e.g. toggleHabit failed remotely but wrote
    // to local DB), also mark the date in logDates so the card shows completed.
    final updatedLogDates = {
      for (final e in prev.logDates.entries)
        e.key: Set<String>.from(e.value),
    };
    if (idx < 0) {
      updatedLogDates.putIfAbsent(habitId, () => {}).add(dateStr);
    }

    state = AsyncData(HabitsState(
      habits: prev.habits,
      logDates: updatedLogDates,
      streaks: idx < 0
          ? {...prev.streaks, habitId: _streak(updatedLogDates[habitId] ?? {})}
          : prev.streaks,
      logEntries: updatedEntries,
    ));

    // Upsert to local DB so note/emoji persist even if the remote call fails.
    await db.upsertHabitLog(LocalHabitLogsCompanion(
      habitId: Value(habitId),
      userId: Value(userId),
      completedAt: Value(dateStr),
      note: Value(note),
      emoji: Value(emoji),
      synced: const Value(false),
    ));

    try {
      if (isOnline) {
        await client.from('habit_logs').update({
          'note': note,
          'emoji': emoji,
        }).eq('habit_id', habitId).eq('user_id', userId).eq('completed_at', dateStr);
        await db.markHabitLogSynced(habitId, userId, dateStr);
      } else {
        await db.enqueueSyncOp(
            'update_habit_log',
            jsonEncode({
              'habit_id': habitId,
              'user_id': userId,
              'completed_at': dateStr,
              'note': note,
              'emoji': emoji,
            }));
      }
    } catch (e) {
      // Remote sync failed — data is safe in local DB, queue for later.
      debugPrint('SiE updateHabitLog: sync failed, queuing — $e');
      try {
        await db.enqueueSyncOp(
            'update_habit_log',
            jsonEncode({
              'habit_id': habitId,
              'user_id': userId,
              'completed_at': dateStr,
              'note': note,
              'emoji': emoji,
            }));
      } catch (_) {}
    }
  }

  Future<void> restoreHabit(Habit habit) async {
    if (_inProgressRestore.contains(habit.id)) return;
    _inProgressRestore.add(habit.id);
    try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final prev = state.valueOrNull;
    if (prev == null) return;

    final restored = habit.copyWith(isArchived: false);
    final newHabits = [...prev.habits, restored]
      ..sort((a, b) {
        if (a.isPinned == b.isPinned) return 0;
        return a.isPinned ? -1 : 1;
      });

    state = AsyncData(HabitsState(
      habits: newHabits,
      logDates: prev.logDates,
      streaks: {...prev.streaks, habit.id: 0},
      logEntries: prev.logEntries,
    ));

    await db.upsertHabit(LocalHabitsCompanion(
      id: Value(habit.id),
      userId: Value(userId),
      title: Value(habit.title),
      description: Value(habit.description),
      color: Value(habit.color),
      icon: Value(habit.icon),
      isPinned: Value(habit.isPinned),
      isArchived: const Value(false),
      createdAtMs: Value(habit.createdAt.millisecondsSinceEpoch),
      synced: Value(isOnline),
    ));

    try {
      if (isOnline) {
        await client
            .from('habits')
            .update({'is_archived': false})
            .eq('id', habit.id)
            .eq('user_id', userId);
      } else {
        await db.enqueueSyncOp('restore_habit',
            jsonEncode({'id': habit.id, 'user_id': userId}));
      }
    } catch (e, st) {
      // Rollback — remove from active list
      final rollback = prev.habits.where((h) => h.id != habit.id).toList();
      state = AsyncData(HabitsState(
        habits: rollback,
        logDates: prev.logDates,
        streaks: prev.streaks,
        logEntries: prev.logEntries,
      ));
      Error.throwWithStackTrace(e, st);
    }
    } finally {
      _inProgressRestore.remove(habit.id);
    }
  }
}

final habitsProvider =
    AsyncNotifierProvider.autoDispose<HabitsNotifier, HabitsState>(
  HabitsNotifier.new,
);

final archivedHabitsProvider =
    AutoDisposeFutureProvider<List<Habit>>((ref) async {
  ref.watch(authStateProvider);
  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  if (session == null) return [];

  final userId = session.user.id;
  final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
  final db = ref.read(appDatabaseProvider);

  if (isOnline) {
    try {
      final rows = await client
          .from('habits')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', true)
          .order('created_at', ascending: false);
      return rows.map((r) => Habit.fromMap(r)).toList();
    } catch (_) {
      // fall through to local
    }
  }

  final local = await db.archivedHabitsForUser(userId);
  return local
      .map((h) => Habit(
            id: h.id,
            userId: h.userId,
            title: h.title,
            description: h.description,
            color: h.color,
            icon: h.icon,
            isPinned: h.isPinned,
            isArchived: true,
            createdAt: DateTime.fromMillisecondsSinceEpoch(h.createdAtMs),
          ))
      .toList();
});

/// All log entries for a single habit (used by HabitDetailScreen timeline).
/// Falls back to local DB when offline.
final habitLogEntriesProvider =
    FutureProvider.autoDispose.family<List<HabitLogEntry>, String>(
  (ref, habitId) async {
    ref.watch(authStateProvider);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);

    if (isOnline) {
      try {
        final rows = await client
            .from('habit_logs')
            .select('habit_id, user_id, completed_at, note, emoji')
            .eq('habit_id', habitId)
            .eq('user_id', userId)
            .order('completed_at', ascending: false);
        return rows.map((r) => HabitLogEntry.fromMap(r)).toList();
      } catch (_) {
        // fall through to local
      }
    }

    final local = await db.habitLogsForHabit(habitId, userId);
    return local
        .map((l) => HabitLogEntry(
              habitId: l.habitId,
              userId: l.userId,
              completedAt: l.completedAt,
              note: l.note,
              emoji: l.emoji,
            ))
        .toList();
  },
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
      client.rpc('increment_xp',
          params: {'p_user_id': userId, 'p_amount': xpReward}),
    ]);
    return true;
  } catch (e) {
    debugPrint('SiE Habits: first_habit achievement error — $e');
    return false;
  }
}
