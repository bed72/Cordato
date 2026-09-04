import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/dashboard/presentation/screens/dashboard_screen.dart';

final dashboardModule = createModule(
  path: '/dashboard',
  register: (context) =>
      context.route('/', child: (_, _) => const DashboardScreen()),
);
