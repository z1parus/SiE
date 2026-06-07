import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/sie_colors.dart';

class SectionHeader extends ConsumerWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Row(
      children: [
        Container(width: 3, height: 16, color: c.accent),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
