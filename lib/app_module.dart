import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/budget/budget_module.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/welcome/welcome_module.dart';
import 'package:cordato/features/settings/settings_module.dart';
import 'package:cordato/features/dashboard/dashboard_module.dart';
import 'package:cordato/features/authentication/authentication_module.dart';

final appModule = createModule(
  register: (context) {
    context
      ..module(coreModule)
      ..module(budgetModule)
      ..module(expenseModule)
      ..module(welcomeModule)
      ..module(settingsModule)
      ..module(dashboardModule)
      ..module(authenticationModule);
  },
);
