import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/firebase/crash_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/firebase/messaging_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/factories/dio_factory.dart';
import 'package:cordato/features/core/infrastructure/clients/notification/notification_client.dart';

const _baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://app.cordato.cloud/api/',
);

final coreDependenciesModule = createModule(
  register: (context) => context
    ..addInstance<String>(_baseUrl)
    ..addInstance<FlutterSecureStorage>(const FlutterSecureStorage())
    ..addLazySingleton<ICrashClient>(CrashClient.new)
    ..addLazySingleton<IMessagingClient>(MessagingClient.new)
    ..addLazySingleton<INotificationClient>(NotificationClient.new)
    ..addLazySingleton<FirebaseMessaging>(() => FirebaseMessaging.instance)
    ..addLazySingleton<FirebaseCrashlytics>(() => FirebaseCrashlytics.instance)
    ..addLazySingleton<Stream<RemoteMessage>>(() => FirebaseMessaging.onMessage)
    ..addLazySingleton<FlutterLocalNotificationsPlugin>(
      FlutterLocalNotificationsPlugin.new,
    )
    ..addLazySingleton<Dio>(
      () => DioFactory.create(
        baseUrl: _baseUrl,
        storage: inject<IStorageClient>(),
      ),
    )
    ..addLazySingleton<IHttpClient>(HttpClient.new)
    ..addLazySingleton<IStorageClient>(StorageClient.new)
    ..addLazySingleton<IMoneyFormatter>(MoneyFormatter.new)
    ..addLazySingleton<IDateFormatter>(() => DateFormatter()),
);
