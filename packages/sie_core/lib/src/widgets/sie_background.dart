import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/sie_colors.dart';

class SieBackground extends ConsumerWidget {
  const SieBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.isLightMode
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: ColoredBox(color: c.background, child: child),
    );
  }
}
