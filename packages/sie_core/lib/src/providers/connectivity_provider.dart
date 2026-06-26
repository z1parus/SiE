import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import 'app_mode_provider.dart';

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final service = ConnectivityService();
  // Emit current state upfront so OfflineBanner shows without delay.
  yield await service.checkNow();
  // Then stream every subsequent connectivity change.
  yield* service.isOnlineStream;
});

// Resolves the best-known online state, defaulting to online only as a last
// resort. The connectivity stream is async and hasn't emitted on the very
// first frame after launch, so during that window we fall back to
// [appModeProvider] — which performs a timeout-bounded probe before any shell
// renders and is therefore already resolved here. Without this, offline-launch
// consumers (profile, branches) would briefly see `true`, take the slow network
// path, and only recover after a manual pull-to-refresh.
bool _resolveOnline(bool? live, AppMode? mode) {
  if (live != null) return live;
  if (mode != null) return mode == AppMode.online;
  return true;
}

// Convenience: synchronous read that defaults to online if not yet resolved.
// Use this in providers/notifiers that need a quick offline check.
bool isOnlineSync(Ref ref) => _resolveOnline(
      ref.read(connectivityProvider).valueOrNull,
      ref.read(appModeProvider).valueOrNull,
    );

// Same for WidgetRef (used in ConsumerWidget / ConsumerStatefulWidget).
bool isOnlineSyncWidget(WidgetRef ref) => _resolveOnline(
      ref.read(connectivityProvider).valueOrNull,
      ref.read(appModeProvider).valueOrNull,
    );
