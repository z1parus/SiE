import 'package:flutter/material.dart';
import '../theme/sie_theme.dart';

class BranchCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: SieTheme.surface,
          border: Border.all(color: SieTheme.borderDefault),
          borderRadius: BorderRadius.circular(4),
        ),
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
                _LevelBadge(level: level),
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
                  decoration: const BoxDecoration(
                    color: SieTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('DEPARTMENT ACTIVE', style: theme.textTheme.labelSmall),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  color: SieTheme.textSecondary,
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

  const _LevelBadge({this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: SieTheme.borderAccent),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        level != null ? 'LVL ${level.toString().padLeft(2, '0')}' : 'LVL --',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
