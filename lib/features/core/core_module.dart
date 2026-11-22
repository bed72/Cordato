import 'package:localstore/localstore.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';

final coreModule = createModule(
  register: (context) => context
    ..addInstance<Localstore>(Localstore.instance)
    ..addLazySingleton<IWidgetClient>(WidgetClient.new)
    ..addLazySingleton<IDateFormatter>(DateFormatter.new)
    ..addLazySingleton<IMoneyFormatter>(MoneyFormatter.new),
);
