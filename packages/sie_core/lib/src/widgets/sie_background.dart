import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/sie_colors.dart';
import 'sie_space_background.dart';

class SieBackground extends ConsumerWidget {
  const SieBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    if (c.isCosmicMode) {
      return GlassPage(
        background: const SieSpaceBackground(),
        statusBarStyle: GlassStatusBarStyle.light,
        child: child,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.isLightMode
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: ColoredBox(color: c.background, child: child),
    );
  }
}
