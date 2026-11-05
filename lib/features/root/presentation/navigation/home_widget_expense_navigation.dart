import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

abstract final class HomeWidgetExpenseNavigation {
  static void open({
    required RouteState baseRoute,
    required void Function(bool Function(RouteState)) popUntil,
    required void Function() showDashboard,
    required void Function() pushExpense,
  }) {
    var hasNewExpense = _isNewExpense(baseRoute);
    popUntil((route) {
      final isNewExpense = _isNewExpense(route);
      if (isNewExpense) {
        hasNewExpense = true;
      }
      return isNewExpense;
    });
    if (hasNewExpense) {
      return;
    }

    if (baseRoute.uri.path != RouteEnum.dashboard.path) {
      showDashboard();
    }
    pushExpense();
  }

  static bool _isNewExpense(RouteState route) =>
      route.uri.path == RouteEnum.expense.path && route.arguments is! String;
}
