import 'public_profile.dart';

class FriendRow {
  final String friendshipId;
  final PublicProfile otherUser;
  final DateTime createdAt;

  const FriendRow({
    required this.friendshipId,
    required this.otherUser,
    required this.createdAt,
  });
}

class FriendsState {
  final List<FriendRow> friends;
  final List<FriendRow> sentRequests;
  final List<FriendRow> receivedRequests;

  const FriendsState({
    this.friends = const [],
    this.sentRequests = const [],
    this.receivedRequests = const [],
  });

  FriendRow? rowFor(String userId) =>
      [...friends, ...sentRequests, ...receivedRequests]
          .where((r) => r.otherUser.id == userId)
          .firstOrNull;
}
