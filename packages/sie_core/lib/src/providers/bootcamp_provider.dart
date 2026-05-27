import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bootcamp.dart';
import 'connectivity_provider.dart';
import 'user_profile_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BootcampProgress — immutable state snapshot
// ─────────────────────────────────────────────────────────────────────────────

class BootcampProgress {
  final int activeDay;
  final Map<int, Set<String>> completedTaskIds;
  final Set<int> claimedDays;
  final bool courseComplete;

  const BootcampProgress({
    required this.activeDay,
    required this.completedTaskIds,
    required this.claimedDays,
    required this.courseComplete,
  });

  factory BootcampProgress.initial() => const BootcampProgress(
        activeDay: 1,
        completedTaskIds: {},
        claimedDays: {},
        courseComplete: false,
      );

  // ── Queries ────────────────────────────────────────────────────────────────

  bool isDayUnlocked(int day) {
    if (day == 1) return true;
    return claimedDays.contains(day - 1);
  }

  bool isDayCompleted(int day) => claimedDays.contains(day);

  bool isTaskDone(int day, String taskId) =>
      completedTaskIds[day]?.contains(taskId) ?? false;

  double completionRateForDay(int day, List<BootcampTask> tasks) {
    if (tasks.isEmpty) return 0;
    final done = completedTaskIds[day]?.length ?? 0;
    return done / tasks.length;
  }

  /// Returns true if the day can have its reward claimed (not yet claimed, ≥75% done).
  bool canClaimDay(int day, List<BootcampTask> tasks) {
    if (claimedDays.contains(day)) return false;
    return completionRateForDay(day, tasks) >= 0.75;
  }

  // ── Copy ──────────────────────────────────────────────────────────────────

  BootcampProgress copyWith({
    int? activeDay,
    Map<int, Set<String>>? completedTaskIds,
    Set<int>? claimedDays,
    bool? courseComplete,
  }) =>
      BootcampProgress(
        activeDay: activeDay ?? this.activeDay,
        completedTaskIds: completedTaskIds ?? this.completedTaskIds,
        claimedDays: claimedDays ?? this.claimedDays,
        courseComplete: courseComplete ?? this.courseComplete,
      );

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'activeDay': activeDay,
        'completedTaskIds': completedTaskIds.map(
          (k, v) => MapEntry(k.toString(), v.toList()),
        ),
        'claimedDays': claimedDays.toList(),
        'courseComplete': courseComplete,
      };

  factory BootcampProgress.fromJson(Map<String, dynamic> json) {
    final rawMap =
        (json['completedTaskIds'] as Map<String, dynamic>?) ?? {};
    final completedTaskIds = rawMap.map(
      (k, v) => MapEntry(
        int.tryParse(k) ?? 0,
        Set<String>.from((v as List).map((e) => e.toString())),
      ),
    );
    final rawClaimed = (json['claimedDays'] as List?) ?? [];
    return BootcampProgress(
      activeDay: json['activeDay'] as int? ?? 1,
      completedTaskIds: completedTaskIds,
      claimedDays: Set<int>.from(rawClaimed.map((e) => e as int)),
      courseComplete: json['courseComplete'] as bool? ?? false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BootcampProgressNotifier
// ─────────────────────────────────────────────────────────────────────────────

class BootcampProgressNotifier
    extends AsyncNotifier<BootcampProgress> {
  static const _prefsKey = 'sie_bootcamp_progress_v1';

  @override
  Future<BootcampProgress> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return BootcampProgress.initial();
    try {
      return BootcampProgress.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return BootcampProgress.initial();
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _save(BootcampProgress p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(p.toJson()));
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Toggles a single task's completion status for [day].
  Future<void> toggleTask(int day, String taskId) async {
    final current = state.valueOrNull ?? BootcampProgress.initial();

    // Deep-copy the map to keep the state immutable.
    final newMap = Map<int, Set<String>>.from(
      current.completedTaskIds
          .map((k, v) => MapEntry(k, Set<String>.from(v))),
    );
    final set = newMap[day] ?? {};
    if (set.contains(taskId)) {
      set.remove(taskId);
    } else {
      set.add(taskId);
    }
    newMap[day] = set;

    final updated = current.copyWith(completedTaskIds: newMap);
    state = AsyncData(updated);
    await _save(updated);
  }

  /// Claims the day reward (1000 DP). Returns true on success.
  Future<bool> claimDayReward(
      int day, List<BootcampTask> dayTasks) async {
    final current = state.valueOrNull ?? BootcampProgress.initial();
    if (!current.canClaimDay(day, dayTasks)) return false;

    final newClaimed = Set<int>.from(current.claimedDays)..add(day);
    final nextActiveDay = (day < 7) ? day + 1 : day;
    final courseComplete = newClaimed.length >= 7;

    final updated = current.copyWith(
      claimedDays: newClaimed,
      activeDay: nextActiveDay,
      courseComplete: courseComplete,
    );
    state = AsyncData(updated);
    await _save(updated);

    // Award 1000 DP — handled locally first, then synced.
    await ref
        .read(userProfileProvider.notifier)
        .applyLocalXpDelta(0, 1000);

    // Best-effort online sync.
    final isOnline =
        ref.read(connectivityProvider).valueOrNull ?? false;
    if (isOnline) {
      try {
        await Supabase.instance.client
            .rpc('add_design_points', params: {'p_amount': 1000});

        if (courseComplete) {
          await _tryAwardBadge();
        }
      } catch (_) {
        // Will be picked up by SyncService._syncPendingXp on next go-online.
      }
    }

    return true;
  }

  /// Attempts to insert the 'bootcamp_tester' achievement for the current user.
  Future<void> _tryAwardBadge() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final ach = await client
          .from('achievements')
          .select()
          .eq('slug', 'bootcamp_tester')
          .maybeSingle();
      if (ach == null) return;

      // Insert; ignore conflict if already awarded.
      await client.from('user_achievements').upsert({
        'user_id': userId,
        'achievement_id': ach['id'],
      }, onConflict: 'user_id,achievement_id');
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final bootcampProgressProvider =
    AsyncNotifierProvider<BootcampProgressNotifier, BootcampProgress>(
  BootcampProgressNotifier.new,
);
