import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/sie_theme.dart';

/// Premium liquid-glass card backed by the [liquid_glass_widgets] shader engine.
///
/// Delegates to [GlassCard] with physics-based settings tuned for the
/// Cyber-Space dark aesthetic: high refraction, sharp specular from the
/// iOS-standard top-left light angle, and subtle chromatic aberration.
///
/// [useOwnLayer: true] + [GlassQuality.standard] is safe inside scrollable
/// lists such as the branch carousel. The root [GlassBackdropScope] installed
/// by [LiquidGlassWidgets.wrap] is shared across all cards on screen.
///
/// The [blurSigma] parameter maps to the shader's frost `blur` value
/// (divided by 6) so existing call-sites that tuned sigma 25–30 translate
/// to a shader blur of ~4–5, which matches the library's calibrated range.
class SieGlassCard extends StatelessWidget {
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

  /// When non-null wraps the card in a [GestureDetector].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Derive corner radius from the theme extension, fall back to 24.
    final spaceEffects = Theme.of(context).extension<SieSpaceEffects>();
    final br = (spaceEffects?.glassDecoration.borderRadius as BorderRadius?)
            ?.topLeft
            .x ??
        24.0;

    final card = GlassCard(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      // LiquidRoundedSuperellipse is Flutter's squircle (iOS-style corner).
      shape: LiquidRoundedSuperellipse(borderRadius: br),
      // useOwnLayer: true — card creates its own rendering context so it
      // works in PageView/ListView without a parent LiquidGlassLayer.
      useOwnLayer: true,
      // GlassQuality.standard uses the lightweight 2D fragment shader.
      // It works reliably in all contexts including scrollable lists.
      // GlassQuality.premium (Impeller-only) would give full volumetric
      // refraction but can jank mid-scroll on mid-range devices.
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      settings: LiquidGlassSettings(
        // Frost blur: sigma 30 → blur 5; sigma 25 → blur ~4.2
        blur: (blurSigma / 6).clamp(2.0, 8.0),
        // Physical thickness drives the strength of the refraction warp.
        thickness: 28,
        // 1.45 visibly bends the star field behind the card.
        refractiveIndex: 1.45,
        // Near-zero dark tint — keeps card almost fully transparent so the
        // background stars remain visible through the glass.
        glassColor: const Color(0x0A0A0E1A),
        // iOS 26 standard: 135° upper-left light source.
        lightAngle: GlassDefaults.lightAngle,
        // Boosted from the default 0.5 for crisper specular highlights.
        lightIntensity: 0.72,
        // Edge glow — mimics the fresnel rim on real glass.
        glowIntensity: 0.85,
        // Saturation boost makes the absorbed star-field colors more vivid.
        saturation: 1.4,
        // Sharp exponent (n=32) → tight mirror-like specular point.
        specularSharpness: GlassSpecularSharpness.sharp,
        // Ambient fill prevents the unlit side going fully black.
        ambientStrength: 0.08,
        // Subtle rainbow fringing at the curved glass edge.
        chromaticAberration: 0.015,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
