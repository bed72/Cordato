import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/infrastructure/clients/http/factories/dio_factory.dart';

const _baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://api.cordato.cloud/api/',
);

final coreModule = createModule(
  register: (context) => context
    ..addInstance<String>(_baseUrl)
    ..addInstance<Dio>(DioFactory.create(baseUrl: _baseUrl))
    ..addLazySingleton<IHttpClient>(HttpClient.new)
    ..addLazySingleton<IMoneyFormatter>(MoneyFormatter.new),
);
