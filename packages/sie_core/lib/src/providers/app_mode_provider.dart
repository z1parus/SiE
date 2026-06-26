import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// Which top-level shell the app runs in.
///
/// Decided once at startup from real backend reachability (a fast, timeout-
/// bounded probe — see [ConnectivityService.checkNow]). It is only flipped to
/// [online] by an explicit user reconnect ([AppModeNotifier.tryConnect]); a
/// mid-session connectivity drop deliberately does NOT yank the user out of the
/// full app — that path stays offline-first and keeps working.
enum AppMode { online, offline }

class AppModeNotifier extends AsyncNotifier<AppMode> {
  @override
  Future<AppMode> build() async {
    final reachable = await ConnectivityService().checkNow();
    return reachable ? AppMode.online : AppMode.offline;
  }

  /// Re-probes the backend. On success flips to [AppMode.online] (the app root,
  /// which watches this provider, then swaps in the full shell). Returns whether
  /// the backend is now reachable.
  Future<bool> tryConnect() async {
    final reachable = await ConnectivityService().checkNow();
    if (reachable && state.valueOrNull != AppMode.online) {
      state = const AsyncData(AppMode.online);
    }
    return reachable;
  }
}

final appModeProvider =
    AsyncNotifierProvider<AppModeNotifier, AppMode>(AppModeNotifier.new);
