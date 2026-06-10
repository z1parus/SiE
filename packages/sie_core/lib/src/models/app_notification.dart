import 'public_profile.dart';

class AppNotification {
  final String id;
  final String type;
  final PublicProfile? fromUser;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    this.fromUser,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        fromUser: fromUser,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

class NotificationsState {
  final List<AppNotification> notifications;

  const NotificationsState({required this.notifications});

  int get unreadCount => notifications.where((n) => !n.isRead).length;
}
