import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_service.dart';
import 'planning_provider.dart';

final goalCollaborationProvider = Provider<GoalCollaborationNotifier>((ref) {
  return GoalCollaborationNotifier(ref);
});

class GoalCollaborationNotifier {
  final Ref _ref;
  const GoalCollaborationNotifier(this._ref);

  Future<void> invite(String goalId, String userId, String role) async {
    final myId = SupabaseService.client.auth.currentUser?.id;
    if (myId == null) return;
    await SupabaseService.client.from('goal_collaborators').insert({
      'goal_id': goalId,
      'user_id': userId,
      'invited_by': myId,
      'role': role,
    });
    _ref.invalidate(planningProvider);
  }

  Future<void> remove(String goalId, String userId) async {
    await SupabaseService.client
        .from('goal_collaborators')
        .delete()
        .eq('goal_id', goalId)
        .eq('user_id', userId);
    _ref.invalidate(planningProvider);
  }

  Future<void> updateRole(String goalId, String userId, String newRole) async {
    await SupabaseService.client
        .from('goal_collaborators')
        .update({'role': newRole})
        .eq('goal_id', goalId)
        .eq('user_id', userId);
    _ref.invalidate(planningProvider);
  }

  Future<void> accept(String goalId) async {
    final myId = SupabaseService.client.auth.currentUser?.id;
    if (myId == null) return;
    await SupabaseService.client
        .from('goal_collaborators')
        .update({'status': 'accepted'})
        .eq('goal_id', goalId)
        .eq('user_id', myId);
    _ref.invalidate(planningProvider);
  }

  Future<void> decline(String goalId) async {
    final myId = SupabaseService.client.auth.currentUser?.id;
    if (myId == null) return;
    await SupabaseService.client
        .from('goal_collaborators')
        .update({'status': 'declined'})
        .eq('goal_id', goalId)
        .eq('user_id', myId);
  }
}
