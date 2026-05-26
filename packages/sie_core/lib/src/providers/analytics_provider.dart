import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_data.dart';

const _habitXp = 50;
const _focusXp = 100;

final analyticsProvider =
    FutureProvider.autoDispose<AnalyticsData>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    return AnalyticsData(
      heatMap: {},
      xpHistory: [],
      focusByDay: [],
      totalFocusMinutes: 0,
      habitCompletionRate: 0,
      currentStreak: 0,
    );
  }

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  try {
    final results = await Future.wait([
      // habit_logs last 91 days (heat map + XP + completion rate + streak)
      client
          .from('habit_logs')
          .select('completed_at, xp_awarded')
          .eq('user_id', userId)
          .gte('completed_at',
              todayDate.subtract(const Duration(days: 90)).toIso8601String())
          .order('completed_at'),

      // focus_sessions last 91 days (heat map + focus bar chart + total)
      client
          .from('focus_sessions')
          .select('created_at, duration_seconds, xp_gained')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .gte('created_at',
              todayDate.subtract(const Duration(days: 90)).toIso8601String())
          .order('created_at'),

      // habit count for completion rate denominator
      client.from('habits').select('id').eq('user_id', userId),

      // sample up to 5 habit_logs (achievement threshold check)
      client
          .from('habit_logs')
          .select('id')
          .eq('user_id', userId)
          .limit(5),
    ]);

    final habitLogs = results[0] as List<dynamic>;
    final focusSessions = results[1] as List<dynamic>;
    final habits = results[2] as List<dynamic>;
    final logSample = results[3] as List<dynamic>;
    final totalLogCount = logSample.length;

    // ── Heat map ──────────────────────────────────────────────
    final heatMap = <DateTime, int>{};

    for (final row in habitLogs) {
      final d = _parseDate(row['completed_at'] as String);
      heatMap[d] = (heatMap[d] ?? 0) + 1;
    }
    for (final row in focusSessions) {
      final d = _parseDate((row['created_at'] as String).substring(0, 10));
      heatMap[d] = (heatMap[d] ?? 0) + 1;
    }

    // ── XP history (last 7 days) ───────────────────────────────
    final xpByDay = <DateTime, int>{};
    for (final row in habitLogs) {
      final d = _parseDate(row['completed_at'] as String);
      if (todayDate.difference(d).inDays < 7) {
        xpByDay[d] = (xpByDay[d] ?? 0) + ((row['xp_awarded'] as int?) ?? _habitXp);
      }
    }
    for (final row in focusSessions) {
      final d = _parseDate((row['created_at'] as String).substring(0, 10));
      if (todayDate.difference(d).inDays < 7) {
        xpByDay[d] = (xpByDay[d] ?? 0) + ((row['xp_gained'] as int?) ?? _focusXp);
      }
    }
    final xpHistory = List.generate(7, (i) {
      final d = todayDate.subtract(Duration(days: 6 - i));
      return DayXp(d, xpByDay[d] ?? 0);
    });

    // ── Focus by day (last 7 days) ────────────────────────────
    final focusSecsByDay = <DateTime, int>{};
    for (final row in focusSessions) {
      final d = _parseDate((row['created_at'] as String).substring(0, 10));
      if (todayDate.difference(d).inDays < 7) {
        focusSecsByDay[d] =
            (focusSecsByDay[d] ?? 0) + ((row['duration_seconds'] as int?) ?? 0);
      }
    }
    final focusByDay = List.generate(7, (i) {
      final d = todayDate.subtract(Duration(days: 6 - i));
      return DayFocus(d, (focusSecsByDay[d] ?? 0) ~/ 60);
    });

    // ── Total focus ───────────────────────────────────────────
    int totalFocusSecs = 0;
    for (final row in focusSessions) {
      totalFocusSecs += (row['duration_seconds'] as int?) ?? 0;
    }

    // ── Habit completion rate (last 30 days) ──────────────────
    double habitCompletionRate = 0;
    if (habits.isNotEmpty) {
      final habitCount = habits.length;
      final logDays30 = <DateTime>{};
      for (final row in habitLogs) {
        final d = _parseDate(row['completed_at'] as String);
        if (todayDate.difference(d).inDays < 30) logDays30.add(d);
      }
      // Count unique habit completions in last 30 days
      int completionsLast30 = 0;
      for (final row in habitLogs) {
        final d = _parseDate(row['completed_at'] as String);
        if (todayDate.difference(d).inDays < 30) completionsLast30++;
      }
      habitCompletionRate =
          (completionsLast30 / (habitCount * 30)).clamp(0.0, 1.0);
    }

    // ── Streak (consecutive days with at least one habit log) ─
    int streak = 0;
    final logDates = habitLogs
        .map((r) => _parseDate(r['completed_at'] as String))
        .toSet();
    for (var i = 0;; i++) {
      final d = todayDate.subtract(Duration(days: i));
      if (logDates.contains(d)) {
        streak++;
      } else {
        break;
      }
    }

    // ── Achievement: data_analyst ─────────────────────────────
    if (totalLogCount >= 5) {
      _tryAwardDataAnalyst(client, userId);
    }

    return AnalyticsData(
      heatMap: heatMap,
      xpHistory: xpHistory,
      focusByDay: focusByDay,
      totalFocusMinutes: totalFocusSecs ~/ 60,
      habitCompletionRate: habitCompletionRate,
      currentStreak: streak,
    );
  } catch (e) {
    debugPrint('SiE Analytics: offline fallback — $e');
    return AnalyticsData(
      heatMap: {},
      xpHistory: List.generate(7, (i) {
        final d = todayDate.subtract(Duration(days: 6 - i));
        return DayXp(d, 0);
      }),
      focusByDay: List.generate(7, (i) {
        final d = todayDate.subtract(Duration(days: 6 - i));
        return DayFocus(d, 0);
      }),
      totalFocusMinutes: 0,
      habitCompletionRate: 0,
      currentStreak: 0,
    );
  }
});

DateTime _parseDate(String s) {
  final parts = s.substring(0, 10).split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

Future<void> _tryAwardDataAnalyst(
    SupabaseClient client, String userId) async {
  try {
    final achRow = await client
        .from('achievements')
        .select()
        .eq('slug', 'data_analyst')
        .maybeSingle();
    if (achRow == null) return;

    final already = await client
        .from('user_achievements')
        .select('id')
        .eq('user_id', userId)
        .eq('achievement_id', achRow['id'] as String)
        .maybeSingle();
    if (already != null) return;

    await client.from('user_achievements').insert({
      'user_id': userId,
      'achievement_id': achRow['id'],
    });
  } catch (e) {
    debugPrint('SiE Analytics: achievement error — $e');
  }
}
