import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';
import '../models/public_profile.dart';
import '../supabase_service.dart';
import 'auth_state_provider.dart';

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsState>(
        NotificationsNotifier.new);

class NotificationsNotifier extends AsyncNotifier<NotificationsState>
    with WidgetsBindingObserver {
  RealtimeChannel? _channel;

  @override
  Future<NotificationsState> build() async {
    ref.watch(authStateProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _channel?.unsubscribe();
    });
    _subscribeRealtime();
    return _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _channel?.unsubscribe();
      _subscribeRealtime();
    }
  }

  void _subscribeRealtime() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    _channel = SupabaseService.client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId),
          callback: (_) async {
            final fresh = await _load();
            state = AsyncData(fresh);
          },
        )
        .subscribe();
  }

  Future<NotificationsState> _load() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return const NotificationsState(notifications: []);

    final data = await SupabaseService.client
        .from('notifications')
        .select('id, type, from_user_id, is_read, created_at, payload')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    final fromIds = data
        .map((r) => r['from_user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final profileMap = <String, PublicProfile>{};
    if (fromIds.isNotEmpty) {
      final profiles = await SupabaseService.client
          .from('profiles')
          .select('id, username, avatar_url, equipped_frame_id, '
              'equipped_background_id, equipped_stat_style_id, equipped_pattern_id, total_xp, design_points')
          .inFilter('id', fromIds);
      for (final p in profiles) {
        profileMap[p['id'] as String] = PublicProfile.fromJson(p);
      }
    }

    final notifications = data.map((r) {
      final fromId = r['from_user_id'] as String?;
      return AppNotification(
        id: r['id'] as String,
        type: r['type'] as String,
        fromUser: fromId != null ? profileMap[fromId] : null,
        isRead: r['is_read'] as bool,
        createdAt: DateTime.parse(r['created_at'] as String),
        payload: (r['payload'] as Map<String, dynamic>?) ?? {},
      );
    }).toList();

    return NotificationsState(notifications: notifications);
  }

  Future<void> markAsRead(String id) async {
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
    final cur = state.valueOrNull;
    if (cur != null) {
      state = AsyncData(NotificationsState(
          notifications: cur.notifications
              .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
              .toList()));
    }
  }

  Future<void> markAllAsRead() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
    final cur = state.valueOrNull;
    if (cur != null) {
      state = AsyncData(NotificationsState(
          notifications:
              cur.notifications.map((n) => n.copyWith(isRead: true)).toList()));
    }
  }

  void resolveInvite(String notificationId, String inviteStatus) {
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = AsyncData(NotificationsState(
        notifications: cur.notifications.map((n) {
      if (n.id != notificationId) return n;
      return n.copyWith(
          payload: {...n.payload, 'invite_status': inviteStatus});
    }).toList()));
  }
}
