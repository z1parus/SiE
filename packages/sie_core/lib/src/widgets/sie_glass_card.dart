import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/sie_theme.dart';

/// Premium liquid-glass card backed by the [liquid_glass_widgets] shader engine.
///
/// Supports interactive press feedback when [onTap] is non-null:
///   • Scale squeezes to 0.97 on tap-down (physical spring resistance).
///   • [lightIntensity] and [glowIntensity] spike momentarily — the specular
///     rim brightens like a real glass surface catching a flash of light.
///   • Returns to 1.0 with a gentle ease-out spring on release.
class SieGlassCard extends StatefulWidget {
  const SieGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.blurSigma = 30.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blurSigma;

  /// When non-null, enables the press-scale animation and tap gesture.
  final VoidCallback? onTap;

  @override
  State<SieGlassCard> createState() => _SieGlassCardState();
}

class _SieGlassCardState extends State<SieGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    // Duration is overridden per-direction in _onTapDown / _onRelease.
    _pressCtrl = AnimationController(vsync: this, value: 0.0);
    _pressAnim = CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _pressCtrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeIn,
    );
  }

  void _onRelease() {
    _pressCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spaceEffects = Theme.of(context).extension<SieSpaceEffects>();
    final br = (spaceEffects?.glassDecoration.borderRadius as BorderRadius?)
            ?.topLeft.x ??
        24.0;
    final blur = (widget.blurSigma / 6).clamp(2.0, 8.0);

    // Non-interactive cards (onTap == null) skip both GestureDetector and
    // AnimatedBuilder — they render as a static GlassCard with zero overhead.
    if (widget.onTap == null) {
      return GlassCard(
        width: widget.width,
        height: widget.height,
        padding: widget.padding ?? const EdgeInsets.all(16),
        margin: widget.margin,
        shape: LiquidRoundedSuperellipse(borderRadius: br),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        settings: LiquidGlassSettings(
          blur: blur,
          thickness: 28,
          refractiveIndex: 1.45,
          glassColor: const Color(0x0A0A0E1A),
          lightAngle: GlassDefaults.lightAngle,
          lightIntensity: 0.72,
          glowIntensity: 0.85,
          saturation: 1.4,
          specularSharpness: GlassSpecularSharpness.sharp,
          ambientStrength: 0.08,
          chromaticAberration: 0.015,
        ),
        child: widget.child,
      );
    }

    // Interactive card — AnimatedBuilder drives scale + specular flash.
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: (_) => _onRelease(),
      onTapCancel: _onRelease,
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (_, child) {
          final t = _pressAnim.value; // 0.0 = idle, 1.0 = fully pressed
          return Transform.scale(
            scale: 1.0 - 0.03 * t, // 1.00 → 0.97
            child: GlassCard(
              width: widget.width,
              height: widget.height,
              padding: widget.padding ?? const EdgeInsets.all(16),
              margin: widget.margin,
              shape: LiquidRoundedSuperellipse(borderRadius: br),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: LiquidGlassSettings(
                blur: blur,
                thickness: 28,
                refractiveIndex: 1.45,
                glassColor: const Color(0x0A0A0E1A),
                lightAngle: GlassDefaults.lightAngle,
                lightIntensity: 0.72 + 0.22 * t, // specular flash on press
                glowIntensity: 0.85 + 0.20 * t,  // edge glow boost on press
                saturation: 1.4,
                specularSharpness: GlassSpecularSharpness.sharp,
                ambientStrength: 0.08,
                chromaticAberration: 0.015,
              ),
              child: child!,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
