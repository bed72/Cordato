import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/bloc_scoped_extension.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

import 'package:cordato/features/dashboard/presentation/screens/bloc/audio_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';

import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final dashboardModule = createModule(
  path: RouteEnum.dashboard.path,
  register: (context) {
    context
      ..add<DashboardBloc>(
        () => DashboardBloc(
          userRepository: inject<IUserRepository>(),
          expenseRepository: inject<IExpenseRepository>(),
          metricsRepository: inject<IMetricsRepository>(),
        ),
      )
      ..route(
        RouteEnum.app.path,
        child: (context, _) => DashboardScreen(
          dashboardBloc: inject<DashboardBloc>,
          dateFormatter: inject<IDateFormatter>(),
          moneyFormatter: inject<IMoneyFormatter>(),
        ),
      );
  },
);
