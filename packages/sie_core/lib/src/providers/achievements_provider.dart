import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/achievement.dart';
import '../supabase_service.dart';

typedef SessionResult = ({int xpGained, Achievement? newAchievement});

class SessionCompletionNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<SessionResult> completeSession({required int durationSeconds}) async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final xp = ((durationSeconds / 60.0) * 10).round().clamp(10, 9999);

    await client.rpc('increment_xp', params: {
      'p_user_id': userId,
      'p_amount': xp,
    });

    // First-ever breathing session → earn 'first_breath'
    Achievement? earned;
    final existing = await client
        .from('user_achievements')
        .select('id')
        .eq('user_id', userId)
        .limit(1);

    if ((existing as List).isEmpty) {
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
        earned = Achievement.fromJson(ach as Map<String, dynamic>);
      }
    }

    return (xpGained: xp, newAchievement: earned);
  }
}

final sessionCompletionProvider =
    NotifierProvider<SessionCompletionNotifier, void>(
  SessionCompletionNotifier.new,
);
