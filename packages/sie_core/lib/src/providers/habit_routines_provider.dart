import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../models/habit.dart';
import '../models/habit_routine.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';

const _uuid = Uuid();

class HabitRoutinesNotifier
    extends AutoDisposeAsyncNotifier<HabitRoutinesState> {
  @override
  Future<HabitRoutinesState> build() async {
    ref.watch(authStateProvider);
    ref.watch(connectivityProvider);
    return _load();
  }

  Future<HabitRoutinesState> _load() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return HabitRoutinesState.empty;

    final userId   = session.user.id;
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db       = ref.read(appDatabaseProvider);

    if (isOnline) {
      try {
        // O2: single nested query instead of N+1 round-trips.
        final routinesRaw = await client
            .from('habit_routines')
            .select(
              'id, routine_type, created_at, '
              'habit_routine_members(id, habit_id, position, habits(*))',
            )
            .eq('user_id', userId);

        HabitRoutine? morning;
        HabitRoutine? evening;

        for (final row in routinesRaw) {
          final rId   = row['id'] as String;
          final rType = row['routine_type'] as String;
          final rAt   = DateTime.parse(row['created_at'] as String);

          await db.upsertRoutine(LocalRoutinesCompanion(
            id:          Value(rId),
            userId:      Value(userId),
            routineType: Value(rType),
            createdAtMs: Value(rAt.millisecondsSinceEpoch),
            synced:      const Value(true),
          ));

          // Sort members by position client-side (nested select has no order).
          final membersRaw = (row['habit_routine_members'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
            ..sort((a, b) =>
                (a['position'] as int).compareTo(b['position'] as int));

          final habits = <Habit>[];
          for (final m in membersRaw) {
            final habitMap = m['habits'] as Map<String, dynamic>?;
            if (habitMap == null) continue;
            habits.add(Habit.fromMap(habitMap));

            await db.upsertRoutineMember(LocalRoutineMembersCompanion(
              id:        Value(m['id'] as String),
              routineId: Value(rId),
              habitId:   Value(m['habit_id'] as String),
              position:  Value(m['position'] as int),
              synced:    const Value(true),
            ));
          }

          final routine = HabitRoutine(
            id:          rId,
            userId:      userId,
            routineType: rType,
            habits:      habits,
            createdAt:   rAt,
          );
          if (rType == 'morning') morning = routine;
          if (rType == 'evening') evening = routine;
        }

        return HabitRoutinesState(morning: morning, evening: evening);
      } catch (e) {
        debugPrint('SiE Routines: online load failed, falling back to local — $e');
      }
    }

    // Offline fallback.
    return _loadFromLocal(userId, db);
  }

  Future<HabitRoutinesState> _loadFromLocal(
      String userId, AppDatabase db) async {
    final localRoutines = await db.routinesForUser(userId);
    final allHabits     = await db.habitsForUser(userId);

    // O1: O(1) map lookup instead of O(n) firstWhere per member.
    final habitById = {for (final h in allHabits) h.id: h};

    HabitRoutine? morning;
    HabitRoutine? evening;

    for (final lr in localRoutines) {
      final members = await db.routineMembersForRoutine(lr.id);
      final habits = members
          .map((m) => habitById[m.habitId])
          .whereType<LocalHabit>()
          .map((lh) => Habit(
                id:          lh.id,
                userId:      lh.userId,
                title:       lh.title,
                description: lh.description,
                color:       lh.color,
                icon:        lh.icon,
                isPinned:    lh.isPinned,
                isArchived:  lh.isArchived,
                createdAt:   DateTime.fromMillisecondsSinceEpoch(lh.createdAtMs),
              ))
          .toList();

      final routine = HabitRoutine(
        id:          lr.id,
        userId:      lr.userId,
        routineType: lr.routineType,
        habits:      habits,
        createdAt:   DateTime.fromMillisecondsSinceEpoch(lr.createdAtMs),
      );
      if (lr.routineType == 'morning') morning = routine;
      if (lr.routineType == 'evening') evening = routine;
    }

    return HabitRoutinesState(morning: morning, evening: evening);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Creates a new routine of the given [routineType] ('morning' | 'evening').
  /// Returns the new routine ID.
  Future<String> createRoutine(String routineType) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db       = ref.read(appDatabaseProvider);
    final routineId = _uuid.v4();
    final now       = DateTime.now();

    await db.upsertRoutine(LocalRoutinesCompanion(
      id:          Value(routineId),
      userId:      Value(userId),
      routineType: Value(routineType),
      createdAtMs: Value(now.millisecondsSinceEpoch),
      synced:      Value(isOnline),
    ));

    final newRoutine = HabitRoutine(
      id:          routineId,
      userId:      userId,
      routineType: routineType,
      habits:      const [],
      createdAt:   now,
    );

    final prev = state.valueOrNull ?? HabitRoutinesState.empty;
    state = AsyncData(routineType == 'morning'
        ? prev.copyWith(morning: newRoutine)
        : prev.copyWith(evening: newRoutine));

    try {
      if (isOnline) {
        await client.from('habit_routines').insert({
          'id':           routineId,
          'user_id':      userId,
          'routine_type': routineType,
        });
        await db.upsertRoutine(LocalRoutinesCompanion(
          id:     Value(routineId),
          synced: const Value(true),
        ));
      } else {
        await db.enqueueSyncOp('insert_routine', jsonEncode({
          'id':           routineId,
          'user_id':      userId,
          'routine_type': routineType,
        }));
      }
    } catch (e) {
      debugPrint('SiE Routines: createRoutine failed — $e');
    }

    return routineId;
  }

  /// Adds [habitId] to the routine [routineId] at the end of the list.
  Future<void> addHabitToRoutine(String routineId, String habitId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db       = ref.read(appDatabaseProvider);

    final prev = state.valueOrNull ?? HabitRoutinesState.empty;
    final routine = prev.morning?.id == routineId ? prev.morning : prev.evening;
    if (routine == null) return;

    final newPosition = routine.habits.length;
    final memberId    = _uuid.v4();

    await db.upsertRoutineMember(LocalRoutineMembersCompanion(
      id:        Value(memberId),
      routineId: Value(routineId),
      habitId:   Value(habitId),
      position:  Value(newPosition),
      synced:    Value(isOnline),
    ));

    // Rebuild routine state.
    state = AsyncData(await _load());

    try {
      if (isOnline) {
        await client.from('habit_routine_members').insert({
          'id':        memberId,
          'routine_id': routineId,
          'habit_id':  habitId,
          'position':  newPosition,
        });
        await db.upsertRoutineMember(LocalRoutineMembersCompanion(
          id:     Value(memberId),
          synced: const Value(true),
        ));
      } else {
        await _enqueueMembersSync(db, routineId, userId);
      }
    } catch (e) {
      debugPrint('SiE Routines: addHabitToRoutine failed — $e');
    }
  }

  /// Removes [habitId] from the routine [routineId].
  Future<void> removeHabitFromRoutine(String routineId, String habitId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db       = ref.read(appDatabaseProvider);

    final prev    = state.valueOrNull ?? HabitRoutinesState.empty;
    final routine = prev.morning?.id == routineId ? prev.morning : prev.evening;
    if (routine == null) return;

    // Bug 1+3: atomic delete+reinsert and preserve existing member IDs.
    final existingMembers = await db.routineMembersForRoutine(routineId);
    final memberIdMap = {for (final m in existingMembers) m.habitId: m.id};
    final remaining = routine.habits.where((h) => h.id != habitId).toList();

    await db.transaction(() async {
      await db.deleteRoutineMembers(routineId);
      for (var i = 0; i < remaining.length; i++) {
        final hid = remaining[i].id;
        await db.upsertRoutineMember(LocalRoutineMembersCompanion(
          id:        Value(memberIdMap[hid] ?? _uuid.v4()),
          routineId: Value(routineId),
          habitId:   Value(hid),
          position:  Value(i),
          synced:    Value(isOnline),
        ));
      }
    });

    state = AsyncData(await _load());

    try {
      if (isOnline) {
        await client
            .from('habit_routine_members')
            .delete()
            .eq('routine_id', routineId)
            .eq('habit_id', habitId);
        // Compact positions server-side.
        for (var i = 0; i < remaining.length; i++) {
          await client
              .from('habit_routine_members')
              .update({'position': i})
              .eq('routine_id', routineId)
              .eq('habit_id', remaining[i].id);
        }
      } else {
        await _enqueueMembersSync(db, routineId, userId);
      }
    } catch (e) {
      debugPrint('SiE Routines: removeHabitFromRoutine failed — $e');
    }
  }

  /// Reorders all members of [routineId] to match [habitIdsInOrder].
  Future<void> reorderMembers(
      String routineId, List<String> habitIdsInOrder) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db       = ref.read(appDatabaseProvider);

    // Bug 1+3: atomic rewrite and preserve existing member IDs.
    final existingMembers = await db.routineMembersForRoutine(routineId);
    final memberIdMap = {for (final m in existingMembers) m.habitId: m.id};

    await db.transaction(() async {
      await db.deleteRoutineMembers(routineId);
      for (var i = 0; i < habitIdsInOrder.length; i++) {
        final hid = habitIdsInOrder[i];
        await db.upsertRoutineMember(LocalRoutineMembersCompanion(
          id:        Value(memberIdMap[hid] ?? _uuid.v4()),
          routineId: Value(routineId),
          habitId:   Value(hid),
          position:  Value(i),
          synced:    Value(isOnline),
        ));
      }
    });

    state = AsyncData(await _load());

    try {
      if (isOnline) {
        // Delete all and re-insert to avoid position conflicts.
        await client
            .from('habit_routine_members')
            .delete()
            .eq('routine_id', routineId);
        if (habitIdsInOrder.isNotEmpty) {
          await client.from('habit_routine_members').insert([
            for (var i = 0; i < habitIdsInOrder.length; i++)
              {
                'id':         _uuid.v4(),
                'routine_id': routineId,
                'habit_id':   habitIdsInOrder[i],
                'position':   i,
              }
          ]);
        }
      } else {
        await _enqueueMembersSync(db, routineId, userId);
      }
    } catch (e) {
      debugPrint('SiE Routines: reorderMembers failed — $e');
    }
  }

  /// Deletes the entire routine and its members.
  Future<void> deleteRoutine(String routineId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db       = ref.read(appDatabaseProvider);

    final prev = state.valueOrNull ?? HabitRoutinesState.empty;
    final isMorning = prev.morning?.id == routineId;

    await db.deleteRoutineMembers(routineId);
    await db.deleteRoutine(routineId);

    state = AsyncData(isMorning
        ? prev.copyWith(clearMorning: true)
        : prev.copyWith(clearEvening: true));

    try {
      if (isOnline) {
        await client.from('habit_routines').delete().eq('id', routineId);
      } else {
        await db.enqueueSyncOp('delete_routine', jsonEncode({
          'id':      routineId,
          'user_id': userId,
        }));
      }
    } catch (e) {
      debugPrint('SiE Routines: deleteRoutine failed — $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // Bug 2: reads IDs from local DB so re-syncs upsert instead of creating duplicates.
  Future<void> _enqueueMembersSync(
    AppDatabase db,
    String routineId,
    String userId,
  ) async {
    final members = await db.routineMembersForRoutine(routineId);
    await db.enqueueSyncOp('sync_routine_members', jsonEncode({
      'routine_id': routineId,
      'user_id':    userId,
      'members': [
        for (final m in members)
          {'id': m.id, 'habit_id': m.habitId, 'position': m.position},
      ],
    }));
  }
}

final habitRoutinesProvider =
    AsyncNotifierProvider.autoDispose<HabitRoutinesNotifier, HabitRoutinesState>(
  HabitRoutinesNotifier.new,
);
