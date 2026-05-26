import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7000FF);

LiquidGlassSettings _glassSettings({
  double blur = 3.0,
  double glowIntensity = 0.88,
}) =>
    LiquidGlassSettings(
      blur: blur,
      thickness: 24,
      refractiveIndex: 1.45,
      glassColor: const Color(0x0A0A0E1A),
      lightAngle: GlassDefaults.lightAngle,
      lightIntensity: 0.72,
      glowIntensity: glowIntensity,
      saturation: 1.4,
      specularSharpness: GlassSpecularSharpness.sharp,
      ambientStrength: 0.08,
      chromaticAberration: 0.015,
    );

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs         = TabController(length: 3, vsync: this);
    _frameId      = widget.profile.equippedFrameId;
    _backgroundId = widget.profile.equippedBackgroundId;
    _styleId      = widget.profile.equippedStatStyleId;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await applyCustomization(
        frameId: _frameId,
        backgroundId: _backgroundId,
        styleId: _styleId,
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
    final inventory   = ref.watch(inventoryProvider).valueOrNull ?? InventoryState.empty;

    final equipped = EquippedAssets.resolve(
      frames: frames,
      backgrounds: backgrounds,
      styles: styles,
      frameId: _frameId,
      backgroundId: _backgroundId,
      styleId: _styleId,
    );

    return GlassPage(
      background: const SieSpaceBackground(),
      statusBarStyle: GlassStatusBarStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onSave: _saving ? null : _save),
              // Live preview panel
              _Preview(profile: widget.profile, equipped: equipped),
              // Glass tab bar
              GlassCard(
                height: 44,
                padding: EdgeInsets.zero,
                shape: LiquidRoundedSuperellipse(borderRadius: 0),
                useOwnLayer: true,
                quality: GlassQuality.standard,
                settings: _glassSettings(blur: 2.5, glowIntensity: 0.75),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: _kCyan,
                  indicatorWeight: 1.5,
                  labelColor: _kCyan,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback? onSave;
  const _TopBar({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: SieTheme.textSecondary, size: 18),
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

class _SaveButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _SaveButton({required this.onTap});

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton>
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
                          Color.lerp(const Color(0xFF00E5FF),
                              const Color(0xFF00BFFF), t)!,
                          Color.lerp(const Color(0xFF7000FF),
                              const Color(0xFF9000FF), t)!,
                        ],
                      )
                    : null,
                boxShadow: widget.onTap != null
                    ? [
                        BoxShadow(
                          color: _kCyan.withValues(alpha: 0.18 + 0.25 * t),
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
                      : SieTheme.textSecondary,
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

class _Preview extends StatelessWidget {
  final Profile profile;
  final EquippedAssets equipped;
  const _Preview({required this.profile, required this.equipped});

  @override
  Widget build(BuildContext context) {
    final bg     = equipped.background;
    final frame  = equipped.frame;
    final style  = equipped.statStyle;
    final letter = (profile.username?.isNotEmpty == true)
        ? profile.username![0].toUpperCase()
        : '?';

    return Container(
      height: 140,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: bg?.backgroundGradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D2A42), Color(0xFF071520)],
            ),
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
                  width: 60,
                  height: 60,
                  decoration: frame?.buildFrameDecoration() ??
                      BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _kCyan.withValues(alpha: 0.6), width: 1.5),
                        color: SieTheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: _kCyan.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
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
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (profile.username ?? 'OPERATIVE').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: style?.buildStatCardDecoration() ??
                          BoxDecoration(
                            color: SieTheme.surface,
                            border: Border.all(
                                color: _kCyan.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                      child: Text(
                        'LVL ${(profile.totalXp ~/ 1000) + 1}  ·  ${profile.totalXp} XP',
                        style: TextStyle(
                          color: style?.accentColor ?? _kCyan,
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
            bottom: 6,
            right: 10,
            child: Text(
              'ПРЕДПРОСМОТР',
              style: TextStyle(
                color: SieTheme.borderAccent,
                fontSize: 8,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00C8FF).withValues(alpha: 0.04)
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

class _LetterFill extends StatelessWidget {
  final String letter;
  const _LetterFill({required this.letter});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: SieTheme.surface,
        child: Center(
          child: Text(letter,
              style: const TextStyle(
                  color: _kCyan, fontSize: 22, fontWeight: FontWeight.w200)),
        ),
      );
}

// ── Asset Grid ────────────────────────────────────────────────

class _AssetGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
            color: SieTheme.accent, strokeWidth: 1.5),
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
            onTap: isOwned
                ? () => onSelect(isSelected ? null : asset.id)
                : null,
          ),
        );
      },
    );
  }
}

// ── Asset Card ────────────────────────────────────────────────

class _AssetCard extends StatefulWidget {
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
  State<_AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<_AssetCard>
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
    final glowIntensity = widget.isSelected
        ? 1.1 + 0.15 * _ctrl.value
        : widget.isActive
            ? 1.0
            : 0.82 + 0.22 * _ctrl.value;

    final borderColor = widget.isActive
        ? _kPurple
        : widget.isSelected
            ? _kCyan
            : Colors.transparent;

    final card = GestureDetector(
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
        builder: (_, child) => Transform.scale(
          scale: 1.0 - (widget.onTap != null ? 0.03 * _ctrl.value : 0),
          child: Stack(
            children: [
              GlassCard(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                shape: LiquidRoundedSuperellipse(borderRadius: 14),
                useOwnLayer: true,
                quality: GlassQuality.standard,
                clipBehavior: Clip.antiAlias,
                settings: _glassSettings(glowIntensity: glowIntensity),
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
                      color: _kPurple.withValues(alpha: 0.9),
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
                      gradient: const LinearGradient(
                          colors: [_kCyan, _kPurple]),
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
                color: widget.isSelected ? _kCyan : Colors.white,
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
        child: const Icon(Icons.person_outline,
            color: SieTheme.textSecondary, size: 26),
      );
}

class _BackgroundPreview extends StatelessWidget {
  final CosmeticAsset asset;
  const _BackgroundPreview({required this.asset});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 56,
          height: 40,
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
