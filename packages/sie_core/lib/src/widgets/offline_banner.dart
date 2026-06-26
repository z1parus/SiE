import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../i18n/translations.g.dart';
import '../providers/connectivity_provider.dart';
import '../theme/sie_colors.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While loading, assume online to avoid false-positive flash.
    // Once resolved, the value is sticky until next network event.
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity.when(
      data: (v) => v,
      loading: () => true,
      error: (_, _) => false,
    );
    if (isOnline) return const SizedBox.shrink();

    final c = ref.watch(sieColorsProvider);

    // No SafeArea here — the parent shell wraps the full body in SafeArea so
    // the status-bar inset is consumed once, not twice.
    return Container(
      width: double.infinity,
      color: c.warning,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        t.common.offline.banner,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: c.background,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
