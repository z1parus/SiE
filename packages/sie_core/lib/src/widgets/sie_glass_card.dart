import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/sie_theme.dart';

BorderRadius _deflateRadius(BorderRadius r, double by) => BorderRadius.only(
      topLeft: Radius.circular(math.max(0, r.topLeft.x - by)),
      topRight: Radius.circular(math.max(0, r.topRight.x - by)),
      bottomLeft: Radius.circular(math.max(0, r.bottomLeft.x - by)),
      bottomRight: Radius.circular(math.max(0, r.bottomRight.x - by)),
    );

/// A premium liquid-glass card: gradient specular border + blurred gradient fill.
///
/// Reads the border radius from [SieSpaceEffects] in the current theme.
/// Degrades gracefully to a plain transparent container when the extension
/// is absent (e.g., during tests or under the legacy [SieTheme.dark] theme).
class SieGlassCard extends StatelessWidget {
  const SieGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.blurSigma = 25.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blurSigma;

  /// When non-null, wraps the card in an [InkWell] whose ripple conforms
  /// to the card's inner border radius.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spaceEffects = Theme.of(context).extension<SieSpaceEffects>();
    final decoration = spaceEffects?.glassDecoration ??
        BoxDecoration(borderRadius: BorderRadius.circular(24));
    final outerRadius =
        (decoration.borderRadius as BorderRadius?) ?? BorderRadius.circular(24);
    final innerRadius = _deflateRadius(outerRadius, 1);

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: innerRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x2EFFFFFF), // 18 % white at top-left
            Color(0x07050514), // 3 % dark indigo at bottom-right
          ],
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: innerRadius,
          child: content,
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x59FFFFFF), // 35 % white specular at top-left
              Color(0x0AFFFFFF), // 4 % white at bottom-right
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: ClipRRect(
            borderRadius: innerRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
