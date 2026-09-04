import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/domain/enums/app_route.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard_screen.dart';

final dashboardModule = createModule(
  path: AppRoute.dashboard.path,
  register: (context) => context.route(
    AppRoute.root.path,
    child: (_, _) => const DashboardScreen(),
  ),
);
