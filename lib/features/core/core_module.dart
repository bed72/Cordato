import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/application/clients/interface_widget_client.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/infrastructure/clients/widget/widget_client.dart';

final coreModule = createModule(
  register: (context) => context
    ..addLazySingleton<IMoneyFormatter>(MoneyFormatter.new)
    ..addLazySingleton<IDateFormatter>(() => DateFormatter())
    ..addLazySingleton<IWidgetClient>(WidgetClient.new),
);
