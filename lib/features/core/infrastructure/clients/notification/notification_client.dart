import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class INotificationClient {
  Future<void> initialize();

  Future<void> show({
    required int id,
    required String body,
    required String title,
  });
}

final class NotificationClient({
  required final FlutterLocalNotificationsPlugin plugin,
}) implements INotificationClient {
  static const _icon = 'ic_notification';
  static const _channelName = 'Notificações';
  static const _channelId = 'cordato_default';
  static const _channelDescription = 'Notificações do Cordato';

  @override
  Future<void> initialize() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: .high,
        description: _channelDescription,
      ),
    );
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
        iOS: DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        ),
      ),
    );
  }

  @override
  Future<void> show({
    required int id,
    required String body,
    required String title,
  }) => plugin.show(
    id: id,
    body: body,
    title: title,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        icon: _icon,
        priority: .high,
        importance: .high,
        channelDescription: _channelDescription,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}
