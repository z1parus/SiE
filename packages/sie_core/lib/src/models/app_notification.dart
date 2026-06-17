import 'public_profile.dart';

class AppNotification {
  final String id;
  final String type;
  final PublicProfile? fromUser;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  const AppNotification({
    required this.id,
    required this.type,
    this.fromUser,
    required this.isRead,
    required this.createdAt,
    this.payload = const {},
  });

  AppNotification copyWith({bool? isRead, Map<String, dynamic>? payload}) =>
      AppNotification(
        id: id,
        type: type,
        fromUser: fromUser,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        payload: payload ?? this.payload,
      );
}

class NotificationsState {
  final List<AppNotification> notifications;

  const NotificationsState({required this.notifications});

  int get unreadCount => notifications.where((n) => !n.isRead).length;
}
