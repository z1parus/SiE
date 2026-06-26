import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../supabase_service.dart';

/// Reports whether the app can actually reach its backend — not merely whether
/// a network interface is up.
///
/// `connectivity_plus` only tells us a Wi-Fi/mobile/ethernet interface exists;
/// it happily reports "connected" on a captive portal, a router with a dead
/// upstream, or a network that blocks our backend. So after the interface
/// check we do a real reachability probe against the Supabase host. Because the
/// probe is HTTPS, a captive portal can't transparently MITM it — the TLS
/// handshake (or the request) fails and we correctly fall back to offline.
///
/// "Connected but no internet" can also happen with no interface-change event
/// (the upstream silently dies while Wi-Fi stays associated), so on top of
/// reacting to connectivity changes we re-probe on a periodic heartbeat.
class ConnectivityService {
  final _connectivity = Connectivity();

  /// How often to re-validate real reachability while a session is listening.
  static const _pollInterval = Duration(seconds: 20);

  /// Probe budget — kept short so a dead upstream flips us offline quickly.
  static const _probeTimeout = Duration(seconds: 2);

  /// Emits the real online/offline state: on every connectivity change, on a
  /// periodic heartbeat, and once immediately on subscribe. Consecutive
  /// duplicate values are suppressed so listeners only rebuild on real flips.
  Stream<bool> get isOnlineStream {
    late final StreamController<bool> controller;
    StreamSubscription<List<ConnectivityResult>>? sub;
    Timer? timer;
    AppLifecycleListener? lifecycle;
    bool? last;
    var probing = false;

    Future<void> emit() async {
      // Skip if a probe is still in flight to avoid piling up requests.
      if (probing) return;
      probing = true;
      try {
        final online = await checkNow();
        if (online != last && !controller.isClosed) {
          last = online;
          controller.add(online);
        }
      } finally {
        probing = false;
      }
    }

    controller = StreamController<bool>(
      onListen: () {
        sub = _connectivity.onConnectivityChanged.listen((_) => emit());
        timer = Timer.periodic(_pollInterval, (_) => emit());
        // Re-probe the moment the app comes back to the foreground, so a
        // connection that recovered while backgrounded clears the offline
        // banner instantly instead of waiting for the next heartbeat.
        lifecycle = AppLifecycleListener(onResume: emit);
        emit();
      },
      onCancel: () async {
        await sub?.cancel();
        timer?.cancel();
        lifecycle?.dispose();
      },
    );
    return controller.stream;
  }

  /// One-shot check: interface present AND backend actually reachable.
  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    if (!_hasInterface(results)) return false;
    return _hasRealInternet();
  }

  bool _hasInterface(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Pings the Supabase GoTrue health endpoint (unauthenticated, tiny, CORS
  /// enabled so it works on web too). Any HTTP response means the backend is
  /// reachable → online. A timeout or transport error (captive portal, dead
  /// upstream, blocked host) → offline.
  Future<bool> _hasRealInternet() async {
    final base = SupabaseService.supabaseUrl;
    // Backend not configured yet (e.g. before init) — don't force offline.
    if (base == null || base.isEmpty) return true;
    try {
      final resp = await http
          .get(Uri.parse('$base/auth/v1/health'))
          .timeout(_probeTimeout);
      // Reaching the host at all (any status) proves real connectivity.
      return resp.statusCode > 0;
    } catch (_) {
      return false;
    }
  }
}
