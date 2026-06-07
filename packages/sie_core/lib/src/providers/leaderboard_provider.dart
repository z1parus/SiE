import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard_entry.dart';
import '../supabase_service.dart';
import 'user_timezone_provider.dart';

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

// Emits the remaining duration until next midnight in the user's timezone,
// ticking every second. Uses a server clock offset for anti-spoofing.
final countdownProvider =
    StreamProvider.autoDispose<Duration>((ref) async* {
  var serverOffset = Duration.zero;
  try {
    final serverTime = await ref.read(serverTimeProvider.future);
    serverOffset = serverTime.difference(DateTime.now().toUtc());
  } catch (_) {}

  // User-configured timezone offset (auto-detected on first use).
  var tzOffset = DateTime.now().timeZoneOffset;
  try {
    tzOffset = await ref.read(userTimezoneProvider.future);
  } catch (_) {}

  // Re-run whenever the user changes their timezone.
  ref.listen(userTimezoneProvider, (_, next) {
    final offset = next.valueOrNull;
    if (offset != null) tzOffset = offset;
  });

  while (true) {
    final utcNow = DateTime.now().toUtc().add(serverOffset);
    // Translate to user's configured timezone.
    final localNow = utcNow.add(tzOffset);
    // Next midnight in user's timezone.
    final localMidnight =
        DateTime(localNow.year, localNow.month, localNow.day + 1);
    final remaining = localMidnight.difference(localNow);
    yield remaining < Duration.zero ? Duration.zero : remaining;
    await Future.delayed(const Duration(seconds: 1));
  }
});
