import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../models/cosmetic_asset.dart';
import '../theme/sie_colors.dart';

/// Renders the background layer of a profile card for any [CosmeticAsset]
/// background [kind]: gradient/solid colour, static image, animated WebP, or
/// Lottie. Used by [ProfileHeroCard] (full render) and the customization
/// preview.
///
/// In grids/lists pass [thumbnail] = true: animated kinds then paint their
/// static [CosmeticAsset.thumbnailUrl] instead of running the animation, so a
/// screen full of cards doesn't spin up dozens of decoders.
class ProfileBackgroundView extends StatelessWidget {
  const ProfileBackgroundView({
    super.key,
    required this.background,
    required this.colors,
    required this.child,
    this.radius = 24,
    this.thumbnail = false,
  });

  /// Equipped background, or null for the themed default.
  final CosmeticAsset? background;

  /// Theme colours, for the fallback decoration.
  final SieColors colors;

  /// Content painted on top of the background.
  final Widget child;

  /// Corner radius of the clipped card.
  final double radius;

  /// When true, animated backgrounds render their static thumbnail.
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    final bg = background;

    // Gradient / solid colour / themed default — no media, no clip needed.
    if (bg == null || !bg.isMediaBackground) {
      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: _gradientDecoration(bg),
        child: child,
      );
    }

    // Media background: paint the media full-bleed, then the child on top.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: _media(bg)),
          child,
        ],
      ),
    );
  }

  BoxDecoration _gradientDecoration(CosmeticAsset? bg) {
    if (bg?.backgroundColor != null) {
      return BoxDecoration(
        color: bg!.backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: bg.accentColor.withValues(alpha: 0.25)),
      );
    }
    if (bg?.backgroundGradient != null) {
      return BoxDecoration(
        gradient: bg!.backgroundGradient,
        borderRadius: BorderRadius.circular(radius),
      );
    }
    return colors.flatCard(radius: radius);
  }

  Widget _media(CosmeticAsset bg) {
    final url = bg.imageUrl!;

    // In thumbnail context, animated kinds show their static preview.
    if (thumbnail && bg.backgroundKind != BackgroundKind.image) {
      final thumb = bg.thumbnailUrl;
      if (thumb != null) {
        return CachedNetworkImage(
          imageUrl: thumb,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _placeholder(),
        );
      }
      return _placeholder();
    }

    switch (bg.backgroundKind) {
      case BackgroundKind.lottie:
        return Lottie.network(
          url,
          fit: BoxFit.cover,
          repeat: true,
          frameRate: FrameRate.max,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      case BackgroundKind.animatedWebp:
        // Animated WebP plays automatically through Image.network.
        return Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      case BackgroundKind.image:
      case BackgroundKind.gradient:
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _placeholder(),
        );
    }
  }

  Widget _placeholder() => DecoratedBox(
        decoration: colors.flatCard(radius: radius),
      );
}
