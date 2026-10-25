import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/welcome/welcome_module.dart';
import 'package:cordato/features/authentication/authentication_module.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/screens/app/app_screen.dart';

final appModule = createModule(
  register: (context) {
    context
      ..module(coreDependenciesModule)
      // ..module(userDependenciesModule)
      ..module(sessionModule)
      // ..module(expenseDependenciesModule)
      // ..module(insightDependenciesModule)
      // ..module(metricsDependenciesModule)
      ..module(authenticationModule);

    context
      // ..module(userRoutesModule)
      ..module(welcomeRoutesModule)
      // ..module(expenseRoutesModule)
      // ..module(settingsRoutesModule)
      // ..module(dashboardRoutesModule)
      ..route(RouteEnum.app.path, child: (_, _) => const AppScreen());
  },
);
