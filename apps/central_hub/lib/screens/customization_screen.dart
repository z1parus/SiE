import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CustomizationScreen
// ─────────────────────────────────────────────────────────────────────────────
class CustomizationScreen extends ConsumerStatefulWidget {
  final Profile profile;
  const CustomizationScreen({super.key, required this.profile});

  @override
  ConsumerState<CustomizationScreen> createState() =>
      _CustomizationScreenState();
}

class _CustomizationScreenState extends ConsumerState<CustomizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _frameId;
  String? _backgroundId;
  String? _styleId;
  String? _patternId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs         = TabController(length: 4, vsync: this);
    _frameId      = widget.profile.equippedFrameId;
    _backgroundId = widget.profile.equippedBackgroundId;
    _styleId      = widget.profile.equippedStatStyleId;
    _patternId    = widget.profile.equippedPatternId;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final inventory = ref.read(inventoryProvider).valueOrNull ?? InventoryState.empty;
      final frames      = ref.read(avatarFramesProvider).valueOrNull ?? [];
      final backgrounds = ref.read(profileBackgroundsProvider).valueOrNull ?? [];
      final styles      = ref.read(statStylesProvider).valueOrNull ?? [];
      final patterns    = ref.read(profilePatternsProvider).valueOrNull ?? [];

      bool canApply(CosmeticAsset? asset) =>
          asset != null && (inventory.owns(asset) || asset.priceDP == 0);

      final safeFrameId = _frameId == null
          ? _frameId
          : canApply(frames.where((a) => a.id == _frameId).firstOrNull)
              ? _frameId
              : widget.profile.equippedFrameId;
      final safeBgId = _backgroundId == null
          ? _backgroundId
          : canApply(backgrounds.where((a) => a.id == _backgroundId).firstOrNull)
              ? _backgroundId
              : widget.profile.equippedBackgroundId;
      final safeStyleId = _styleId == null
          ? _styleId
          : canApply(styles.where((a) => a.id == _styleId).firstOrNull)
              ? _styleId
              : widget.profile.equippedStatStyleId;
      final safePatternId = _patternId == null
          ? _patternId
          : canApply(patterns.where((a) => a.id == _patternId).firstOrNull)
              ? _patternId
              : widget.profile.equippedPatternId;

      await applyCustomization(
        frameId: safeFrameId,
        backgroundId: safeBgId,
        styleId: safeStyleId,
        patternId: safePatternId,
      );
      ref.invalidate(userProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Проверьте подключение к интернету')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames      = ref.watch(avatarFramesProvider).valueOrNull ?? [];
    final backgrounds = ref.watch(profileBackgroundsProvider).valueOrNull ?? [];
    final styles      = ref.watch(statStylesProvider).valueOrNull ?? [];
    final patterns    = ref.watch(profilePatternsProvider).valueOrNull ?? [];
    final inventory   = ref.watch(inventoryProvider).valueOrNull ?? InventoryState.empty;

    final equipped = EquippedAssets.resolve(
      frames: frames,
      backgrounds: backgrounds,
      styles: styles,
      patterns: patterns,
      frameId: _frameId,
      backgroundId: _backgroundId,
      styleId: _styleId,
      patternId: _patternId,
    );

    final c = ref.watch(sieColorsProvider);
    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onSave: _saving ? null : _save),
              // Live preview panel
              _Preview(profile: widget.profile, equipped: equipped),
              // Tab bar
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: _buildTabBar(c),
              ),
              // Grid
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _AssetGrid(
                      assets: frames,
                      inventory: inventory,
                      selectedId: _frameId,
                      equippedId: widget.profile.equippedFrameId,
                      onSelect: (id) => setState(() => _frameId = id),
                    ),
                    _AssetGrid(
                      assets: backgrounds,
                      inventory: inventory,
                      selectedId: _backgroundId,
                      equippedId: widget.profile.equippedBackgroundId,
                      onSelect: (id) => setState(() => _backgroundId = id),
                    ),
                    _AssetGrid(
                      assets: styles,
                      inventory: inventory,
                      selectedId: _styleId,
                      equippedId: widget.profile.equippedStatStyleId,
                      onSelect: (id) => setState(() => _styleId = id),
                    ),
                    _AssetGrid(
                      assets: patterns,
                      inventory: inventory,
                      selectedId: _patternId,
                      equippedId: widget.profile.equippedPatternId,
                      onSelect: (id) => setState(() => _patternId = id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(SieColors c) {
    return TabBar(
      controller: _tabs,
      indicatorColor: c.accent,
      indicatorWeight: 1.5,
      labelColor: c.accent,
      unselectedLabelColor: c.textSecondary,
      labelStyle: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
      ),
      tabs: const [
        Tab(text: 'РАМКИ'),
        Tab(text: 'ФОНЫ'),
        Tab(text: 'СТИЛИ'),
        Tab(text: 'УЗОРЫ'),
      ],
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final VoidCallback? onSave;
  const _TopBar({required this.onSave});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new,
                color: c.textSecondary, size: 18),
          ),
          Expanded(
            child: Text(
              'НАСТРОЙКА ОБЛИКА',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          _SaveButton(onTap: onSave),
        ],
      ),
    );
  }
}

class _SaveButton extends ConsumerStatefulWidget {
  final VoidCallback? onTap;
  const _SaveButton({required this.onTap});

  @override
  ConsumerState<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<_SaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap != null
          ? (_) => _ctrl.animateTo(1.0,
              duration: const Duration(milliseconds: 80), curve: Curves.easeIn)
          : null,
      onTapUp: (_) => _ctrl.animateTo(0.0,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
      onTapCancel: () => _ctrl.animateTo(0.0,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final t = _ctrl.value;
          return Transform.scale(
            scale: 1.0 - 0.03 * t,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: widget.onTap != null
                    ? LinearGradient(
                        colors: [
                          Color.lerp(c.accent,
                              c.accent.withValues(alpha: 0.8), t)!,
                          Color.lerp(c.accentSecondary,
                              c.accentSecondary.withValues(alpha: 0.8), t)!,
                        ],
                      )
                    : null,
                boxShadow: widget.onTap != null
                    ? [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.18 + 0.25 * t),
                          blurRadius: 8.0 + 6.0 * t,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'ПРИМЕНИТЬ',
                style: TextStyle(
                  color: widget.onTap != null
                      ? Colors.white
                      : c.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Live Preview ──────────────────────────────────────────────

class _Preview extends ConsumerWidget {
  final Profile profile;
  final EquippedAssets equipped;
  const _Preview({required this.profile, required this.equipped});

  static BoxDecoration _cardDecoration(SieColors c, CosmeticAsset? bg) {
    if (bg?.backgroundColor != null) {
      return BoxDecoration(
        color: bg!.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.accentColor.withValues(alpha: 0.25)),
      );
    }
    if (bg?.backgroundGradient != null) {
      return BoxDecoration(
        gradient: bg!.backgroundGradient,
        borderRadius: BorderRadius.circular(20),
      );
    }
    return c.flatCard(radius: 20);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c         = ref.watch(sieColorsProvider);
    final bg        = equipped.background;
    final frame     = equipped.frame;
    final level     = (profile.totalXp ~/ 1000) + 1;
    final xpInLevel = profile.totalXp % 1000;
    final xpToNext  = 1000 - xpInLevel;
    final progress  = (xpInLevel / 1000.0).clamp(0.0, 1.0);
    final letter    = (profile.username?.isNotEmpty == true)
        ? profile.username![0].toUpperCase()
        : '?';

    final hasCustomBg = bg != null &&
        (bg.backgroundColor != null || bg.backgroundGradient != null);
    final textMain   = hasCustomBg ? Colors.white : c.textPrimary;
    final textSub    = hasCustomBg ? Colors.white60 : c.textSecondary;
    final showNeural = bg != null &&
        (bg.backgroundColor != null || bg.useNeuralPattern);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: _cardDecoration(c, bg),
        child: Stack(
          children: [
            if (showNeural)
              Positioned.fill(
                child: NeuralNetworkWidget(
                  color: bg.accentColor.withValues(alpha: 0.40),
                ),
              ),
            if (equipped.pattern != null)
              Positioned.fill(
                child: ProfilePatternRenderer(
                  pattern: equipped.pattern,
                  accentColor: bg?.accentColor ?? c.accent,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: frame?.buildFrameDecoration() ??
                            BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: c.accent.withValues(alpha: 0.6),
                                  width: 1.5),
                              color: c.surface,
                            ),
                        child: ClipOval(
                          child: profile.avatarUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: profile.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      _LetterFill(letter: letter),
                                )
                              : _LetterFill(letter: letter),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (profile.username ?? 'OPERATIVE').toUpperCase(),
                              style: TextStyle(
                                color: textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _PreviewChip(
                                  label: 'LEVEL $level',
                                  borderColor: c.accent.withValues(alpha: 0.5),
                                  textColor: c.accent,
                                ),
                                const SizedBox(width: 6),
                                _PreviewChip(
                                  label: '${profile.designPoints} DP',
                                  borderColor: c.dp.withValues(alpha: 0.45),
                                  textColor: c.dp,
                                  icon: Icons.palette_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${profile.totalXp} XP TOTAL',
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '$xpToNext XP TO LVL ${level + 1}',
                        style: TextStyle(color: textSub, fontSize: 9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(height: 4, color: c.border),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [c.accent, c.accentSecondary],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ПРЕДПРОСМОТР',
                      style: TextStyle(
                        color: c.accent.withValues(alpha: 0.5),
                        fontSize: 8,
                        letterSpacing: 1.5,
                      ),
                    ),
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

class _PreviewChip extends StatelessWidget {
  final String label;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;
  const _PreviewChip({
    required this.label,
    required this.borderColor,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 8, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    const step = 24.0;
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

class _LetterFill extends ConsumerWidget {
  final String letter;
  const _LetterFill({required this.letter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return ColoredBox(
      color: c.surface,
      child: Center(
        child: Text(letter,
            style: TextStyle(
                color: c.accent, fontSize: 22, fontWeight: FontWeight.w200)),
      ),
    );
  }
}

// ── Asset Grid ────────────────────────────────────────────────

class _AssetGrid extends ConsumerWidget {
  final List<CosmeticAsset> assets;
  final InventoryState inventory;
  final String? selectedId;
  final String? equippedId;
  final ValueChanged<String?> onSelect;

  const _AssetGrid({
    required this.assets,
    required this.inventory,
    required this.selectedId,
    required this.equippedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    if (assets.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
            color: c.accent, strokeWidth: 1.5),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: assets.length,
      itemBuilder: (_, i) {
        final asset      = assets[i];
        final isSelected = selectedId == asset.id;
        final isActive   = equippedId == asset.id;
        final isOwned    = inventory.owns(asset) || asset.priceDP == 0;
        return RepaintBoundary(
          child: _AssetCard(
            asset: asset,
            isSelected: isSelected,
            isActive: isActive,
            isOwned: isOwned,
            onTap: () => onSelect(isSelected ? null : asset.id),
          ),
        );
      },
    );
  }
}

// ── Asset Card ────────────────────────────────────────────────

class _AssetCard extends ConsumerStatefulWidget {
  final CosmeticAsset asset;
  final bool isSelected;
  final bool isActive;
  final bool isOwned;
  final VoidCallback? onTap;

  const _AssetCard({
    required this.asset,
    required this.isSelected,
    required this.isActive,
    required this.isOwned,
    required this.onTap,
  });

  @override
  ConsumerState<_AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends ConsumerState<_AssetCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Cryo-freeze for locked/unowned items
  Widget _buildCryo(Widget child) => ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.25, 0.60, 0.15, 0, 5,
          0.25, 0.60, 0.15, 0, 5,
          0.35, 0.60, 0.15, 0, 10,
          0,    0,    0,    1, 0,
        ]),
        child: Opacity(opacity: 0.22, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final borderColor = widget.isActive
        ? c.accentSecondary
        : widget.isSelected
            ? c.accent
            : Colors.transparent;

    final card = GestureDetector(
      onTap: widget.isOwned
          ? widget.onTap
          : () {
              final msg = widget.asset.priceDP > 0
                  ? 'Требуется ${widget.asset.priceDP} DP для разблокировки'
                  : 'Этот элемент недоступен';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(msg),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ));
            },
      onTapDown: widget.isOwned && widget.onTap != null
          ? (_) => _ctrl.animateTo(1.0,
              duration: const Duration(milliseconds: 80), curve: Curves.easeIn)
          : null,
      onTapUp: (_) => _ctrl.animateTo(0.0,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
      onTapCancel: () => _ctrl.animateTo(0.0,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - (widget.onTap != null ? 0.03 * _ctrl.value : 0),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                decoration: c.flatCard(radius: 14),
                child: child!,
              ),
              // Neon border overlay
              if (widget.isSelected || widget.isActive)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: borderColor,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: borderColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Badges
              if (widget.isActive)
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.accentSecondary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'АКТИВНО',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              if (widget.isSelected && !widget.isActive)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [c.accent, c.accentSecondary]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 10),
                  ),
                ),
              // Rarity dot
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.asset.rarityColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            widget.asset.rarityColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      )
                    ],
                  ),
                ),
              ),
              // Lock badge for unowned items
              if (!widget.isOwned)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Tooltip(
                    message: widget.asset.priceDP > 0
                        ? '${widget.asset.priceDP} DP'
                        : 'Заблокировано',
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: c.warning.withValues(alpha: 0.5)),
                      ),
                      child: Icon(Icons.lock_outline,
                          size: 10, color: c.warning),
                    ),
                  ),
                ),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AssetVisual(asset: widget.asset),
            const SizedBox(height: 8),
            Text(
              widget.asset.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isSelected ? c.accent : c.textPrimary,
                fontSize: 10,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    return widget.isOwned ? card : _buildCryo(card);
  }
}

// ── Asset Visual Previews ─────────────────────────────────────

class _AssetVisual extends StatelessWidget {
  final CosmeticAsset asset;
  const _AssetVisual({required this.asset});

  @override
  Widget build(BuildContext context) {
    if (asset.imageUrl != null) {
      return SizedBox(
        width: 56,
        height: 56,
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
        AssetType.avatarFrame       => _FramePreview(asset: asset),
        AssetType.profileBackground => _BackgroundPreview(asset: asset),
        AssetType.statStyle         => _StatStylePreview(asset: asset),
        AssetType.profilePattern    => _BackgroundPreview(asset: asset),
      };
}

class _FramePreview extends StatelessWidget {
  final CosmeticAsset asset;
  const _FramePreview({required this.asset});

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: asset.buildFrameDecoration(),
        child: Icon(Icons.person_outline,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 26),
      );
}

class _BackgroundPreview extends StatelessWidget {
  final CosmeticAsset asset;
  const _BackgroundPreview({required this.asset});

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;
    if (asset.backgroundColor != null) {
      decoration = BoxDecoration(color: asset.backgroundColor);
    } else {
      decoration = BoxDecoration(
        gradient: asset.backgroundGradient ??
            const LinearGradient(
              colors: [Color(0xFF0D2A42), Color(0xFF071520)],
            ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 56,
        height: 40,
        decoration: decoration,
        child: asset.useNeuralPattern
            ? NeuralNetworkWidget(
                color: asset.accentColor.withValues(alpha: 0.35),
              )
            : CustomPaint(painter: _GridPainter(color: asset.accentColor)),
      ),
    );
  }
}

class _StatStylePreview extends StatelessWidget {
  final CosmeticAsset asset;
  const _StatStylePreview({required this.asset});

  @override
  Widget build(BuildContext context) {
    final glow = asset.styleGlowColor;
    return Container(
      width: 56,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: asset.buildStatCardDecoration().copyWith(
            borderRadius: BorderRadius.circular(4),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 2,
            width: 24,
            decoration: BoxDecoration(
              color: asset.accentColor,
              borderRadius: BorderRadius.circular(1),
              boxShadow: glow != null
                  ? [BoxShadow(color: glow, blurRadius: 4)]
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 16,
            color: asset.accentColor.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
