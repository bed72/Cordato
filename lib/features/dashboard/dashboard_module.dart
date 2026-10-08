import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';

final dashboardRoutesModule = createModule(
  path: RouteEnum.dashboard.path,
  register: (context) {
    context.route(
      RouteEnum.app.path,
      child: (context, _) => DashboardScreen(
        onBudgetPressed: () {},
        onNotificationsPressed: () {},
        userCommand: inject<UserCommand>(),
        dateFormatter: inject<IDateFormatter>(),
        moneyFormatter: inject<IMoneyFormatter>(),
        expensesCommand: inject<GetExpensesCommand>(),
        onSeeAllExpensesPressed: () async =>
            await context.pushNamed(RouteEnum.expenses.path),
        onAvatarPressed: () => context.pushNamed(RouteEnum.user.path),
        onMenuPressed: () => context.pushNamed(RouteEnum.settings.path),
        onExpensePressed: () async =>
            await context.pushNamed(RouteEnum.expense.path),
      ),
    );
  },
);
