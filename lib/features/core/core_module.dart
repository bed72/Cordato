import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

final coreModule = createModule(
  register: (context) =>
      context.addLazySingleton<IMoneyFormatter>(MoneyFormatter.new),
);
