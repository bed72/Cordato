import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/expense/domain/repositories/interface_expense_repository.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';

final dashboardRoutesModule = createModule(
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
