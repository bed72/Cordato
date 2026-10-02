import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/infrastructure/clients/http/factories/dio_factory.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';

const _baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://api.cordato.cloud/api/',
);

final coreModule = createModule(
  register: (context) => context
    ..addInstance<String>(_baseUrl)
    ..addInstance<FlutterSecureStorage>(const FlutterSecureStorage())
    ..addLazySingleton<IStorageClient>(StorageClient.new)
    ..addLazySingleton<Dio>(
      () => DioFactory.create(
        baseUrl: _baseUrl,
        storage: inject<IStorageClient>(),
      ),
    )
    ..addLazySingleton<IHttpClient>(HttpClient.new)
    ..addLazySingleton<IMoneyFormatter>(MoneyFormatter.new),
);
