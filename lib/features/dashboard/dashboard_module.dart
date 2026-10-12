import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/insight/presentation/commands/get_insights_command.dart';
import 'package:cordato/features/user/presentation/screens/user/commands/user_command.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/commands/get_expenses_command.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/commands/get_first_expense_month_command.dart';

final dashboardRoutesModule = createModule(
  path: RouteEnum.dashboard.path,
  register: (context) {
    context.add(GetFirstExpenseMonthCommand.new);
    context.route(
      RouteEnum.app.path,
      child: (context, _) => DashboardScreen(
        onNotificationsPressed: () {},
        userCommand: inject<UserCommand>(),
        dateFormatter: inject<IDateFormatter>(),
        moneyFormatter: inject<IMoneyFormatter>(),
        expensesCommand: inject<GetExpensesCommand>(),
        insightsCommand: inject<GetInsightsCommand>(),
        metricsCommand: inject<GetExpenseMetricsCommand>(),
        firstExpenseMonthCommand: inject<GetFirstExpenseMonthCommand>(),
        onSeeAllExpensesPressed: (month) async => await context.pushNamed(
          RouteEnum.expenses.path,
          arguments: (
            from: DateTime(month.year, month.month),
            to: DateTime(month.year, month.month + 1, 0),
          ),
        ),
        onAvatarPressed: () => context.pushNamed(RouteEnum.user.path),
        onMenuPressed: () => context.pushNamed(RouteEnum.settings.path),
        onExpensePressed: () async => await context.pushNamed(
          RouteEnum.expense.path,
          arguments: (returnToPrevious: true),
        ),
      ),
    );
  },
);
