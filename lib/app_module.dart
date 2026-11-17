import 'dart:io';

import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/root/root_module.dart';
import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/welcome/welcome_module.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/metrics/metrics_module.dart';
import 'package:cordato/features/settings/settings_module.dart';
import 'package:cordato/features/dashboard/dashboard_module.dart';
import 'package:cordato/features/information/information_module.dart';
import 'package:cordato/features/authentication/authentication_module.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/screens/app_screen.dart';

Module createAppModule({
  required PocketBase pocketBase,
  required Directory supportDirectory,
}) => createModule(
  register: (context) => context
    ..addInstance<Directory>(supportDirectory)
    ..addInstance<PocketBase>(pocketBase)
    ..module(coreModule)
    ..module(userModule)
    ..module(rootModule)
    ..module(sessionModule)
    ..module(expenseModule)
    ..module(metricsModule)
    ..module(welcomeModule)
    ..module(settingsModule)
    ..module(dashboardModule)
    ..module(informationModule)
    ..module(authenticationModule)
    ..route(RouteEnum.app.path, child: (_, _) => const AppScreen()),
);
