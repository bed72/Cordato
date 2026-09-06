import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/welcome/welcome_module.dart';
import 'package:cordato/features/dashboard/dashboard_module.dart';
import 'package:cordato/features/authentication/authentication_module.dart';

final appModule = createModule(
  register: (context) {
    context
      ..module(welcomeModule)
      ..module(dashboardModule)
      ..module(authenticationModule);
  },
);
