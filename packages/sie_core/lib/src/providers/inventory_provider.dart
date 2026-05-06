import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cosmetic_asset.dart';
import '../supabase_service.dart';
import 'auth_state_provider.dart';

class InventoryState {
  final Set<String> ownedFrameIds;
  final Set<String> ownedBackgroundIds;
  final Set<String> ownedStyleIds;

  const InventoryState({
    this.ownedFrameIds = const {},
    this.ownedBackgroundIds = const {},
    this.ownedStyleIds = const {},
  });

  static const empty = InventoryState();

  bool owns(CosmeticAsset asset) => switch (asset.type) {
        AssetType.avatarFrame       => ownedFrameIds.contains(asset.id),
        AssetType.profileBackground => ownedBackgroundIds.contains(asset.id),
        AssetType.statStyle         => ownedStyleIds.contains(asset.id),
      };
}

final inventoryProvider = FutureProvider.autoDispose<InventoryState>((ref) async {
  ref.watch(authStateProvider);
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return InventoryState.empty;

  final rows = await SupabaseService.client
      .from('user_inventory')
      .select('asset_type, asset_id')
      .eq('user_id', userId);

  final frames = <String>{};
  final backgrounds = <String>{};
  final styles = <String>{};

  for (final row in rows) {
    final id = row['asset_id'] as String;
    switch (row['asset_type'] as String) {
      case 'avatar_frame':
        frames.add(id);
      case 'profile_background':
        backgrounds.add(id);
      case 'stat_style':
        styles.add(id);
    }
  }

  return InventoryState(
    ownedFrameIds: frames,
    ownedBackgroundIds: backgrounds,
    ownedStyleIds: styles,
  );
});

Future<void> purchaseAsset(CosmeticAsset asset) async {
  await SupabaseService.client.rpc('purchase_asset', params: {
    'p_asset_id':   asset.id,
    'p_asset_type': asset.type.dbValue,
    'p_price_dp':   asset.priceDP,
  });
}

Future<void> equipAsset(CosmeticAsset asset) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return;
  final col = switch (asset.type) {
    AssetType.avatarFrame       => 'equipped_frame_id',
    AssetType.profileBackground => 'equipped_background_id',
    AssetType.statStyle         => 'equipped_stat_style_id',
  };
  await SupabaseService.client
      .from('profiles')
      .update({col: asset.id})
      .eq('id', userId);
}
