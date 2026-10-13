import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:cordato/features/core/infrastructure/clients/firebase/messaging_client.dart';

import '../../../../../support/core/mocks/firebase_messaging_mock.dart';

void main() {
  late MessagingClient client;
  late FirebaseMessagingMock messaging;
  late StreamController<RemoteMessage> messages;

  setUp(() {
    messaging = FirebaseMessagingMock();
    messages = StreamController<RemoteMessage>.broadcast();
    client = MessagingClient(
      messaging: messaging,
      foregroundMessages: messages.stream,
    );
    debugDefaultTargetPlatformOverride = .android;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await messages.close();
  });

  test('construction does not request permission or a registration token', () {
    verifyZeroInteractions(messaging);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('identifies ${platform.name} without accessing the SDK', () {
      debugDefaultTargetPlatformOverride = platform;

      expect(
        client.platform,
        platform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      verifyZeroInteractions(messaging);
    });
  }

  test('does not identify an unsupported platform as Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    expect(() => client.platform, throwsUnsupportedError);
  });

  test('returns the Android FCM token without an APNs request', () async {
    when(() => messaging.getToken()).thenAnswer((_) async => 'fcm-token');

    expect(await client.getToken(), 'fcm-token');

    verify(() => messaging.getToken()).called(1);
    verifyNever(() => messaging.getAPNSToken());
  });

  test('preserves an absent registration token', () async {
    when(() => messaging.getToken()).thenAnswer((_) async => null);

    expect(await client.getToken(), isNull);
  });

  test('does not request the iOS FCM token before APNs is ready', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    when(() => messaging.getAPNSToken()).thenAnswer((_) async => null);

    expect(await client.getToken(), isNull);

    verifyNever(() => messaging.getToken());
  });

  test('returns the iOS FCM token once APNs is ready', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    when(() => messaging.getToken()).thenAnswer((_) async => 'fcm-token');
    when(() => messaging.getAPNSToken()).thenAnswer((_) async => 'apns-token');

    expect(await client.getToken(), 'fcm-token');

    verifyInOrder([() => messaging.getAPNSToken(), () => messaging.getToken()]);
  });

  for (final status in AuthorizationStatus.values) {
    test(
      'maps notification authorization ${status.name} to permission',
      () async {
        final settings = NotificationSettings(
          alert: .enabled,
          announcement: .disabled,
          authorizationStatus: status,
          badge: .enabled,
          carPlay: .disabled,
          lockScreen: .enabled,
          notificationCenter: .enabled,
          showPreviews: .always,
          timeSensitive: .disabled,
          criticalAlert: .disabled,
          sound: .enabled,
          providesAppNotificationSettings: .disabled,
        );
        when(() => messaging.requestPermission())
            .thenAnswer((_) async => settings);

        expect(
          await client.requestPermission(),
          status == .authorized || status == .provisional,
        );

        verify(() => messaging.requestPermission()).called(1);
      },
    );
  }

  test(
    'distinguishes SDK failures from missing tokens and denied permissions',
    () async {
      final failure = StateError('Messaging unavailable');
      when(() => messaging.getToken()).thenAnswer((_) async => throw failure);
      when(() => messaging.requestPermission())
          .thenAnswer((_) async => throw failure);

      await expectLater(client.getToken(), throwsA(same(failure)));
      await expectLater(client.requestPermission(), throwsA(same(failure)));
    },
  );

  test('preserves the SDK token-refresh stream', () async {
    final tokens = StreamController<String>.broadcast();
    addTearDown(tokens.close);
    when(() => messaging.onTokenRefresh).thenAnswer((_) => tokens.stream);
    final received = <String>[];
    final subscription = client.onTokenRefresh.listen(received.add);
    addTearDown(subscription.cancel);

    tokens.add('first-token');
    tokens.add('replacement-token');
    await Future<void>.delayed(Duration.zero);

    expect(received, ['first-token', 'replacement-token']);
    await subscription.cancel();
    expect(tokens.hasListener, isFalse);
  });

  test('preserves notifications and data-only foreground messages', () async {
    final received = <Map<String, dynamic>>[];
    final subscription = client.onForegroundMessage.listen(received.add);
    addTearDown(subscription.cancel);
    const notification = RemoteMessage(
      messageId: 'notification-id',
      notification: RemoteNotification(
        title: 'Cordato',
        body: 'Atualização disponível',
      ),
      data: {'type': 'insight', 'id': 'insight-id'},
    );
    const dataOnly = RemoteMessage(
      messageId: 'data-id',
      data: {'type': 'refresh'},
    );

    messages.add(notification);
    messages.add(dataOnly);
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(2));
    expect(received.first['messageId'], 'notification-id');
    expect(received.first['data'], {'type': 'insight', 'id': 'insight-id'});
    expect(received.first['notification'], containsPair('title', 'Cordato'));
    expect(
      received.first['notification'],
      containsPair('body', 'Atualização disponível'),
    );
    expect(received.last['messageId'], 'data-id');
    expect(received.last['data'], {'type': 'refresh'});
    expect(received.last['notification'], isNull);
    await subscription.cancel();
    expect(messages.hasListener, isFalse);
  });
}
