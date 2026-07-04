import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/app_database.dart';
import '../models/breathing_session.dart';
import 'connectivity_provider.dart';

/// Every breathing-practice session the current user has logged, newest first.
/// Offline-first read model: when online it pulls from Supabase and mirrors the
/// rows into the Drift cache; otherwise it serves the cache. Sessions are
/// written by [SessionCompletionNotifier]; this provider is read-only and is
/// invalidated after a new session is logged.
final breathingJournalProvider = AsyncNotifierProvider.autoDispose<
    BreathingJournalNotifier, List<BreathingSession>>(
  BreathingJournalNotifier.new,
);

class BreathingJournalNotifier
    extends AutoDisposeAsyncNotifier<List<BreathingSession>> {
  @override
  Future<List<BreathingSession>> build() async {
    ref.watch(connectivityProvider);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final db = ref.read(appDatabaseProvider);
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

    if (isOnline) {
      try {
        final raw = await client
            .from('breathing_sessions')
            .select()
            .eq('user_id', userId)
            .order('completed_at', ascending: false);
        final sessions = (raw as List)
            .map((r) => BreathingSession.fromMap(r as Map<String, dynamic>))
            .toList();
        for (final s in sessions) {
          await db.insertBreathingSession(_companion(s, synced: true));
        }
        return sessions;
      } catch (_) {
        // fall through to the local cache
      }
    }
    return _loadLocal(db, userId);
  }

  Future<List<BreathingSession>> _loadLocal(
      AppDatabase db, String userId) async {
    final rows = await db.breathingSessionsForUser(userId);
    return rows.map(_fromLocal).toList();
  }

  LocalBreathingSessionsCompanion _companion(BreathingSession s,
          {required bool synced}) =>
      LocalBreathingSessionsCompanion(
        id: Value(s.id),
        userId: Value(s.userId),
        durationSeconds: Value(s.durationSeconds),
        completedAtMs: Value(s.completedAt.millisecondsSinceEpoch),
        xpAwarded: Value(s.xpAwarded),
        dpAwarded: Value(s.dpAwarded),
        breaths: Value(s.breaths),
        rounds: Value(s.rounds),
        longestHoldSeconds: Value(s.longestHoldSeconds),
        totalHoldSeconds: Value(s.totalHoldSeconds),
        moodEmoji: Value(s.moodEmoji),
        calmness: Value(s.calmness),
        confidence: Value(s.confidence),
        meditationSessionId: Value(s.meditationSessionId),
        synced: Value(synced),
      );

  BreathingSession _fromLocal(LocalBreathingSession r) => BreathingSession(
        id: r.id,
        userId: r.userId,
        durationSeconds: r.durationSeconds,
        breaths: r.breaths,
        rounds: r.rounds,
        longestHoldSeconds: r.longestHoldSeconds,
        totalHoldSeconds: r.totalHoldSeconds,
        moodEmoji: r.moodEmoji,
        calmness: r.calmness,
        confidence: r.confidence,
        xpAwarded: r.xpAwarded,
        dpAwarded: r.dpAwarded,
        meditationSessionId: r.meditationSessionId,
        completedAt: DateTime.fromMillisecondsSinceEpoch(r.completedAtMs),
      );
}
