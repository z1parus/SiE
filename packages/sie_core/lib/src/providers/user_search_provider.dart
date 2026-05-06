import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/achievement.dart';
import '../models/public_profile.dart';
import '../supabase_service.dart';

final userSearchProvider = FutureProvider.autoDispose
    .family<List<PublicProfile>, String>((ref, query) async {
  final q = query.trim();
  if (q.length < 2) return [];

  final data = await SupabaseService.client
      .from('profiles')
      .select(
          'id, username, avatar_url, avatar_frame_id, profile_background_url, total_xp')
      .ilike('username', '%$q%')
      .order('total_xp', ascending: false)
      .limit(30);

  return data.map((r) => PublicProfile.fromJson(r)).toList();
});

// Aggregate stats for any operative via SECURITY DEFINER RPC.
final publicStatsProvider = FutureProvider.autoDispose
    .family<PublicProfileStats, String>((ref, userId) async {
  try {
    final result = await SupabaseService.client
        .rpc('get_operative_stats', params: {'p_user_id': userId});
    if (result == null) return PublicProfileStats.zero();
    return PublicProfileStats.fromJson(result as Map<String, dynamic>);
  } catch (_) {
    return PublicProfileStats.zero();
  }
});

// All achievements with per-user earned status — used on the public dossier.
// Requires the 'authenticated can read user_achievements' policy (migration 20260507000002).
final publicAchievementsProvider = FutureProvider.autoDispose
    .family<List<UserAchievement>, String>((ref, userId) async {
  final data = await SupabaseService.client
      .from('achievements')
      .select('*, user_achievements(*)')
      .order('slug');

  return data.map((row) {
    final ach = Achievement.fromMap(row);
    final rawList = row['user_achievements'];
    final userAchs = (rawList is List ? rawList : <dynamic>[])
        .whereType<Map>()
        .where((ua) => ua['user_id'] == userId)
        .toList();
    final earned = userAchs.isNotEmpty;
    final earnedAt = earned
        ? DateTime.tryParse('${userAchs.first['earned_at'] ?? ''}')
        : null;
    return UserAchievement(achievement: ach, earned: earned, earnedAt: earnedAt);
  }).toList();
});
