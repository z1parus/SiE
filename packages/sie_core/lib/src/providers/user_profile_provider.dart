import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

Future<void> updateProfileInfo({
  required String username,
  required String fullName,
}) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return;
  await SupabaseService.client.from('profiles').update({
    'username': username,
    'full_name': fullName.isEmpty ? null : fullName,
  }).eq('id', userId);
}

Future<String?> uploadAvatar(Uint8List bytes) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return null;
  final path = '$userId/avatar.jpg';
  await SupabaseService.client.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
  final url =
      SupabaseService.client.storage.from('avatars').getPublicUrl(path);
  await SupabaseService.client
      .from('profiles')
      .update({'avatar_url': url})
      .eq('id', userId);
  return url;
}

Future<void> changePassword(String newPassword) async {
  await SupabaseService.client.auth
      .updateUser(UserAttributes(password: newPassword));
}
