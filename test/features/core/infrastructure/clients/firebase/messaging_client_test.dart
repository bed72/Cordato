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

  test('construction does not request permission or register', () {
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

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('delegates registration on ${platform.name} to the SDK', () async {
      debugDefaultTargetPlatformOverride = platform;
      when(() => messaging.register()).thenAnswer((_) async {});

      await client.register();

      verify(() => messaging.register()).called(1);
      verifyNoMoreInteractions(messaging);
    });
  }

  test('waits for SDK registration to complete', () async {
    final pending = Completer<void>();
    when(() => messaging.register()).thenAnswer((_) => pending.future);
    var completed = false;
    final registration = client.register().then((_) => completed = true);

    expect(completed, isFalse);
    pending.complete();
    await registration;

    expect(completed, isTrue);
    verify(() => messaging.register()).called(1);
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

  test('propagates SDK registration and permission failures', () async {
    final failure = StateError('Messaging unavailable');
    when(() => messaging.register()).thenAnswer((_) async => throw failure);
    when(() => messaging.requestPermission())
        .thenAnswer((_) async => throw failure);

    await expectLater(client.register(), throwsA(same(failure)));
    await expectLater(client.requestPermission(), throwsA(same(failure)));
  });

  test('preserves the SDK registration stream', () async {
    final registrations = StreamController<String>.broadcast();
    addTearDown(registrations.close);
    final stream = registrations.stream;
    when(() => messaging.onRegistered).thenAnswer((_) => stream);
    expect(client.onRegistered, same(stream));
    final received = <String>[];
    final subscription = client.onRegistered.listen(received.add);
    addTearDown(subscription.cancel);

    final delivered = subscription.asFuture<void>();
    registrations.add('first-fid');
    registrations.add('replacement-fid');
    await registrations.close();
    await delivered;

    expect(received, ['first-fid', 'replacement-fid']);
    await subscription.cancel();
    expect(registrations.hasListener, isFalse);
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
