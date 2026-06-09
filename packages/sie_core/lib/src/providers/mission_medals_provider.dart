import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/app_database.dart';
import '../models/mission_medal.dart';
import '../models/planning.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';
import 'package:drift/drift.dart' show Value;

final missionMedalsProvider =
    AutoDisposeFutureProvider<List<MissionMedal>>((ref) async {
  ref.watch(authStateProvider);

  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final db = ref.read(appDatabaseProvider);
  final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;

  if (isOnline) {
    try {
      final raw = await Supabase.instance.client
          .from('mission_medals')
          .select()
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      for (final row in raw as List) {
        final m = row as Map<String, dynamic>;
        await db.upsertMedalLocally(LocalMissionMedalsCompanion(
          id: Value(m['id'] as String),
          userId: Value(m['user_id'] as String),
          goalId: Value(m['goal_id'] as String),
          goalName: const Value(''),
          category: Value(m['category'] as String? ?? 'none'),
          level: Value((m['level'] as num).toInt()),
          name: Value(m['name'] as String),
          earnedAtMs: Value(
              DateTime.parse(m['earned_at'] as String).millisecondsSinceEpoch),
          totalTaskWeight:
              Value((m['total_task_weight'] as num?)?.toInt() ?? 0),
          durationDays: Value((m['duration_days'] as num?)?.toInt() ?? 0),
          synced: const Value(true),
        ));
      }
    } catch (_) {
      // fall through to local
    }
  }

  final local = await db.medalsForUser(userId);
  return local.map(_fromLocal).toList();
});

final publicMissionMedalsProvider =
    AutoDisposeFutureProvider.family<List<MissionMedal>, String>((ref, userId) async {
  try {
    final raw = await Supabase.instance.client
        .from('mission_medals')
        .select()
        .eq('user_id', userId)
        .order('earned_at', ascending: false);

    return (raw as List)
        .map((r) => _fromRemote(r as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

MissionMedal _fromLocal(LocalMissionMedal r) {
  final catStr = r.category;
  final cat = catStr != 'none'
      ? GoalCategory.values.where((e) => e.name == catStr).firstOrNull
      : null;
  return MissionMedal(
    id: r.id,
    userId: r.userId,
    goalId: r.goalId,
    goalName: r.goalName,
    category: cat,
    level: r.level,
    name: r.name,
    earnedAt: DateTime.fromMillisecondsSinceEpoch(r.earnedAtMs),
    totalTaskWeight: r.totalTaskWeight,
    durationDays: r.durationDays,
  );
}

MissionMedal _fromRemote(Map<String, dynamic> m) {
  final catStr = m['category'] as String?;
  final cat = catStr != null && catStr != 'none'
      ? GoalCategory.values.where((e) => e.name == catStr).firstOrNull
      : null;
  return MissionMedal(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    goalId: m['goal_id'] as String,
    goalName: '',
    category: cat,
    level: (m['level'] as num).toInt(),
    name: m['name'] as String,
    earnedAt: DateTime.parse(m['earned_at'] as String),
    totalTaskWeight: (m['total_task_weight'] as num?)?.toInt() ?? 0,
    durationDays: (m['duration_days'] as num?)?.toInt() ?? 0,
  );
}
