import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard/dashboard_screen.dart';

final dashboardRoutesModule = createModule(
  path: RouteEnum.dashboard.path,
  register: (context) {
    context.route(
      RouteEnum.app.path,
      child: (context, _) => DashboardScreen(
        onBudgetPressed: () {},
        onNotificationsPressed: () {},
        onMenuPressed: () => context.pushNamed(RouteEnum.settings.path),
        onExpensePressed: () => context.pushNamed(RouteEnum.expense.path),
      ),
    );
  },
);
