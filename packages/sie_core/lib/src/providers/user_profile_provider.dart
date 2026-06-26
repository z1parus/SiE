import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import '../local/app_database.dart';
import '../models/profile.dart';
import '../supabase_service.dart';
import 'auth_state_provider.dart';
import 'connectivity_provider.dart';

class UserProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // Track auth changes so the provider rebuilds on login/logout.
    // Read the value (not .future) to avoid auto-propagation of AsyncError
    // from the stream provider — profile loading has its own fallback.
    ref.watch(authStateProvider).valueOrNull;
    return _fetchFromServer();
  }

  Future<Profile?> _fetchFromServer() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      debugPrint('SiE Profile: currentUser is null — skipping fetch');
      return null;
    }

    // Fast offline path: skip Supabase and load from local cache immediately.
    // Without this the provider would stay in loading state for 60+ seconds
    // while waiting for the OS-level TCP timeout to expire.
    if (!isOnlineSync(ref)) {
      debugPrint('SiE Profile: offline — loading from local cache');
      try {
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
      } catch (e) {
        debugPrint('SiE Profile: local cache read failed offline — $e');
        return null;
      }
    }

    // ── Step 1: Fetch from Supabase ───────────────────────────────────────────
    // Isolated so a network error never loses already-fetched data.
    Profile? serverProfile;
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) {
        serverProfile = Profile.fromJson(data);
        debugPrint('SiE Profile: server fetch OK — ${serverProfile.username}');
      }
    } catch (e, st) {
      debugPrint('SiE Profile: Supabase fetch failed — $e\n$st');
    }

    // ── Step 2: Merge pending XP/DP and write local cache ────────────────────
    // If DB fails here we still return the live server data — never discard it.
    if (serverProfile != null) {
      try {
        final db = ref.read(appDatabaseProvider);
        final existing = await db.getProfile(user.id);
        final pendingXp = existing?.pendingXp ?? 0;
        final pendingDp = existing?.pendingDp ?? 0;

        await db.upsertProfile(LocalProfilesCompanion(
          userId: Value(user.id),
          totalXp: Value(serverProfile.totalXp + pendingXp),
          designPoints: Value(serverProfile.designPoints + pendingDp),
          pendingXp: Value(pendingXp),
          pendingDp: Value(pendingDp),
          cachedJson: Value(jsonEncode({
            'id': user.id,
            'username': serverProfile.username,
            'full_name': serverProfile.fullName,
            'avatar_url': serverProfile.avatarUrl,
            'total_xp': serverProfile.totalXp,
            'design_points': serverProfile.designPoints,
            'is_lab_member': serverProfile.isLabMember,
            'has_seen_welcome': serverProfile.hasSeenWelcome,
            'has_seen_onboarding_breathing': serverProfile.hasSeenOnboardingBreathing,
            'has_seen_onboarding_habits': serverProfile.hasSeenOnboardingHabits,
            'has_seen_onboarding_focus': serverProfile.hasSeenOnboardingFocus,
            'equipped_frame_id': serverProfile.equippedFrameId,
            'equipped_background_id': serverProfile.equippedBackgroundId,
            'equipped_stat_style_id': serverProfile.equippedStatStyleId,
            'equipped_pattern_id': serverProfile.equippedPatternId,
            'telegram_id': serverProfile.telegramId,
            'telegram_username': serverProfile.telegramUsername,
          })),
        ));
        if (pendingXp == 0 && pendingDp == 0) return serverProfile;
        return serverProfile.copyWith(
          totalXp: serverProfile.totalXp + pendingXp,
          designPoints: serverProfile.designPoints + pendingDp,
        );
      } catch (e) {
        debugPrint('SiE Profile: DB cache write failed (returning server data anyway) — $e');
        return serverProfile;
      }
    }

    // ── Step 3: Supabase failed — try local cache ─────────────────────────────
    try {
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
    } catch (e2) {
      debugPrint('SiE Profile: local cache fallback also failed — $e2');
      return null;
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
