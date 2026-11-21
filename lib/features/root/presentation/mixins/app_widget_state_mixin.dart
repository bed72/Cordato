import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_state.dart';
import 'package:cordato/features/root/presentation/navigation/app_navigation_policy.dart';
import 'package:cordato/features/root/presentation/navigation/home_widget_expense_navigation.dart';

mixin AppWidgetStateMixin on State<AppWidget> {
  bool _pendingExpenseLaunch = false;

  late HomeWidgetSyncBloc homeWidgetSyncBloc;
  late HomeWidgetLaunchBloc homeWidgetLaunchBloc;

  @override
  void initState() {
    super.initState();

    homeWidgetSyncBloc = widget.homeWidgetSyncBloc();
    homeWidgetLaunchBloc = widget.homeWidgetLaunchBloc();

    homeWidgetSyncBloc.add(const HomeWidgetSyncStartedEvent());
    homeWidgetLaunchBloc.add(const HomeWidgetLaunchStartedEvent());

    _scheduleNavigation();
  }

  @override
  void didUpdateWidget(covariant AppWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.homeWidgetLaunchBloc != widget.homeWidgetLaunchBloc) {
      unawaited(homeWidgetLaunchBloc.close());
      homeWidgetLaunchBloc = widget.homeWidgetLaunchBloc();
      homeWidgetLaunchBloc.add(const HomeWidgetLaunchStartedEvent());
      _scheduleNavigation();
    }

    if (oldWidget.homeWidgetSyncBloc != widget.homeWidgetSyncBloc) {
      unawaited(homeWidgetSyncBloc.close());
      homeWidgetSyncBloc = widget.homeWidgetSyncBloc();
      homeWidgetSyncBloc.add(const HomeWidgetSyncStartedEvent());
    }

    if (oldWidget.navigatorKey != widget.navigatorKey) {
      _scheduleNavigation();
    }
  }

  @override
  void dispose() {
    unawaited(homeWidgetSyncBloc.close());
    unawaited(homeWidgetLaunchBloc.close());

    super.dispose();
  }

  void handleHomeWidgetLaunch(HomeWidgetLaunchState state) {
    if (state is! HomeWidgetLaunchRequested) return;

    _pendingExpenseLaunch = true;
    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    final key = widget.navigatorKey;
    final owner = homeWidgetLaunchBloc;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          owner.isClosed ||
          homeWidgetLaunchBloc != owner ||
          widget.navigatorKey != key) {
        return;
      }

      final target = key.currentContext;
      if (target == null) {
        _scheduleNavigation();
        return;
      }

      switch (AppNavigationPolicy.action(
        path: target.routeState(listen: false).uri.path,
        pendingExpense: _pendingExpenseLaunch,
      )) {
        case .none:
          break;
        case .dashboard:
          target.navigate(RouteEnum.dashboard.path);
        case .newExpense:
          _pendingExpenseLaunch = false;
          _openExpenseFromHomeWidget(target);
      }
    });

    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _openExpenseFromHomeWidget(BuildContext target) {
    HomeWidgetExpenseNavigation.open(
      popUntil: target.popUntil,
      baseRoute: target.routeState(listen: false),
      showDashboard: () => target.navigate(RouteEnum.dashboard.path),
      pushExpense: () =>
          unawaited(target.pushNamed<void>(RouteEnum.expense.path)),
    );
  }
}
