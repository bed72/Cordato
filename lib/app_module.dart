import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/insight/insight_module.dart';
import 'package:cordato/features/welcome/welcome_module.dart';
import 'package:cordato/features/settings/settings_module.dart';
import 'package:cordato/features/dashboard/dashboard_module.dart';
import 'package:cordato/features/authentication/authentication_module.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/screens/app/app_screen.dart';
import 'package:cordato/features/session/presentation/commands/session_command.dart';

final appModule = createModule(
  register: (context) {
    context
      ..module(coreDependenciesModule)
      ..module(userDependenciesModule)
      ..module(sessionDependenciesModule)
      ..module(expenseDependenciesModule)
      ..module(insightDependenciesModule)
      ..module(authenticationDependenciesModule);

    context
      ..module(userRoutesModule)
      ..module(welcomeRoutesModule)
      ..module(expenseRoutesModule)
      ..module(settingsRoutesModule)
      ..module(dashboardRoutesModule)
      ..module(authenticationRoutesModule)
      ..route(
        RouteEnum.app.path,
        child: (_, _) => AppScreen(
          command: inject<SessionCommand>(),
          onAuthenticated: (BuildContext context) =>
              context.navigate(RouteEnum.dashboard.path),
          onUnauthenticated: (BuildContext context) =>
              context.navigate(RouteEnum.welcome.path),
        ),
      );
  },
);
