import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

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

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFF6F00),
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: const Text(
          'OFFLINE — changes will sync on reconnect',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
