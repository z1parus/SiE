import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cosmetic_asset.dart';
import '../supabase_service.dart';

final avatarFramesProvider = FutureProvider<List<CosmeticAsset>>((ref) async {
  final data = await SupabaseService.client
      .from('avatar_frames')
      .select()
      .order('rarity');
  return data
      .map((r) => CosmeticAsset.fromJson(r, AssetType.avatarFrame))
      .toList();
});

final profileBackgroundsProvider =
    FutureProvider<List<CosmeticAsset>>((ref) async {
  final data = await SupabaseService.client
      .from('profile_backgrounds')
      .select()
      .order('rarity');
  return data
      .map((r) => CosmeticAsset.fromJson(r, AssetType.profileBackground))
      .toList();
});

final statStylesProvider = FutureProvider<List<CosmeticAsset>>((ref) async {
  final data = await SupabaseService.client
      .from('stat_styles')
      .select()
      .order('rarity');
  return data
      .map((r) => CosmeticAsset.fromJson(r, AssetType.statStyle))
      .toList();
});

final profilePatternsProvider =
    FutureProvider<List<CosmeticAsset>>((ref) async {
  final data = await SupabaseService.client
      .from('profile_patterns')
      .select()
      .order('rarity');
  return data
      .map((r) => CosmeticAsset.fromJson(r, AssetType.profilePattern))
      .toList();
});

Future<void> applyCustomization({
  required String? frameId,
  required String? backgroundId,
  required String? styleId,
  required String? patternId,
}) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return;
  await SupabaseService.client.from('profiles').update({
    'equipped_frame_id': frameId,
    'equipped_background_id': backgroundId,
    'equipped_stat_style_id': styleId,
    'equipped_pattern_id': patternId,
  }).eq('id', userId);
}
