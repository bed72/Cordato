import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/domain/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/budget/presentation/screens/budget_screen.dart';

final budgetModule = createModule(
  path: RouteEnum.budget.path,
  register: (context) => context.route(
    RouteEnum.root.path,
    child: (context, _) => BudgetScreen(
      onBackPressed: context.pop,
      formatter: inject<IMoneyFormatter>(),
    ),
  ),
);
