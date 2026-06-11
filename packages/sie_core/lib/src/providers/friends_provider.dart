import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friendship.dart';
import '../models/public_profile.dart';
import '../supabase_service.dart';
import 'auth_state_provider.dart';

final friendsProvider =
    AsyncNotifierProvider<FriendsNotifier, FriendsState>(FriendsNotifier.new);

class FriendsNotifier extends AsyncNotifier<FriendsState> {
  @override
  Future<FriendsState> build() async {
    ref.watch(authStateProvider);
    return _load();
  }

  Future<FriendsState> _load() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return const FriendsState();

    final rows = await SupabaseService.client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId')
        .order('created_at', ascending: false);

    final otherIds = rows.map<String>((r) {
      return (r['requester_id'] as String) == userId
          ? r['addressee_id'] as String
          : r['requester_id'] as String;
    }).toSet().toList();

    final profileMap = <String, PublicProfile>{};
    if (otherIds.isNotEmpty) {
      final profiles = await SupabaseService.client
          .from('profiles')
          .select('id, username, avatar_url, equipped_frame_id, '
              'equipped_background_id, equipped_stat_style_id, total_xp, design_points')
          .inFilter('id', otherIds);
      for (final p in profiles) {
        profileMap[p['id'] as String] = PublicProfile.fromJson(p);
      }
    }

    final friends = <FriendRow>[];
    final sent = <FriendRow>[];
    final received = <FriendRow>[];

    for (final r in rows) {
      final requesterId = r['requester_id'] as String;
      final addresseeId = r['addressee_id'] as String;
      final iAmRequester = requesterId == userId;
      final otherId = iAmRequester ? addresseeId : requesterId;
      final otherUser = profileMap[otherId];
      if (otherUser == null) continue;

      final row = FriendRow(
        friendshipId: r['id'] as String,
        otherUser: otherUser,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

      switch (r['status'] as String) {
        case 'accepted':
          friends.add(row);
        case 'pending' when iAmRequester:
          sent.add(row);
        case 'pending':
          received.add(row);
      }
    }

    return FriendsState(
        friends: friends, sentRequests: sent, receivedRequests: received);
  }

  Future<void> sendRequest(String userId) async {
    final mirror = state.valueOrNull?.receivedRequests
        .where((r) => r.otherUser.id == userId)
        .firstOrNull;
    if (mirror != null) {
      await acceptRequest(mirror.friendshipId);
      return;
    }
    final myId = SupabaseService.client.auth.currentUser!.id;
    await SupabaseService.client
        .from('friendships')
        .insert({'requester_id': myId, 'addressee_id': userId});
    state = AsyncData(await _load());
  }

  Future<void> cancelRequest(String friendshipId) async {
    await SupabaseService.client
        .from('friendships')
        .delete()
        .eq('id', friendshipId);
    state = AsyncData(await _load());
  }

  Future<void> acceptRequest(String friendshipId) async {
    await SupabaseService.client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
    state = AsyncData(await _load());
  }

  Future<void> declineRequest(String friendshipId) async {
    await SupabaseService.client
        .from('friendships')
        .delete()
        .eq('id', friendshipId);
    state = AsyncData(await _load());
  }

  Future<void> removeFriend(String friendshipId) async {
    await SupabaseService.client
        .from('friendships')
        .delete()
        .eq('id', friendshipId);
    state = AsyncData(await _load());
  }
}
