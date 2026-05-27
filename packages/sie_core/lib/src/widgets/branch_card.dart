import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/sie_colors.dart';

class BranchCard extends ConsumerWidget {
  final String name;
  final String? description;
  final int? level;
  final VoidCallback onTap;

  const BranchCard({
    super.key,
    required this.name,
    this.description,
    this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: c.flatCard(radius: 4),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                _LevelBadge(level: level, c: c),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('DEPARTMENT ACTIVE', style: theme.textTheme.labelSmall),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: c.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int? level;
  final SieColors c;

  const _LevelBadge({this.level, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: c.accent.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        level != null ? 'LVL ${level.toString().padLeft(2, '0')}' : 'LVL --',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
