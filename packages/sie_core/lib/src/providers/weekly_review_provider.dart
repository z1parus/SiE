import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/planning.dart';
import 'agenda_provider.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';
import 'planning_provider.dart';
import 'user_profile_provider.dart';

const _uuid = Uuid();

/// Reward for completing a weekly review (mirrors the meditation pattern).
const int kWeeklyReviewXp = 200;
const int kWeeklyReviewDp = 30;

/// Monday 00:00 local of the week containing [d] (ISO week start).
DateTime isoWeekStart(DateTime d) {
  final dateOnly = DateTime(d.year, d.month, d.day);
  return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
}

// ─── Models ─────────────────────────────────────────────────────────────────

class WeeklyReviewData {
  const WeeklyReviewData({
    required this.weekStart,
    required this.completedTasks,
    required this.milestonesCompleted,
    required this.stallingGoals,
    required this.overdue,
    required this.alreadyReviewed,
    required this.reviewStreak,
  });

  final DateTime weekStart;
  final int completedTasks;
  final int milestonesCompleted;
  final List<Goal> stallingGoals;
  final List<AgendaItem> overdue;
  final bool alreadyReviewed;
  final int reviewStreak;

  static final empty = WeeklyReviewData(
    weekStart: isoWeekStart(DateTime.now()),
    completedTasks: 0,
    milestonesCompleted: 0,
    stallingGoals: const [],
    overdue: const [],
    alreadyReviewed: false,
    reviewStreak: 0,
  );
}

class WeeklyReviewResult {
  const WeeklyReviewResult({required this.xpGained, required this.dpGained});
  final int xpGained;
  final int dpGained;
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class WeeklyReviewNotifier
    extends AutoDisposeAsyncNotifier<WeeklyReviewData> {
  @override
  Future<WeeklyReviewData> build() async {
    ref.watch(authStateProvider);
    final planning = ref.watch(planningProvider).valueOrNull;
    final agenda = ref.watch(agendaProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (planning == null || userId == null) return WeeklyReviewData.empty;

    final weekStart = isoWeekStart(DateTime.now());
    final weekStartMs = weekStart.millisecondsSinceEpoch;

    var completed = 0;
    var milestonesDone = 0;
    for (final g in planning.goals) {
      for (final sg in flattenSubGoals(g.subGoals)) {
        for (final t in sg.tasks) {
          if (t.isCompleted &&
              t.completedAt != null &&
              !t.completedAt!.isBefore(weekStart)) {
            completed++;
          }
        }
      }
      for (final m in g.milestones) {
        if (m.isCompleted) milestonesDone++;
      }
    }

    final stalling = planning.activeGoals.where(isGoalFatigued).toList();

    final db = ref.read(appDatabaseProvider);
    final existing = await db.weeklyReviewForWeek(userId, weekStartMs);

    var streak = 0;
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        final row = await Supabase.instance.client
            .from('profiles')
            .select('review_streak')
            .eq('id', userId)
            .maybeSingle();
        streak = (row?['review_streak'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }

    return WeeklyReviewData(
      weekStart: weekStart,
      completedTasks: completed,
      milestonesCompleted: milestonesDone,
      stallingGoals: stalling,
      overdue: agenda.overdue,
      alreadyReviewed: existing != null,
      reviewStreak: streak,
    );
  }

  /// Persists a weekly review (idempotent per week — antifarm), awards XP/DP
  /// and bumps the review streak. Returns the reward, or null if already done.
  Future<WeeklyReviewResult?> submit({
    String? notes,
    List<String> focusGoalIds = const [],
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return null;
    final userId = session.user.id;
    final db = ref.read(appDatabaseProvider);

    final weekStart = isoWeekStart(DateTime.now());
    final weekStartMs = weekStart.millisecondsSinceEpoch;

    // Antifarm: one review per week.
    final existing = await db.weeklyReviewForWeek(userId, weekStartMs);
    if (existing != null) return null;

    final data = state.valueOrNull;
    final completed = data?.completedTasks ?? 0;
    final id = _uuid.v4();
    final now = DateTime.now();
    final focusJson = jsonEncode(focusGoalIds);

    await db.upsertWeeklyReview(LocalWeeklyReviewsCompanion(
      id: Value(id),
      userId: Value(userId),
      weekStartMs: Value(weekStartMs),
      completedTasks: Value(completed),
      notes: Value(notes),
      focusGoalIdsJson: Value(focusJson),
      createdAtMs: Value(now.millisecondsSinceEpoch),
      synced: const Value(false),
    ));

    var xp = kWeeklyReviewXp;
    var dp = kWeeklyReviewDp;

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        final result = await client.rpc('log_weekly_review', params: {
          'p_week_start': _dateString(weekStart),
          'p_completed_tasks': completed,
          'p_notes': notes,
          'p_focus_goal_ids': focusGoalIds,
        });
        if (result is List && result.isNotEmpty) {
          xp = (result[0]['xp_awarded'] as num?)?.toInt() ?? xp;
          dp = (result[0]['dp_awarded'] as num?)?.toInt() ?? dp;
        }
        await db.markWeeklyReviewSynced(id);
      } catch (_) {
        await db.enqueueSyncOp('insert_weekly_review', jsonEncode({
          'id': id,
          'week_start': _dateString(weekStart),
          'completed_tasks': completed,
          'notes': notes,
          'focus_goal_ids': focusGoalIds,
        }));
      }
    } else {
      await db.enqueueSyncOp('insert_weekly_review', jsonEncode({
        'id': id,
        'week_start': _dateString(weekStart),
        'completed_tasks': completed,
        'notes': notes,
        'focus_goal_ids': focusGoalIds,
      }));
    }

    try {
      await ref.read(userProfileProvider.notifier).applyLocalXpDelta(xp, dp);
    } catch (_) {}

    ref.invalidateSelf();
    ref.invalidate(weeklyFocusGoalIdsProvider);
    return WeeklyReviewResult(xpGained: xp, dpGained: dp);
  }

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final weeklyReviewProvider = AutoDisposeAsyncNotifierProvider<
    WeeklyReviewNotifier, WeeklyReviewData>(WeeklyReviewNotifier.new);

/// Goal ids marked as "focus of the week" in the current week's review.
/// Read by the War Room to star them.
final weeklyFocusGoalIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  ref.watch(authStateProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};
  final db = ref.read(appDatabaseProvider);
  final weekStartMs = isoWeekStart(DateTime.now()).millisecondsSinceEpoch;
  final review = await db.weeklyReviewForWeek(userId, weekStartMs);
  if (review == null) return {};
  try {
    final ids = (jsonDecode(review.focusGoalIdsJson) as List).cast<String>();
    return ids.toSet();
  } catch (_) {
    return {};
  }
});
