import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../providers/user_profile_provider.dart';

const _uuid = Uuid();

class SyncService {
  final AppDatabase _db;
  final UserProfileNotifier _profileNotifier;

  SyncService._(this._db, this._profileNotifier);

  factory SyncService.fromRef(Ref ref) => SyncService._(
        ref.read(appDatabaseProvider),
        ref.read(userProfileProvider.notifier),
      );

  factory SyncService.fromWidgetRef(WidgetRef ref) => SyncService._(
        ref.read(appDatabaseProvider),
        ref.read(userProfileProvider.notifier),
      );

  Future<void> syncAll() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await _syncPendingOps(client, userId);
    await _syncHabitLogs(client, userId);
    await _syncFocusSessions(client, userId);
    await _syncPendingXp(client, userId);

    // Reconcile server profile so XP bar reflects true server state.
    await _profileNotifier.reconcileFromServer();
  }

  Future<void> _syncPendingOps(
      SupabaseClient client, String userId) async {
    final ops = await _db.getPendingSyncOps();
    for (final op in ops) {
      try {
        final payload =
            jsonDecode(op.payload) as Map<String, dynamic>;
        switch (op.operationType) {
          case 'insert_habit':
            await client
                .from('habits')
                .upsert(payload, onConflict: 'id');
          case 'delete_habit':
            await client
                .from('habits')
                .delete()
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
          case 'update_habit':
            await client
                .from('habits')
                .update(payload)
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
          case 'insert_habit_log':
            await client.from('habit_logs').upsert({
              ...payload,
              'xp_awarded': 50,
            }, onConflict: 'user_id,habit_id,completed_at');
          case 'update_habit_log':
            await client.from('habit_logs').update({
              'note': payload['note'],
              'emoji': payload['emoji'],
            })
                .eq('habit_id', payload['habit_id'] as String)
                .eq('user_id', userId)
                .eq('completed_at', payload['completed_at'] as String);
          case 'delete_habit_log':
            await client
                .from('habit_logs')
                .delete()
                .eq('habit_id', payload['habit_id'] as String)
                .eq('user_id', userId)
                .eq('completed_at',
                    payload['completed_at'] as String);
          case 'insert_routine':
            await client
                .from('habit_routines')
                .upsert(payload, onConflict: 'id');
          case 'sync_routine_members':
            // Bug 2: payload now includes stable IDs; upsert to handle re-sync safely.
            final routineId = payload['routine_id'] as String;
            final members =
                (payload['members'] as List).cast<Map<String, dynamic>>();
            await client
                .from('habit_routine_members')
                .delete()
                .eq('routine_id', routineId);
            if (members.isNotEmpty) {
              await client.from('habit_routine_members').upsert([
                for (final m in members)
                  {
                    'id': m['id'] as String? ?? _uuid.v4(),
                    'routine_id': routineId,
                    'habit_id': m['habit_id'] as String,
                    'position': m['position'] as int,
                  }
              ], onConflict: 'id');
            }
          case 'delete_routine':
            await client
                .from('habit_routines')
                .delete()
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);

          // ── Planning ops ────────────────────────────────────────────────
          case 'insert_goal':
            await client.from('goals').upsert(payload, onConflict: 'id');
            await _db.updateGoal(payload['id'] as String,
                const LocalGoalsCompanion(synced: Value(true)));
          case 'delete_goal':
            await client
                .from('goals')
                .delete()
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
          case 'update_goal_status':
            await client
                .from('goals')
                .update({'status': payload['status'] as String})
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
            await _db.updateGoal(payload['id'] as String,
                const LocalGoalsCompanion(synced: Value(true)));
          case 'insert_sub_goal':
            final sgId = payload['id'] as String;
            final localSg = await _db.getSubGoal(sgId);
            await client.from('sub_goals').upsert({
              'id': sgId,
              'goal_id': payload['goal_id'],
              'name': payload['name'],
              'order_index': payload['order_index'] ?? 0,
              'is_completed': localSg?.isCompleted ?? false,
            }, onConflict: 'id');
            await _db.updateSubGoal(sgId,
                const LocalSubGoalsCompanion(synced: Value(true)));
          case 'delete_sub_goal':
            await client
                .from('sub_goals')
                .delete()
                .eq('id', payload['id'] as String);
          case 'complete_sub_goal':
            await client
                .from('sub_goals')
                .update({'is_completed': true})
                .eq('id', payload['id'] as String);
            await _db.updateSubGoal(payload['id'] as String,
                const LocalSubGoalsCompanion(synced: Value(true)));
          case 'insert_task':
            final taskId = payload['id'] as String;
            final localTask = await _db.getPlanningTask(taskId);
            await client.from('planning_tasks').upsert({
              'id': taskId,
              'sub_goal_id': payload['sub_goal_id'],
              'user_id': payload['user_id'],
              'name': payload['name'],
              'weight': payload['weight'] ?? 1,
              'order_index': payload['order_index'] ?? localTask?.orderIndex ?? 0,
              if (payload['due_date'] != null) 'due_date': payload['due_date'],
              if (payload['recurrence_rule'] != null)
                'recurrence_rule': payload['recurrence_rule'],
              if (payload['recurrence_until'] != null)
                'recurrence_until': payload['recurrence_until'],
              if (payload['recurrence_parent_id'] != null)
                'recurrence_parent_id': payload['recurrence_parent_id'],
              'is_completed': localTask?.isCompleted ?? false,
              if (localTask?.completedAtMs != null)
                'completed_at': DateTime.fromMillisecondsSinceEpoch(
                    localTask!.completedAtMs!).toIso8601String(),
            }, onConflict: 'id');
            await _db.updatePlanningTask(taskId,
                const LocalPlanningTasksCompanion(synced: Value(true)));
          case 'toggle_task':
            final isCompleted = payload['is_completed'] as bool;
            await client.from('planning_tasks').update({
              'is_completed': isCompleted,
              'completed_at': payload['completed_at'],
            }).eq('id', payload['id'] as String);
            await _db.updatePlanningTask(payload['id'] as String,
                const LocalPlanningTasksCompanion(synced: Value(true)));
          case 'reschedule_task':
            await client.from('planning_tasks').update({
              'due_date': payload['due_date'],
            }).eq('id', payload['id'] as String).eq('user_id', userId);
            await _db.updatePlanningTask(payload['id'] as String,
                const LocalPlanningTasksCompanion(synced: Value(true)));
          case 'end_recurrence':
            await client.from('planning_tasks').update({
              'recurrence_rule': null,
            }).eq('id', payload['id'] as String).eq('user_id', userId);
            await _db.updatePlanningTask(payload['id'] as String,
                const LocalPlanningTasksCompanion(synced: Value(true)));
          case 'delete_task':
            await client
                .from('planning_tasks')
                .delete()
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
          case 'insert_milestone':
            final msId = payload['id'] as String;
            final localMs = await _db.getMilestone(msId);
            await client.from('milestones').upsert({
              'id': msId,
              'goal_id': payload['goal_id'],
              'name': payload['name'],
              if (payload['target_date'] != null) 'target_date': payload['target_date'],
              'is_completed': localMs?.isCompleted ?? false,
              'kind': payload['kind'] ?? 'binary',
              if (payload['unit'] != null) 'unit': payload['unit'],
              if (payload['start_value'] != null) 'start_value': payload['start_value'],
              if (payload['target_value'] != null) 'target_value': payload['target_value'],
              if (payload['current_value'] != null) 'current_value': payload['current_value'],
              'direction': payload['direction'] ?? 'up',
            }, onConflict: 'id');
            await _db.upsertMilestone(LocalMilestonesCompanion(
                id: Value(msId), synced: const Value(true)));
          case 'insert_milestone_log':
            await client.from('milestone_logs').upsert({
              'id': payload['id'],
              'milestone_id': payload['milestone_id'],
              'user_id': payload['user_id'],
              'value': payload['value'],
              'recorded_at': payload['recorded_at'],
            }, onConflict: 'id');
            await _db.insertMilestoneLog(LocalMilestoneLogsCompanion(
                id: Value(payload['id'] as String),
                synced: const Value(true)));
          case 'delete_milestone_log':
            await client
                .from('milestone_logs')
                .delete()
                .eq('id', payload['id'] as String);
          case 'complete_milestone':
            await client
                .from('milestones')
                .update({'is_completed': true})
                .eq('id', payload['id'] as String);
            await _db.upsertMilestone(LocalMilestonesCompanion(
                id: Value(payload['id'] as String), synced: const Value(true)));
          case 'delete_milestone':
            await client
                .from('milestones')
                .delete()
                .eq('id', payload['id'] as String);
          case 'insert_goal_snapshot':
            await client.from('goal_progress_snapshots').upsert({
              'id': payload['id'],
              'goal_id': payload['goal_id'],
              'user_id': payload['user_id'],
              'progress': payload['progress'],
              'completed_tasks': payload['completed_tasks'],
              'total_tasks': payload['total_tasks'],
              'captured_at': payload['captured_at'],
            }, onConflict: 'id');
            await _db.markGoalSnapshotSynced(payload['id'] as String);
          case 'insert_habit_link':
            await client.from('goal_habit_links').upsert({
              'id': payload['id'],
              'goal_id': payload['goal_id'],
              'habit_id': payload['habit_id'],
            }, onConflict: 'id');
          case 'delete_habit_link':
            await client
                .from('goal_habit_links')
                .delete()
                .eq('id', payload['id'] as String);
          case 'move_task':
            await client
                .from('planning_tasks')
                .update({'sub_goal_id': payload['sub_goal_id'] as String})
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
            await _db.updatePlanningTask(payload['id'] as String,
                const LocalPlanningTasksCompanion(synced: Value(true)));
          case 'update_goal_progress':
            await client
                .from('goals')
                .update({'progress': payload['progress'] as double})
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
            await _db.updateGoal(payload['id'] as String,
                const LocalGoalsCompanion(synced: Value(true)));
          case 'update_goal_settings':
            await client
                .from('goals')
                .update({'settings': payload['settings']})
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
            await _db.updateGoal(payload['id'] as String,
                const LocalGoalsCompanion(synced: Value(true)));
          case 'award_mission_medal':
            await client
                .from('mission_medals')
                .upsert(payload, onConflict: 'id');
            await _db.markMedalSynced(payload['id'] as String);
          case 'reorder_sub_goal':
            await client
                .from('sub_goals')
                .update({'order_index': payload['order_index'] as int})
                .eq('id', payload['id'] as String);
            await _db.updateSubGoal(payload['id'] as String,
                const LocalSubGoalsCompanion(synced: Value(true)));
          case 'reorder_task':
            await client
                .from('planning_tasks')
                .update({'order_index': payload['order_index'] as int})
                .eq('id', payload['id'] as String);
            await _db.updatePlanningTask(payload['id'] as String,
                const LocalPlanningTasksCompanion(synced: Value(true)));
          case 'update_goal_pin':
            await client
                .from('goals')
                .update({'is_pinned': payload['is_pinned'] as bool})
                .eq('id', payload['id'] as String)
                .eq('user_id', userId);
            await _db.updateGoal(payload['id'] as String,
                const LocalGoalsCompanion(synced: Value(true)));

          default:
            debugPrint(
                'SiE Sync: unknown op ${op.operationType}');
        }
        await _db.deleteSyncOp(op.id);
      } catch (e) {
        debugPrint('SiE Sync: op ${op.id} failed — $e');
        await _db.incrementSyncAttempts(op.id, e.toString());
      }
    }
  }

  // O3: single batch upsert instead of N round-trips.
  Future<void> _syncHabitLogs(
      SupabaseClient client, String userId) async {
    final logs = await _db.unsyncedHabitLogs(userId);
    if (logs.isEmpty) return;
    try {
      await client.from('habit_logs').upsert(
        logs.map((log) => {
          'habit_id':     log.habitId,
          'user_id':      log.userId,
          'completed_at': log.completedAt,
          'xp_awarded':   50,
          if (log.note  != null) 'note':  log.note,
          if (log.emoji != null) 'emoji': log.emoji,
        }).toList(),
        onConflict: 'user_id,habit_id,completed_at',
      );
      for (final log in logs) {
        await _db.markHabitLogSynced(log.habitId, log.userId, log.completedAt);
      }
    } catch (e) {
      debugPrint('SiE Sync: habit_log batch sync failed — $e');
    }
  }

  Future<void> _syncFocusSessions(
      SupabaseClient client, String userId) async {
    final sessions = await _db.unsyncedFocusSessions(userId);
    for (final s in sessions) {
      try {
        await client.from('focus_sessions').upsert({
          'id': s.id,
          'user_id': s.userId,
          'duration_seconds': s.durationSeconds,
          'is_completed': true,
          'xp_gained': s.xpAwarded,
        }, onConflict: 'id');
        await _db.markFocusSessionSynced(s.id);
      } catch (e) {
        debugPrint(
            'SiE Sync: focus session ${s.id} failed — $e');
      }
    }
  }

  // Flushes accumulated offline XP/DP to Supabase in one batch.
  Future<void> _syncPendingXp(
      SupabaseClient client, String userId) async {
    final profile = await _db.getProfile(userId);
    if (profile == null) return;
    final xp = profile.pendingXp;
    final dp = profile.pendingDp;
    if (xp <= 0 && dp <= 0) return;

    try {
      await Future.wait([
        if (xp > 0)
          client.rpc('increment_xp',
              params: {'p_user_id': userId, 'p_amount': xp}),
        if (dp > 0)
          client.rpc('add_design_points',
              params: {'p_amount': dp}),
      ]);
      await _db.clearPending(userId);
    } catch (e) {
      debugPrint('SiE Sync: pending XP flush failed — $e');
    }
  }
}
