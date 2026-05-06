import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

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
    _tabs = TabController(length: 3, vsync: this);
    _frameId = widget.profile.equippedFrameId;
    _backgroundId = widget.profile.equippedBackgroundId;
    _styleId = widget.profile.equippedStatStyleId;
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
          SnackBar(content: Text('ERROR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames = ref.watch(avatarFramesProvider).valueOrNull ?? [];
    final backgrounds = ref.watch(profileBackgroundsProvider).valueOrNull ?? [];
    final styles = ref.watch(statStylesProvider).valueOrNull ?? [];

    final equipped = EquippedAssets.resolve(
      frames: frames,
      backgrounds: backgrounds,
      styles: styles,
      frameId: _frameId,
      backgroundId: _backgroundId,
      styleId: _styleId,
    );

    return Scaffold(
      backgroundColor: SieTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onSave: _saving ? null : _save),
            // Live preview
            _Preview(
              profile: widget.profile,
              equipped: equipped,
            ),
            // Tab bar
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
            // Grid content
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _AssetGrid(
                    assets: frames,
                    selectedId: _frameId,
                    equippedId: widget.profile.equippedFrameId,
                    onSelect: (id) => setState(() => _frameId = id),
                  ),
                  _AssetGrid(
                    assets: backgrounds,
                    selectedId: _backgroundId,
                    equippedId: widget.profile.equippedBackgroundId,
                    onSelect: (id) => setState(() => _backgroundId = id),
                  ),
                  _AssetGrid(
                    assets: styles,
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
            child: Text('НАСТРОЙКА ОБЛИКА',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
          ),
          TextButton(
            onPressed: onSave,
            child: Text(
              'ПРИМЕНИТЬ',
              style: TextStyle(
                color: onSave != null
                    ? SieTheme.accent
                    : SieTheme.textSecondary,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    final bg = equipped.background;
    final frame = equipped.frame;
    final style = equipped.statStyle;
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
          // Subtle grid lines
          CustomPaint(painter: _GridPainter(), size: Size.infinite),
          // Gradient fade at bottom
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
          // Avatar + stats preview centered
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with frame
                Container(
                  width: 60,
                  height: 60,
                  decoration: frame?.buildFrameDecoration() ??
                      BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: SieTheme.borderAccent, width: 1.5),
                        color: SieTheme.surface,
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
                // Name + stat mini-card
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (profile.username ?? 'OPERATIVE').toUpperCase(),
                      style: const TextStyle(
                        color: SieTheme.textPrimary,
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
                            border: Border.all(color: SieTheme.borderDefault),
                            borderRadius: BorderRadius.circular(4),
                          ),
                      child: Text(
                        'LVL ${(profile.totalXp ~/ 1000) + 1}  ·  ${profile.totalXp} XP',
                        style: TextStyle(
                          color: style?.accentColor ?? SieTheme.accent,
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
          // "PREVIEW" label
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
                  color: SieTheme.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w200)),
        ),
      );
}

// ── Asset Grid ────────────────────────────────────────────────

class _AssetGrid extends StatelessWidget {
  final List<CosmeticAsset> assets;
  final String? selectedId;
  final String? equippedId;
  final ValueChanged<String?> onSelect;

  const _AssetGrid({
    required this.assets,
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
        final asset = assets[i];
        final isSelected = selectedId == asset.id;
        final isActive = equippedId == asset.id;
        return _AssetCard(
          asset: asset,
          isSelected: isSelected,
          isActive: isActive,
          onTap: () => onSelect(isSelected ? null : asset.id),
        );
      },
    );
  }
}

// ── Asset Card ────────────────────────────────────────────────

class _AssetCard extends StatelessWidget {
  final CosmeticAsset asset;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  const _AssetCard({
    required this.asset,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? SieTheme.accent.withValues(alpha: 0.08)
              : SieTheme.surface,
          border: Border.all(
            color: isSelected ? SieTheme.accent : SieTheme.borderDefault,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            // Asset visual preview
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AssetVisual(asset: asset),
                  const SizedBox(height: 8),
                  Text(
                    asset.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? SieTheme.accent
                          : SieTheme.textPrimary,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Rarity dot (bottom-right)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
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
            ),
            // "АКТИВНО" badge (top-left)
            if (isActive)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: SieTheme.accent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text(
                    'АКТИВНО',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            // Checkmark if selected (but not yet saved)
            if (isSelected && !isActive)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: SieTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.black, size: 10),
                ),
              ),
          ],
        ),
      ),
    );
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

  Widget _fallback() {
    return switch (asset.type) {
      AssetType.avatarFrame      => _FramePreview(asset: asset),
      AssetType.profileBackground => _BackgroundPreview(asset: asset),
      AssetType.statStyle        => _StatStylePreview(asset: asset),
    };
  }
}

class _FramePreview extends StatelessWidget {
  final CosmeticAsset asset;
  const _FramePreview({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: asset.buildFrameDecoration(),
      child: const Icon(Icons.person_outline,
          color: SieTheme.textSecondary, size: 26),
    );
  }
}

class _BackgroundPreview extends StatelessWidget {
  final CosmeticAsset asset;
  const _BackgroundPreview({required this.asset});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
