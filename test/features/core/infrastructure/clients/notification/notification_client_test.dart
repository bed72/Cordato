import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:cordato/features/core/infrastructure/clients/notification/notification_client.dart';

import '../../../../../support/core/mocks/flutter_local_notifications_plugin_mock.dart';
import '../../../../../support/core/mocks/android_flutter_local_notifications_plugin_mock.dart';

void main() {
  late NotificationClient client;
  late FlutterLocalNotificationsPluginMock plugin;
  late AndroidFlutterLocalNotificationsPluginMock android;

  setUpAll(() {
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(
      const AndroidNotificationChannel('fallback', 'Fallback'),
    );
  });

  setUp(() {
    plugin = FlutterLocalNotificationsPluginMock();
    client = NotificationClient(plugin: plugin);
    android = AndroidFlutterLocalNotificationsPluginMock();
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(android);
    when(() => android.createNotificationChannel(any()))
        .thenAnswer((_) async {});
    when(() => plugin.initialize(settings: any(named: 'settings')))
        .thenAnswer((_) async => true);
    when(
      () => plugin.show(
        id: any(named: 'id'),
        body: any(named: 'body'),
        title: any(named: 'title'),
        notificationDetails: any(named: 'notificationDetails'),
      ),
    ).thenAnswer((_) async {});
  });

  test('construction does not initialize or request permissions', () {
    verifyZeroInteractions(plugin);
    verifyZeroInteractions(android);
  });

  test('creates the Cordato high-importance channel and configures without permission prompts', () async {
    await client.initialize();

    final channel =
        verify(() => android.createNotificationChannel(captureAny()))
                .captured
                .single
            as AndroidNotificationChannel;

    final settings =
        verify(() => plugin.initialize(settings: captureAny(named: 'settings')))
                .captured
                .single
            as InitializationSettings;

    expect(channel.name, 'Notificações');
    expect(channel.id, 'cordato_default');
    expect(channel.importance, Importance.high);
    expect(settings.iOS!.requestAlertPermission, isFalse);
    expect(settings.iOS!.requestBadgePermission, isFalse);
    expect(settings.iOS!.requestSoundPermission, isFalse);
    expect(channel.description, 'Notificações do Cordato');
    expect(settings.android!.defaultIcon, 'ic_notification');
    expect(settings.iOS!.requestCriticalPermission, isFalse);
    expect(settings.iOS!.requestProvisionalPermission, isFalse);
  });

  test('initializes iOS when no Android implementation is available', () async {
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);

    await client.initialize();

    verify(() => plugin.initialize(settings: any(named: 'settings'))).called(1);
    verifyZeroInteractions(android);
  });

  test('awaits channel creation and plugin initialization', () async {
    final channelCompletion = Completer<void>();
    final initializationCompletion = Completer<bool?>();
    when(() => android.createNotificationChannel(any()))
        .thenAnswer((_) => channelCompletion.future);
    when(() => plugin.initialize(settings: any(named: 'settings')))
        .thenAnswer((_) => initializationCompletion.future);
    bool completed = false;

    final initialization = client.initialize().then((_) => completed = true);
    await Future<void>.delayed(.zero);
    verifyNever(() => plugin.initialize(settings: any(named: 'settings')));
    expect(completed, isFalse);

    channelCompletion.complete();
    await Future<void>.delayed(.zero);
    verify(() => plugin.initialize(settings: any(named: 'settings'))).called(1);
    expect(completed, isFalse);

    initializationCompletion.complete(true);
    await initialization;
    expect(completed, isTrue);
  });

  test(
    'propagates channel-creation failures without claiming initialization',
    () async {
      final failure = StateError('Channel creation failed');
      when(() => android.createNotificationChannel(any()))
          .thenAnswer((_) async => throw failure);

      await expectLater(client.initialize(), throwsA(same(failure)));

      verifyNever(() => plugin.initialize(settings: any(named: 'settings')));
    },
  );

  test('propagates plugin initialization failures', () async {
    final failure = StateError('Initialization failed');
    when(() => plugin.initialize(settings: any(named: 'settings')))
        .thenAnswer((_) async => throw failure);

    await expectLater(client.initialize(), throwsA(same(failure)));
  });

  test(
    'shows the unchanged content using the same channel and existing icon',
    () async {
      await client.show(
        id: 72,
        title: ' Cordato ',
        body: 'Sua notificação local.',
      );

      final details =
          verify(
                () => plugin.show(
                  id: 72,
                  title: ' Cordato ',
                  body: 'Sua notificação local.',
                  notificationDetails: captureAny(named: 'notificationDetails'),
                ),
              ).captured.single
              as NotificationDetails;

      expect(details.android!.priority, Priority.high);
      expect(details.android!.icon, 'ic_notification');
      expect(details.android!.channelName, 'Notificações');
      expect(details.android!.importance, Importance.high);
      expect(details.android!.channelId, 'cordato_default');
      expect(details.iOS, isA<DarwinNotificationDetails>());
      expect(details.android!.channelDescription, 'Notificações do Cordato');
    },
  );

  test('awaits delivery and propagates SDK failures', () async {
    final completion = Completer<void>();
    final failure = StateError('Notification failed');
    when(
      () => plugin.show(
        id: any(named: 'id'),
        body: any(named: 'body'),
        title: any(named: 'title'),
        notificationDetails: any(named: 'notificationDetails'),
      ),
    ).thenAnswer((_) => completion.future);
    var completed = false;

    final delivery = client
        .show(id: 1, title: '', body: '')
        .then((_) => completed = true);
    final expectation = expectLater(delivery, throwsA(same(failure)));
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    completion.completeError(failure);
    await expectation;
  });
}
