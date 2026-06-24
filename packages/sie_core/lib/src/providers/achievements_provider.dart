import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/achievement.dart';
import '../widgets_home/widget_render_service.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';
import 'user_profile_provider.dart';

const _breathingDp = 20;
const _uuid = Uuid();

typedef SessionResult = ({int xpGained, int dpGained, Achievement? newAchievement});

class SessionCompletionNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Logs a finished breathing session. The practice metrics ([breaths],
  /// [rounds], [longestHoldSeconds], [totalHoldSeconds]) and the optional
  /// post-practice reflection ([moodEmoji], [calmness], [confidence]) are
  /// stored both locally and — now — in the Supabase `breathing_sessions`
  /// table (queued for sync when offline).
  Future<SessionResult> completeSession({
    required int durationSeconds,
    int breaths = 0,
    int rounds = 0,
    int longestHoldSeconds = 0,
    int totalHoldSeconds = 0,
    String? moodEmoji,
    int? calmness,
    int? confidence,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final xp = ((durationSeconds / 60.0) * 10).round().clamp(10, 9999);

    final id = _uuid.v4();
    final completedAt = DateTime.now();

    // Always record locally.
    await db.insertBreathingSession(LocalBreathingSessionsCompanion(
      id: Value(id),
      userId: Value(userId),
      durationSeconds: Value(durationSeconds),
      completedAtMs: Value(completedAt.millisecondsSinceEpoch),
      xpAwarded: Value(xp),
      dpAwarded: const Value(_breathingDp),
      breaths: Value(breaths),
      rounds: Value(rounds),
      longestHoldSeconds: Value(longestHoldSeconds),
      totalHoldSeconds: Value(totalHoldSeconds),
      moodEmoji: Value(moodEmoji),
      calmness: Value(calmness),
      confidence: Value(confidence),
      synced: Value(isOnline),
    ));

    // The row that mirrors this session into Supabase.
    final sessionRow = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'duration_seconds': durationSeconds,
      'breaths': breaths,
      'rounds': rounds,
      'longest_hold_seconds': longestHoldSeconds,
      'total_hold_seconds': totalHoldSeconds,
      'mood_emoji': moodEmoji,
      'calmness': calmness,
      'confidence': confidence,
      'xp_awarded': xp,
      'dp_awarded': _breathingDp,
      'completed_at': completedAt.toUtc().toIso8601String(),
    };

    // Refresh the Breathing home widget(s) from the local mirror.
    WidgetRenderService.notifyModuleChanged('breathing', db)
        .catchError((e) => debugPrint('SiE Breathing: widget refresh — $e'));

    Achievement? earned;

    if (isOnline) {
      await client.from('breathing_sessions').insert(sessionRow);
      await db.markBreathingSessionSynced(id);

      await Future.wait([
        client.rpc('increment_xp', params: {
          'p_user_id': userId,
          'p_amount': xp,
        }),
        client.rpc('add_design_points', params: {'p_amount': _breathingDp}),
      ]);

      // Award 'first_breath' only if the user has no achievements yet.
      final existing = await client
          .from('user_achievements')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      if (existing.isEmpty) {
        final ach = await client
            .from('achievements')
            .select()
            .eq('slug', 'first_breath')
            .maybeSingle();
        if (ach != null) {
          await client.from('user_achievements').insert({
            'user_id': userId,
            'achievement_id': ach['id'],
          });
          earned = Achievement.fromMap(ach);
        }
      }
    } else {
      // Offline: queue the session row so it reaches Supabase on reconnect.
      // (XP/DP increments are reconciled separately via the pending profile
      // deltas applied below.)
      await db.enqueueSyncOp('insert_breathing_session', jsonEncode(sessionRow));
    }

    // Apply local XP delta for immediate UI update regardless of connectivity.
    await ref
        .read(userProfileProvider.notifier)
        .applyLocalXpDelta(xp, _breathingDp);

    return (xpGained: xp, dpGained: _breathingDp, newAchievement: earned);
  }
}

final sessionCompletionProvider =
    NotifierProvider<SessionCompletionNotifier, void>(
  SessionCompletionNotifier.new,
);

/// Fetches all achievements and maps unlock status for the current session user.
///
/// Waits for authStateProvider to confirm a live session before querying —
/// prevents a premature empty return while Supabase restores the JWT from
/// storage on first launch.
///
/// user_achievements nested rows are processed with whereType instead of cast
/// — cast() is lazy and throws a TypeError at element-access time when Dart's
/// decoder produces Map-String-Object? values instead of Map-String-dynamic.
final userAchievementsProvider =
    FutureProvider.autoDispose<List<UserAchievement>>((ref) async {
  // Block until auth is confirmed active; re-run on any auth state change.
  final authState = ref.watch(authStateProvider);
  final isAuthenticated = authState.valueOrNull ?? false;
  if (!isAuthenticated) {
    debugPrint('SiE Achievements: auth not ready — waiting');
    return [];
  }

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    debugPrint('SiE Achievements: currentUser is null — returning empty');
    return [];
  }

  try {
    final data = await client
        .from('achievements')
        .select('*, user_achievements(*)')
        .order('slug');

    debugPrint('SiE Achievements: fetched ${data.length} achievement(s)');

    return data.map((row) {
      final ach = Achievement.fromMap(row);

      // whereType<Map>() is eager and safe — it skips any non-Map elements
      // rather than throwing, which makes it immune to Map<String,Object?>
      // vs Map<String,dynamic> runtime type mismatches from the JSON decoder.
      final rawList = row['user_achievements'];
      final userAchs = (rawList is List ? rawList : <dynamic>[])
          .whereType<Map>()
          .where((ua) => ua['user_id'] == userId)
          .toList();

      final earned = userAchs.isNotEmpty;
      final earnedAt = earned
          ? DateTime.tryParse('${userAchs.first['earned_at'] ?? ''}')
          : null;

      debugPrint('SiE Achievements: [${ach.slug}] earned=$earned');
      return UserAchievement(
          achievement: ach, earned: earned, earnedAt: earnedAt);
    }).toList();
  } catch (e) {
    debugPrint('SiE Achievements: offline fallback — $e');
    return [];
  }
});
