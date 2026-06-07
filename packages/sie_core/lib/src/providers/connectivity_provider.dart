import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final service = ConnectivityService();
  // Emit current state upfront so OfflineBanner shows without delay.
  yield await service.checkNow();
  // Then stream every subsequent connectivity change.
  yield* service.isOnlineStream;
});

// Convenience: synchronous read that defaults to online if not yet resolved.
// Use this in providers/notifiers that need a quick offline check.
bool isOnlineSync(Ref ref) =>
    ref.read(connectivityProvider).valueOrNull ?? true;

// Same for WidgetRef (used in ConsumerWidget / ConsumerStatefulWidget).
bool isOnlineSyncWidget(WidgetRef ref) =>
    ref.read(connectivityProvider).valueOrNull ?? true;
