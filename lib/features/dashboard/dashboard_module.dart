import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';
import 'package:cordato/features/insight/application/repositories/interface_insight_repository.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';

final dashboardModule = createModule(
  path: RouteEnum.dashboard.path,
  register: (context) {
    context.add<DashboardBloc>(
      () => DashboardBloc(
        userRepository: inject<IUserRepository>(),
        expenseRepository: inject<IExpenseRepository>(),
        insightRepository: inject<IInsightRepository>(),
        metricsRepository: inject<IMetricsRepository>(),
      ),
    );
    context.route(
      RouteEnum.app.path,
      child: (_, _) => DashboardScreen(
        bloc: inject<DashboardBloc>,
        dateFormatter: inject<IDateFormatter>(),
        moneyFormatter: inject<IMoneyFormatter>(),
      ),
    );
  },
);
