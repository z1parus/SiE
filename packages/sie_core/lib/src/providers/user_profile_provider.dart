import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../supabase_service.dart';
import 'auth_state_provider.dart';

final userProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider); // re-run on every auth change

  final user = SupabaseService.client.auth.currentUser;
  if (user == null) return null;

  final data = await SupabaseService.client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return Profile.fromJson(data);
});

Future<void> markWelcomeSeen(String userId) async {
  await SupabaseService.client
      .from('profiles')
      .update({'has_seen_welcome': true})
      .eq('id', userId);
}

Future<void> markOnboardingSeen(String tool) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return;
  await SupabaseService.client
      .from('profiles')
      .update({'has_seen_onboarding_$tool': true})
      .eq('id', userId);
}
