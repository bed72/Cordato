import 'package:cordato/features/core/presentation/enums/route_enum.dart';

enum AppNavigationAction { none, dashboard, newExpense }

abstract final class AppNavigationPolicy {
  static AppNavigationAction action({
    required String path,
    required bool pendingExpense,
  }) {
    if (pendingExpense) return .newExpense;

    return (path == RouteEnum.app.path) ? .dashboard : .none;
  }
}
