import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/app_database.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';

class MeditationStats {
  final int zenStreakDays;
  final int claritySecondsThisWeek;
  final int clarityXpLevel;
  final double clarityXpProgress;
  final int totalSessionCount;

  const MeditationStats({
    this.zenStreakDays = 0,
    this.claritySecondsThisWeek = 0,
    this.clarityXpLevel = 1,
    this.clarityXpProgress = 0,
    this.totalSessionCount = 0,
  });
}

final meditationStatsProvider =
    AutoDisposeFutureProvider<MeditationStats>((ref) async {
  ref.watch(authStateProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const MeditationStats();

  final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
  final db = ref.read(appDatabaseProvider);
  final localWeekSecs = await db.meditationSecondsThisWeek(userId);

  if (isOnline) {
    try {
      final client = Supabase.instance.client;

      final profileRow = await client
          .from('profiles')
          .select('zen_streak_days')
          .eq('id', userId)
          .single();
      final streak = (profileRow['zen_streak_days'] as num?)?.toInt() ?? 0;

      final now = DateTime.now().toUtc();
      final weekAgo = now.subtract(const Duration(days: 7)).toIso8601String();

      final allLogs = await client
          .from('meditation_logs')
          .select('xp_awarded, duration_seconds, completed_at')
          .eq('user_id', userId);

      int totalXp = 0;
      int weekSecs = 0;
      int totalCount = 0;

      for (final r in (allLogs as List)) {
        final xp = (r['xp_awarded'] as num?)?.toInt() ?? 0;
        final secs = (r['duration_seconds'] as num?)?.toInt() ?? 0;
        final completedAt = r['completed_at'] as String?;
        totalXp += xp;
        totalCount++;
        if (completedAt != null &&
            DateTime.tryParse(completedAt)?.isAfter(
                    DateTime.tryParse(weekAgo) ?? now) ==
                true) {
          weekSecs += secs;
        }
      }

      return MeditationStats(
        zenStreakDays: streak,
        claritySecondsThisWeek: weekSecs,
        clarityXpLevel: totalXp ~/ 500 + 1,
        clarityXpProgress: (totalXp % 500) / 500,
        totalSessionCount: totalCount,
      );
    } catch (_) {}
  }

  return MeditationStats(claritySecondsThisWeek: localWeekSecs);
});
