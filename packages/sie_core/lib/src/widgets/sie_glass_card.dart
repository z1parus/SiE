import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/sie_theme.dart';

/// A premium glassmorphic card with backdrop blur and optional tap feedback.
///
/// Reads visual tokens from [SieSpaceEffects] in the current theme.
/// Degrades gracefully to a plain transparent container when the extension
/// is absent (e.g., during tests or under the legacy [SieTheme.dark] theme).
///
/// Usage:
/// ```dart
/// SieGlassCard(
///   padding: const EdgeInsets.all(20),
///   onTap: () { ... },
///   child: Text('Hello'),
/// )
/// ```
class SieGlassCard extends StatelessWidget {
  const SieGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.blurSigma = 20.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blurSigma;

  /// When non-null, wraps the card in an [InkWell] whose ripple conforms
  /// to the card's border radius.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spaceEffects = Theme.of(context).extension<SieSpaceEffects>();

    // Resolve decoration and border radius from the theme extension.
    // The cast is safe: glassDecoration is always constructed with BorderRadius
    // (not a directional variant), so the runtime type is BorderRadius.
    final decoration = spaceEffects?.glassDecoration ??
        BoxDecoration(borderRadius: BorderRadius.circular(24));
    final borderRadius =
        (decoration.borderRadius as BorderRadius?) ?? BorderRadius.circular(24);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      // Material(transparency) provides the ink-splash layer without
      // overriding the glass decoration's background.
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        // Clipping before BackdropFilter prevents blur from bleeding
        // outside the rounded corners into adjacent layers.
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      ),
    );
  }
}
