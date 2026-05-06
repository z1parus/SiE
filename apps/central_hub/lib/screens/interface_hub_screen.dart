import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

class InterfaceHubScreen extends ConsumerStatefulWidget {
  const InterfaceHubScreen({super.key});

  @override
  ConsumerState<InterfaceHubScreen> createState() => _InterfaceHubScreenState();
}

class _InterfaceHubScreenState extends ConsumerState<InterfaceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _buyingId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _onBuy(CosmeticAsset asset) async {
    if (_buyingId != null) return;
    setState(() => _buyingId = asset.id);
    try {
      await purchaseAsset(asset);
      ref.invalidate(inventoryProvider);
      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      ref.read(audioServiceProvider).playPurchase().ignore();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ПРОТОКОЛ ВИЗУАЛИЗАЦИИ УСПЕШНО ПРИОБРЕТЁН'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final isInsufficient = e.toString().contains('INSUFFICIENT_DP');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInsufficient
                ? 'НЕДОСТАТОЧНО РЕСУРСОВ (DP)'
                : 'ОШИБКА ТРАНЗАКЦИИ',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  Future<void> _onEquip(CosmeticAsset asset) async {
    try {
      await equipAsset(asset);
      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ОСНАЩЕНИЕ ПРИМЕНЕНО')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ОШИБКА: $e')));
    }
  }

  void _showPreview(CosmeticAsset asset, Profile? profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SieTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        side: BorderSide(color: SieTheme.borderDefault),
      ),
      builder: (_) => _PreviewSheet(asset: asset, profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final frames = ref.watch(avatarFramesProvider).valueOrNull ?? [];
    final backgrounds =
        ref.watch(profileBackgroundsProvider).valueOrNull ?? [];
    final styles = ref.watch(statStylesProvider).valueOrNull ?? [];
    final inventory =
        ref.watch(inventoryProvider).valueOrNull ?? InventoryState.empty;
    final dp = profile?.designPoints ?? 0;

    return Scaffold(
      backgroundColor: SieTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(dp: dp, onBack: () => Navigator.of(context).pop()),
            Container(
                height: 1,
                color: SieTheme.borderAccent.withValues(alpha: 0.25)),
            Container(
              color: SieTheme.surface,
              child: TabBar(
                controller: _tabs,
                indicatorColor: SieTheme.accent,
                indicatorWeight: 1.5,
                labelColor: SieTheme.accent,
                unselectedLabelColor: SieTheme.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'РАМКИ'),
                  Tab(text: 'ФОНЫ'),
                  Tab(text: 'СТИЛИ'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ShopGrid(
                    assets: frames,
                    inventory: inventory,
                    profile: profile,
                    buyingId: _buyingId,
                    onBuy: _onBuy,
                    onEquip: _onEquip,
                    onPreview: (a) => _showPreview(a, profile),
                  ),
                  _ShopGrid(
                    assets: backgrounds,
                    inventory: inventory,
                    profile: profile,
                    buyingId: _buyingId,
                    onBuy: _onBuy,
                    onEquip: _onEquip,
                    onPreview: (a) => _showPreview(a, profile),
                  ),
                  _ShopGrid(
                    assets: styles,
                    inventory: inventory,
                    profile: profile,
                    buyingId: _buyingId,
                    onBuy: _onBuy,
                    onEquip: _onEquip,
                    onPreview: (a) => _showPreview(a, profile),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int dp;
  final VoidCallback onBack;
  const _TopBar({required this.dp, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new,
                color: SieTheme.textSecondary, size: 18),
          ),
          Expanded(
            child: Text(
              'ИНТЕРФЕЙС-ХАБ',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border:
                  Border.all(color: SieTheme.dp.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.palette_outlined,
                    size: 11,
                    color: SieTheme.dp.withValues(alpha: 0.9)),
                const SizedBox(width: 4),
                Text(
                  '$dp DP',
                  style: const TextStyle(
                    color: SieTheme.dp,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Shop Grid ─────────────────────────────────────────────────

class _ShopGrid extends StatelessWidget {
  final List<CosmeticAsset> assets;
  final InventoryState inventory;
  final Profile? profile;
  final String? buyingId;
  final Future<void> Function(CosmeticAsset) onBuy;
  final Future<void> Function(CosmeticAsset) onEquip;
  final void Function(CosmeticAsset) onPreview;

  const _ShopGrid({
    required this.assets,
    required this.inventory,
    required this.profile,
    required this.buyingId,
    required this.onBuy,
    required this.onEquip,
    required this.onPreview,
  });

  bool _isEquipped(CosmeticAsset asset) => switch (asset.type) {
        AssetType.avatarFrame =>
          profile?.equippedFrameId == asset.id,
        AssetType.profileBackground =>
          profile?.equippedBackgroundId == asset.id,
        AssetType.statStyle =>
          profile?.equippedStatStyleId == asset.id,
      };

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
            color: SieTheme.accent, strokeWidth: 1.5),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.70,
      ),
      itemCount: assets.length,
      itemBuilder: (_, i) {
        final asset = assets[i];
        final purchased = inventory.owns(asset);
        // Free items (price 0) are accessible without explicit purchase.
        final accessible = purchased || asset.priceDP == 0;
        final equipped = _isEquipped(asset);
        return _ShopCard(
          asset: asset,
          accessible: accessible,
          purchased: purchased,
          equipped: equipped,
          loading: buyingId == asset.id,
          dp: profile?.designPoints ?? 0,
          onBuy: () => onBuy(asset),
          onEquip: () => onEquip(asset),
          onPreview: () => onPreview(asset),
        );
      },
    );
  }
}

// ── Shop Card ─────────────────────────────────────────────────

class _ShopCard extends StatelessWidget {
  final CosmeticAsset asset;
  final bool accessible;
  final bool purchased;
  final bool equipped;
  final bool loading;
  final int dp;
  final VoidCallback onBuy;
  final VoidCallback onEquip;
  final VoidCallback onPreview;

  const _ShopCard({
    required this.asset,
    required this.accessible,
    required this.purchased,
    required this.equipped,
    required this.loading,
    required this.dp,
    required this.onBuy,
    required this.onEquip,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = dp >= asset.priceDP;
    final isFree = asset.priceDP == 0;

    return Container(
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(
          color: equipped
              ? SieTheme.accent
              : accessible
                  ? SieTheme.borderAccent.withValues(alpha: 0.5)
                  : SieTheme.borderDefault,
          width: equipped ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: equipped
            ? [
                BoxShadow(
                  color: SieTheme.accent.withValues(alpha: 0.1),
                  blurRadius: 8,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual area (tappable → preview)
          Expanded(
            child: GestureDetector(
              onTap: onPreview,
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: SieTheme.background.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
                child: Stack(
                  children: [
                    Center(child: _AssetVisualBig(asset: asset)),
                    // Equipped / purchased badge
                    if (equipped)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: _Badge(
                            label: 'АКТИВНО',
                            color: SieTheme.accent,
                            filled: true),
                      )
                    else if (purchased)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: _Badge(
                            label: 'КУПЛЕНО',
                            color: SieTheme.accentSecondary,
                            filled: false),
                      ),
                    // Preview eye icon
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: Icon(
                        Icons.visibility_outlined,
                        size: 11,
                        color: SieTheme.textSecondary
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    // Rarity dot
                    Positioned(
                      bottom: 6,
                      left: 8,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: asset.rarityColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: asset.rarityColor
                                  .withValues(alpha: 0.5),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Info + action
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SieTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  asset.rarityLabel,
                  style: TextStyle(
                    color: asset.rarityColor,
                    fontSize: 8,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!accessible) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 9,
                        color: canAfford
                            ? SieTheme.dp.withValues(alpha: 0.85)
                            : SieTheme.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${asset.priceDP} DP',
                        style: TextStyle(
                          color: canAfford
                              ? SieTheme.dp
                              : SieTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (!canAfford) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.lock_outline,
                            size: 9,
                            color: SieTheme.textSecondary),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                if (accessible)
                  _ActionButton(
                    label: equipped ? 'ЭКИПИРОВАНО' : 'ВЫБРАТЬ',
                    color: equipped
                        ? SieTheme.textSecondary
                        : SieTheme.accentSecondary,
                    enabled: !equipped,
                    loading: false,
                    onTap: equipped ? null : onEquip,
                  )
                else
                  _ActionButton(
                    label: loading
                        ? '...'
                        : (isFree ? 'ПОЛУЧИТЬ' : 'КУПИТЬ'),
                    color: canAfford
                        ? SieTheme.accent
                        : SieTheme.textSecondary,
                    enabled: !loading,
                    loading: loading,
                    onTap: loading ? null : onBuy,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Badge ────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _Badge(
      {required this.label, required this.color, required this.filled});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.9) : null,
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.black : color,
            fontSize: 7,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      );
}

// ── Action Button ─────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color:
              (enabled && !loading) ? color.withValues(alpha: 0.1) : null,
          border: Border.all(
              color: enabled ? color : SieTheme.borderDefault),
          borderRadius: BorderRadius.circular(2),
        ),
        child: loading
            ? Center(
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      color: color, strokeWidth: 1.5),
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? color : SieTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}

// ── Asset Visual (shop size) ──────────────────────────────────

class _AssetVisualBig extends StatelessWidget {
  final CosmeticAsset asset;
  const _AssetVisualBig({required this.asset});

  @override
  Widget build(BuildContext context) {
    if (asset.imageUrl != null) {
      return SizedBox(
        width: 72,
        height: 72,
        child: CachedNetworkImage(
          imageUrl: asset.imageUrl!,
          fit: BoxFit.contain,
          placeholder: (_, _) => const SizedBox(),
          errorWidget: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => switch (asset.type) {
        AssetType.avatarFrame       => _FrameVisual(asset: asset),
        AssetType.profileBackground => _BackgroundVisual(asset: asset),
        AssetType.statStyle         => _StatStyleVisual(asset: asset),
      };
}

class _FrameVisual extends StatelessWidget {
  final CosmeticAsset asset;
  const _FrameVisual({required this.asset});

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 64,
        decoration: asset.buildFrameDecoration(),
        child: const Icon(Icons.person_outline,
            color: SieTheme.textSecondary, size: 32),
      );
}

class _BackgroundVisual extends StatelessWidget {
  final CosmeticAsset asset;
  const _BackgroundVisual({required this.asset});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 84,
          height: 56,
          decoration: BoxDecoration(
            gradient: asset.backgroundGradient ??
                const LinearGradient(
                  colors: [Color(0xFF0D2A42), Color(0xFF071520)],
                ),
          ),
          child: CustomPaint(painter: _GridPainter()),
        ),
      );
}

class _StatStyleVisual extends StatelessWidget {
  final CosmeticAsset asset;
  const _StatStyleVisual({required this.asset});

  @override
  Widget build(BuildContext context) {
    final glow = asset.styleGlowColor;
    return Container(
      width: 72,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: asset.buildStatCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            width: 30,
            decoration: BoxDecoration(
              color: asset.accentColor,
              borderRadius: BorderRadius.circular(1),
              boxShadow: glow != null
                  ? [BoxShadow(color: glow, blurRadius: 5)]
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Container(
              height: 3,
              width: 18,
              color: asset.accentColor.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          Container(
              height: 3,
              width: 24,
              color: asset.accentColor.withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00C8FF).withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    const step = 14.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ── Preview Sheet ─────────────────────────────────────────────

class _PreviewSheet extends ConsumerWidget {
  final CosmeticAsset asset;
  final Profile? profile;
  const _PreviewSheet({required this.asset, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frames = ref.watch(avatarFramesProvider).valueOrNull ?? [];
    final backgrounds =
        ref.watch(profileBackgroundsProvider).valueOrNull ?? [];
    final styles = ref.watch(statStylesProvider).valueOrNull ?? [];

    // Substitute this asset into the current equipped set for the preview.
    final previewEquipped = EquippedAssets.resolve(
      frames: frames,
      backgrounds: backgrounds,
      styles: styles,
      frameId: asset.type == AssetType.avatarFrame
          ? asset.id
          : profile?.equippedFrameId,
      backgroundId: asset.type == AssetType.profileBackground
          ? asset.id
          : profile?.equippedBackgroundId,
      styleId: asset.type == AssetType.statStyle
          ? asset.id
          : profile?.equippedStatStyleId,
    );

    final letter = profile?.username?.isNotEmpty == true
        ? profile!.username![0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 3,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: SieTheme.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'ПРЕДПРОСМОТР',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Text(
            asset.name.toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Mini profile preview
          Container(
            height: 130,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              gradient: previewEquipped.background?.backgroundGradient ??
                  const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D2A42), Color(0xFF071520)],
                  ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: SieTheme.borderDefault),
            ),
            child: Stack(
              children: [
                CustomPaint(painter: _GridPainter(), size: Size.infinite),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          SieTheme.background.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration:
                            previewEquipped.frame?.buildFrameDecoration() ??
                                BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: SieTheme.borderAccent,
                                      width: 1.5),
                                  color: SieTheme.surface,
                                ),
                        child: ClipOval(
                          child: profile?.avatarUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: profile!.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      _LetterFill(letter: letter),
                                )
                              : _LetterFill(letter: letter),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (profile?.username ?? 'OPERATIVE').toUpperCase(),
                            style: const TextStyle(
                              color: SieTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: previewEquipped.statStyle
                                    ?.buildStatCardDecoration() ??
                                BoxDecoration(
                                  color: SieTheme.surface,
                                  border: Border.all(
                                      color: SieTheme.borderDefault),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                            child: Text(
                              'LVL ${((profile?.totalXp ?? 0) ~/ 1000) + 1}'
                              '  ·  ${profile?.totalXp ?? 0} XP',
                              style: TextStyle(
                                color:
                                    previewEquipped.statStyle?.accentColor ??
                                        SieTheme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  bottom: 5,
                  right: 10,
                  child: Text(
                    'ПРЕДПРОСМОТР',
                    style: TextStyle(
                      color: SieTheme.borderAccent,
                      fontSize: 7,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: asset.rarityColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: asset.rarityColor.withValues(alpha: 0.5),
                        blurRadius: 4)
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                asset.rarityLabel,
                style: TextStyle(
                  color: asset.rarityColor,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LetterFill extends StatelessWidget {
  final String letter;
  const _LetterFill({required this.letter});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: SieTheme.surface,
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(
              color: SieTheme.accent,
              fontSize: 22,
              fontWeight: FontWeight.w200,
            ),
          ),
        ),
      );
}
