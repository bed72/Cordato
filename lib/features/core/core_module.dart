import 'dart:io' hide HttpClient;

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/application/clients/interface_share_client.dart';
import 'package:cordato/features/core/application/clients/interface_recording_client.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/infrastructure/clients/recording/recording_client.dart';
import 'package:cordato/features/core/infrastructure/clients/home_widget/home_widget_client.dart';

const projectId = String.fromEnvironment(
  'APPWRITE_PROJECT_ID',
  defaultValue: '6ae23b900027854cc526',
);
const endpoint = String.fromEnvironment(
  'APPWRITE_ENDPOINT',
  defaultValue: 'https://console.cordato.cloud/v1',
);

final coreModule = createModule(
  register: (context) => context
    ..addLazySingleton<PersistCookieJar>(
      (Directory directory) => PersistCookieJar(
        ignoreExpires: false,
        persistSession: true,
        storage: FileStorage('${directory.path}/$projectId/cookies'),
      ),
    )
    ..addLazySingleton<Dio>(
      (PersistCookieJar cookies) => HttpClient.create(
        cookies: cookies,
        endpoint: endpoint,
        projectId: projectId,
      ),
    )
    ..addLazySingleton<IShareClient>(ShareClient.new)
    ..addLazySingleton<IMoneyFormatter>(MoneyFormatter.new)
    ..addLazySingleton<IDateFormatter>(() => DateFormatter())
    ..addLazySingleton<IHomeWidgetClient>(HomeWidgetClient.new)
    ..addLazySingleton<IRecordingClient>(() => RecordingClient()),
);
