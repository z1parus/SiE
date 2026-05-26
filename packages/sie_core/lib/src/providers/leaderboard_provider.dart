import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard_entry.dart';
import '../supabase_service.dart';

final leaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  try {
    final data =
        await SupabaseService.client.rpc('get_daily_leaderboard');
    return (data as List<dynamic>)
        .map((r) =>
            LeaderboardEntry.fromJson(r as Map<String, dynamic>))
        .toList();
  } catch (e) {
    debugPrint('SiE Leaderboard: offline fallback — $e');
    return [];
  }
});

// Returns the authoritative server UTC timestamp — used to compute a
// clock-offset that prevents timezone spoofing in the countdown display.
final serverTimeProvider = FutureProvider<DateTime>((ref) async {
  try {
    final result =
        await SupabaseService.client.rpc('get_server_time');
    return DateTime.parse(result.toString()).toUtc();
  } catch (_) {
    return DateTime.now().toUtc();
  }
});

// Emits the remaining duration until next UTC midnight, ticking every second.
// Fetches a one-time server clock offset so the countdown is authoritative.
final countdownProvider =
    StreamProvider.autoDispose<Duration>((ref) async* {
  var serverOffset = Duration.zero;
  try {
    final serverTime = await ref.read(serverTimeProvider.future);
    serverOffset = serverTime.difference(DateTime.now().toUtc());
  } catch (_) {}

  while (true) {
    final now = DateTime.now().toUtc().add(serverOffset);
    final midnight =
        DateTime.utc(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    yield remaining < Duration.zero ? Duration.zero : remaining;
    await Future.delayed(const Duration(seconds: 1));
  }
});
