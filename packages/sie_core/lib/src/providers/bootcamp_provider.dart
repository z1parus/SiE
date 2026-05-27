import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import '../models/bootcamp.dart';
import '../supabase_service.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';
import 'user_profile_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _todayStr() {
  final d = DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _prefsKey(String userId) => 'sie_bootcamp_progress_v2_$userId';

// ─────────────────────────────────────────────────────────────────────────────
// BootcampProgress — immutable state snapshot
// ─────────────────────────────────────────────────────────────────────────────

class BootcampProgress {
  final int activeDay;
  final Set<int> claimedDays;

  /// Per-day ISO date string recording WHEN that day's reward was claimed.
  final Map<int, String> claimedDates;

  /// ISO date string of the first time the user opened the Garage tab.
  final String? enrolledDate;

  final bool courseComplete;

  const BootcampProgress({
    required this.activeDay,
    required this.claimedDays,
    required this.claimedDates,
    required this.courseComplete,
    this.enrolledDate,
  });

  factory BootcampProgress.initial() => BootcampProgress(
        activeDay: 1,
        claimedDays: const {},
        claimedDates: const {},
        courseComplete: false,
        enrolledDate: _todayStr(),
      );

  // ── Queries ────────────────────────────────────────────────────────────────

  bool isDayUnlocked(int day) {
    if (day == 1) return true;
    return claimedDays.contains(day - 1);
  }

  bool isDayCompleted(int day) => claimedDays.contains(day);

  /// True when the day's reward can be claimed:
  ///   • Not yet claimed
  ///   • Day lock: for Day N>1, must be a different calendar day than Day N-1's claim
  ///   • ≥75% of tasks auto-completed by real activity
  bool canClaimDay(
    int day,
    List<BootcampTask> tasks,
    BootcampDailyActivity activity,
  ) {
    if (claimedDays.contains(day)) return false;

    // Day lock — prevent same-day advancement
    if (day > 1) {
      final prevDate = claimedDates[day - 1];
      if (prevDate != null && prevDate == _todayStr()) return false;
    }

    if (tasks.isEmpty) return false;
    final done = tasks.where((t) => t.isAutoComplete(activity)).length;
    return (done / tasks.length) >= 0.75;
  }

  /// True when Day N-1 was claimed today — show the day-lock banner.
  bool isDayLockedUntilTomorrow(int day) {
    if (day <= 1) return false;
    final prevDate = claimedDates[day - 1];
    return prevDate != null && prevDate == _todayStr();
  }

  // ── Copy ──────────────────────────────────────────────────────────────────

  BootcampProgress copyWith({
    int? activeDay,
    Set<int>? claimedDays,
    Map<int, String>? claimedDates,
    bool? courseComplete,
    String? enrolledDate,
  }) =>
      BootcampProgress(
        activeDay: activeDay ?? this.activeDay,
        claimedDays: claimedDays ?? this.claimedDays,
        claimedDates: claimedDates ?? this.claimedDates,
        courseComplete: courseComplete ?? this.courseComplete,
        enrolledDate: enrolledDate ?? this.enrolledDate,
      );

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'activeDay': activeDay,
        'claimedDays': claimedDays.toList(),
        'claimedDates': claimedDates.map((k, v) => MapEntry(k.toString(), v)),
        'courseComplete': courseComplete,
        'enrolledDate': enrolledDate,
      };

  factory BootcampProgress.fromJson(Map<String, dynamic> json) {
    final rawClaimed = (json['claimedDays'] as List?) ?? [];
    final rawDates   = (json['claimedDates'] as Map<String, dynamic>?) ?? {};
    return BootcampProgress(
      activeDay: json['activeDay'] as int? ?? 1,
      claimedDays: Set<int>.from(rawClaimed.map((e) => e as int)),
      claimedDates: rawDates.map(
        (k, v) => MapEntry(int.tryParse(k) ?? 0, v.toString()),
      ),
      courseComplete: json['courseComplete'] as bool? ?? false,
      enrolledDate: json['enrolledDate'] as String?,
    );
  }

  /// Merge two progress snapshots, keeping the more advanced one.
  static BootcampProgress merge(BootcampProgress a, BootcampProgress b) =>
      a.claimedDays.length >= b.claimedDays.length ? a : b;
}

// ─────────────────────────────────────────────────────────────────────────────
// BootcampProgressNotifier
// ─────────────────────────────────────────────────────────────────────────────

class BootcampProgressNotifier
    extends AsyncNotifier<BootcampProgress> {
  @override
  Future<BootcampProgress> build() async {
    // Re-build whenever auth changes (e.g., different account logs in).
    ref.watch(authStateProvider);

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return BootcampProgress.initial();

    final isOnline =
        ref.read(connectivityProvider).valueOrNull ?? false;

    BootcampProgress? local = await _loadLocal(userId);
    BootcampProgress? remote;

    if (isOnline) {
      remote = await _loadRemote(userId);
    }

    BootcampProgress progress;
    if (local == null && remote == null) {
      progress = BootcampProgress.initial();
    } else if (local == null) {
      progress = remote!;
    } else if (remote == null) {
      progress = local;
    } else {
      progress = BootcampProgress.merge(local, remote);
    }

    // Ensure enrolledDate is always set.
    if (progress.enrolledDate == null) {
      progress = progress.copyWith(enrolledDate: _todayStr());
    }

    await _save(progress, userId);
    return progress;
  }

  // ── Local persistence ──────────────────────────────────────────────────────

  Future<BootcampProgress?> _loadLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_prefsKey(userId));
      if (raw == null) return null;
      return BootcampProgress.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocal(BootcampProgress p, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(userId), jsonEncode(p.toJson()));
  }

  // ── Remote persistence ─────────────────────────────────────────────────────

  Future<BootcampProgress?> _loadRemote(String userId) async {
    try {
      final row = await SupabaseService.client
          .from('bootcamp_progress')
          .select('progress_json')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      final json = row['progress_json'];
      if (json == null) return null;
      return BootcampProgress.fromJson(
          (json is String ? jsonDecode(json) : json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRemote(BootcampProgress p, String userId) async {
    try {
      await SupabaseService.client.from('bootcamp_progress').upsert({
        'user_id': userId,
        'progress_json': p.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _save(BootcampProgress p, String userId) async {
    await _saveLocal(p, userId);
    final isOnline =
        ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) await _saveRemote(p, userId);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Claims the day reward (1000 DP) if eligible. Returns true on success.
  Future<bool> claimDayReward(
    int day,
    List<BootcampTask> dayTasks,
    BootcampDailyActivity activity,
  ) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;

    final current = state.valueOrNull ?? BootcampProgress.initial();
    if (!current.canClaimDay(day, dayTasks, activity)) return false;

    final newClaimedDays  = Set<int>.from(current.claimedDays)..add(day);
    final newClaimedDates = Map<int, String>.from(current.claimedDates)
      ..[day] = _todayStr();
    final nextActiveDay   = (day < 7) ? day + 1 : day;
    final courseComplete  = newClaimedDays.length >= 7;

    final updated = current.copyWith(
      claimedDays: newClaimedDays,
      claimedDates: newClaimedDates,
      activeDay: nextActiveDay,
      courseComplete: courseComplete,
    );
    state = AsyncData(updated);
    await _save(updated, userId);

    // Award 1000 DP locally (syncs via SyncService on next go-online).
    await ref
        .read(userProfileProvider.notifier)
        .applyLocalXpDelta(0, 1000);

    // Best-effort online DP sync + badge on course completion.
    final isOnline =
        ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .rpc('add_design_points', params: {'p_amount': 1000});
        if (courseComplete) await _tryAwardBadge(userId);
      } catch (_) {}
    }

    return true;
  }

  Future<void> _tryAwardBadge(String userId) async {
    try {
      final ach = await SupabaseService.client
          .from('achievements')
          .select()
          .eq('slug', 'bootcamp_tester')
          .maybeSingle();
      if (ach == null) return;
      await SupabaseService.client
          .from('user_achievements')
          .upsert(
        {'user_id': userId, 'achievement_id': ach['id']},
        onConflict: 'user_id,achievement_id',
      );
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// bootcampProgressProvider
// ─────────────────────────────────────────────────────────────────────────────

final bootcampProgressProvider =
    AsyncNotifierProvider<BootcampProgressNotifier, BootcampProgress>(
  BootcampProgressNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// bootcampDailyActivityProvider
//
// Reads TODAY's real tool usage from the local DB.
// Invalidated by garage_screen.dart after returning from a tool screen.
// ─────────────────────────────────────────────────────────────────────────────

final bootcampDailyActivityProvider =
    FutureProvider.autoDispose<BootcampDailyActivity>((ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return BootcampDailyActivity.empty;

  final db    = ref.read(appDatabaseProvider);
  final today = _todayStr();

  final breathing = await db.countBreathingSessionsOnDate(userId, today);
  final focus     = await db.countFocusSessionsOnDate(userId, today);
  final habit     = await db.hasHabitLogOnDate(userId, today);

  return BootcampDailyActivity(
    breathingSessionsToday: breathing,
    focusSessionsToday: focus,
    hasHabitLogToday: habit,
  );
});
