import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

abstract interface class IMessagingClient {
  String get platform;

  Future<void> register();

  Future<bool> requestPermission();

  Stream<String> get onRegistered;

  Stream<Map<String, dynamic>> get onForegroundMessage;
}

final class MessagingClient({
  required final FirebaseMessaging messaging,
  required final Stream<RemoteMessage> foregroundMessages,
}) implements IMessagingClient {
  @override
  String get platform => switch (defaultTargetPlatform) {
    .iOS => 'ios',
    .android => 'android',
    _ => throw UnsupportedError('Messaging suporta somente Android e iOS.'),
  };

  @override
  Future<void> register() => messaging.register();

  @override
  Future<bool> requestPermission() async {
    final settings = await messaging.requestPermission();
    return settings.authorizationStatus == .authorized ||
        settings.authorizationStatus == .provisional;
  }

  @override
  Stream<String> get onRegistered => messaging.onRegistered;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      foregroundMessages.map((message) => message.toMap());
}
