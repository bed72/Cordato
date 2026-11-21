import 'package:flutter_modular/flutter_modular.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client.dart';
import 'package:cordato/features/core/application/clients/interface_share_client.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';
import 'package:cordato/features/core/infrastructure/clients/home_widget/home_widget_client.dart';

Module createCoreModule({required ToStore database}) => createModule(
  register: (context) => context
    ..addInstance<ToStore>(database)
    ..addLazySingleton<IShareClient>(ShareClient.new)
    ..addLazySingleton<IMoneyFormatter>(MoneyFormatter.new)
    ..addLazySingleton<IDateFormatter>(() => DateFormatter())
    ..addLazySingleton<IHomeWidgetClient>(HomeWidgetClient.new),
);
