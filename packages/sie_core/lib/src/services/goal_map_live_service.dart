import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoalMapLiveService — Stage 8 (live collaborative canvas).
//
// Thin wrapper over a Supabase Realtime *broadcast* channel `goal_map:{goalId}`.
// Carries ephemeral live-collab events (cursors, node drags, editing flags)
// between participants viewing the same goal map. Nothing is persisted — the
// DB stays the source of truth; broadcast only smooths the UX between saves.
// Degrades silently offline (no channel ⇒ no live layer, plan data untouched).
// ─────────────────────────────────────────────────────────────────────────────

class LiveCursor {
  const LiveCursor({required this.userId, required this.x, required this.y});
  final String userId;
  final double x;
  final double y;
}

class LiveNodeMove {
  const LiveNodeMove(
      {required this.userId,
      required this.nodeId,
      required this.x,
      required this.y});
  final String userId;
  final String nodeId; // 'node:uuid' | 'el:uuid'
  final double x;
  final double y;
}

class LiveEditing {
  const LiveEditing(
      {required this.userId, required this.nodeId, required this.active});
  final String userId;
  final String nodeId;
  final bool active;
}

class GoalMapLiveService {
  GoalMapLiveService({required this.goalId, required this.userId});

  final String goalId;
  final String userId;

  RealtimeChannel? _channel;
  bool _ready = false;

  // Callbacks set by the consumer (the map widget).
  void Function(LiveCursor)? onCursor;
  void Function(LiveNodeMove)? onNodeMove;
  void Function(LiveEditing)? onEditing;

  // Outbound throttle clocks.
  DateTime _lastCursor = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastMove = DateTime.fromMillisecondsSinceEpoch(0);

  static const _cursorThrottle = Duration(milliseconds: 30);
  static const _moveThrottle = Duration(milliseconds: 50);

  void connect() {
    if (_channel != null) return;
    final ch = SupabaseService.client.channel(
      'goal_map:$goalId',
      opts: const RealtimeChannelConfig(self: false),
    );

    ch.onBroadcast(
      event: 'cursor',
      callback: (payload) {
        final uid = payload['userId'] as String?;
        if (uid == null || uid == userId) return;
        final x = (payload['x'] as num?)?.toDouble();
        final y = (payload['y'] as num?)?.toDouble();
        if (x == null || y == null) return;
        onCursor?.call(LiveCursor(userId: uid, x: x, y: y));
      },
    );
    ch.onBroadcast(
      event: 'node_move',
      callback: (payload) {
        final uid = payload['userId'] as String?;
        final nodeId = payload['nodeId'] as String?;
        if (uid == null || uid == userId || nodeId == null) return;
        final x = (payload['x'] as num?)?.toDouble();
        final y = (payload['y'] as num?)?.toDouble();
        if (x == null || y == null) return;
        onNodeMove?.call(LiveNodeMove(userId: uid, nodeId: nodeId, x: x, y: y));
      },
    );
    ch.onBroadcast(
      event: 'editing',
      callback: (payload) {
        final uid = payload['userId'] as String?;
        final nodeId = payload['nodeId'] as String?;
        if (uid == null || uid == userId || nodeId == null) return;
        onEditing?.call(LiveEditing(
            userId: uid,
            nodeId: nodeId,
            active: payload['active'] as bool? ?? false));
      },
    );

    ch.subscribe((status, _) {
      _ready = status == RealtimeSubscribeStatus.subscribed;
    });
    _channel = ch;
  }

  void sendCursor(double x, double y) {
    if (!_ready) return;
    final now = DateTime.now();
    if (now.difference(_lastCursor) < _cursorThrottle) return;
    _lastCursor = now;
    _channel?.sendBroadcastMessage(
        event: 'cursor', payload: {'userId': userId, 'x': x, 'y': y});
  }

  void sendNodeMove(String nodeId, double x, double y) {
    if (!_ready) return;
    final now = DateTime.now();
    if (now.difference(_lastMove) < _moveThrottle) return;
    _lastMove = now;
    _channel?.sendBroadcastMessage(event: 'node_move', payload: {
      'userId': userId,
      'nodeId': nodeId,
      'x': x,
      'y': y,
    });
  }

  void sendEditing(String nodeId, bool active) {
    if (!_ready) return;
    _channel?.sendBroadcastMessage(event: 'editing', payload: {
      'userId': userId,
      'nodeId': nodeId,
      'active': active,
    });
  }

  void dispose() {
    final ch = _channel;
    _channel = null;
    _ready = false;
    if (ch != null) {
      SupabaseService.client.removeChannel(ch);
    }
  }
}
