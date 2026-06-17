import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import '../local/app_database.dart';
import '../models/profile.dart';
import '../supabase_service.dart';
import 'auth_state_provider.dart';

class UserProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    ref.watch(authStateProvider);
    return _fetchFromServer();
  }

  Future<Profile?> _fetchFromServer() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data == null) return null;
      final profile = Profile.fromJson(data);

      // Preserve any pending XP/DP that hasn't been flushed to the server yet.
      final db = ref.read(appDatabaseProvider);
      final existing = await db.getProfile(user.id);
      final pendingXp = existing?.pendingXp ?? 0;
      final pendingDp = existing?.pendingDp ?? 0;

      await db.upsertProfile(LocalProfilesCompanion(
        userId: Value(user.id),
        totalXp: Value(profile.totalXp + pendingXp),
        designPoints: Value(profile.designPoints + pendingDp),
        pendingXp: Value(pendingXp),
        pendingDp: Value(pendingDp),
        cachedJson: Value(jsonEncode(data)),
      ));
      if (pendingXp == 0 && pendingDp == 0) return profile;
      return profile.copyWith(
        totalXp: profile.totalXp + pendingXp,
        designPoints: profile.designPoints + pendingDp,
      );
    } catch (_) {
      // Offline fallback: reconstruct from local cache.
      final db = ref.read(appDatabaseProvider);
      final local = await db.getProfile(user.id);
      if (local == null) return null;
      if (local.cachedJson != null) {
        final json = jsonDecode(local.cachedJson!) as Map<String, dynamic>;
        return Profile.fromJson({
          ...json,
          'total_xp': local.totalXp,
          'design_points': local.designPoints,
        });
      }
      return Profile(
        id: user.id,
        totalXp: local.totalXp,
        designPoints: local.designPoints,
        isLabMember: false,
      );
    }
  }

  /// Immediately increments XP/DP in the local cache and updates the in-memory
  /// state so the XP bar updates without a network round-trip.
  Future<void> applyLocalXpDelta(int xp, int dp) async {
    if (xp == 0 && dp == 0) return;
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    final db = ref.read(appDatabaseProvider);
    var local = await db.getProfile(user.id);
    if (local == null) {
      // No cached profile yet — seed one with the delta.
      await db.upsertProfile(LocalProfilesCompanion(
        userId: Value(user.id),
        totalXp: Value(xp),
        designPoints: Value(dp),
        pendingXp: Value(xp),
        pendingDp: Value(dp),
      ));
      local = await db.getProfile(user.id);
    } else {
      await db.applyXpDelta(user.id, xp, dp);
      local = await db.getProfile(user.id);
    }

    if (local == null) return;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
        totalXp: local.totalXp,
        designPoints: local.designPoints,
      ));
    }
  }

  /// Re-fetches from Supabase and overwrites local cache. Called after sync.
  Future<void> reconcileFromServer() async {
    state = await AsyncValue.guard(_fetchFromServer);
  }
}

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, Profile?>(
  UserProfileNotifier.new,
);

Future<void> markWelcomeSeen(String userId) async {
  await SupabaseService.client
      .from('profiles')
      .update({'has_seen_welcome': true}).eq('id', userId);
}

Future<void> markOnboardingSeen(String tool) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return;
  await SupabaseService.client
      .from('profiles')
      .update({'has_seen_onboarding_$tool': true}).eq('id', userId);
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
        fileOptions:
            const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
  final baseUrl =
      SupabaseService.client.storage.from('avatars').getPublicUrl(path);
  final url = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  await SupabaseService.client
      .from('profiles')
      .update({'avatar_url': url}).eq('id', userId);
  return url;
}

Future<void> changePassword(String newPassword) async {
  await SupabaseService.client.auth
      .updateUser(UserAttributes(password: newPassword));
}

Future<void> addDesignPoints(int amount) async {
  await SupabaseService.client
      .rpc('add_design_points', params: {'p_amount': amount});
}
