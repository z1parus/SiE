import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/sie_colors.dart';

/// Unified error / offline state with a retry affordance (Stage 0).
///
/// Standardises the mix of `Text('Ошибка загрузки')` and bespoke offline
/// messages into one component. Pass [onRetry] to surface a "Повторить" button.
class SieErrorState extends ConsumerWidget {
  const SieErrorState({
    super.key,
    this.title = 'Не удалось загрузить',
    this.subtitle = 'Проверьте подключение к интернету',
    this.icon = Icons.wifi_off_rounded,
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: c.iconMuted),
            const SizedBox(height: 16),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: 'Повторить загрузку',
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.accent),
                    ),
                    child: Text(
                      'ПОВТОРИТЬ',
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
