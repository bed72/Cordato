import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';

final coreModule = createModule(
  register: (context) => context
    ..addLazySingleton<IShareClient>(ShareClient.new)
    ..addLazySingleton<IWidgetClient>(WidgetClient.new)
    ..addLazySingleton<DatabaseClient>(DatabaseClient.new)
    ..addLazySingleton<IDateFormatter>(DateFormatter.new)
    ..addLazySingleton<IMoneyFormatter>(MoneyFormatter.new),
);
