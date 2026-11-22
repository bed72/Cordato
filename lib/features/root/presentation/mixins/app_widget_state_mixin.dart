import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_state.dart';
import 'package:cordato/features/root/presentation/navigation/app_navigation_policy.dart';
import 'package:cordato/features/root/presentation/navigation/widget_expense_navigation.dart';

mixin AppWidgetStateMixin on State<AppWidget> {
  bool _pendingExpenseLaunch = false;

  late WidgetSyncBloc widgetSyncBloc;
  late WidgetLaunchBloc widgetLaunchBloc;

  @override
  void initState() {
    super.initState();

    widgetSyncBloc = widget.widgetSyncBloc();
    widgetLaunchBloc = widget.widgetLaunchBloc();

    widgetSyncBloc.add(const WidgetSyncStartedEvent());
    widgetLaunchBloc.add(const WidgetLaunchStartedEvent());

    _scheduleNavigation();
  }

  @override
  void didUpdateWidget(covariant AppWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.widgetLaunchBloc != widget.widgetLaunchBloc) {
      unawaited(widgetLaunchBloc.close());
      widgetLaunchBloc = widget.widgetLaunchBloc();
      widgetLaunchBloc.add(const WidgetLaunchStartedEvent());
      _scheduleNavigation();
    }

    if (oldWidget.widgetSyncBloc != widget.widgetSyncBloc) {
      unawaited(widgetSyncBloc.close());
      widgetSyncBloc = widget.widgetSyncBloc();
      widgetSyncBloc.add(const WidgetSyncStartedEvent());
    }

    if (oldWidget.navigatorKey != widget.navigatorKey) {
      _scheduleNavigation();
    }
  }

  @override
  void dispose() {
    unawaited(widgetSyncBloc.close());
    unawaited(widgetLaunchBloc.close());

    super.dispose();
  }

  void handleWidgetLaunch(WidgetLaunchState state) {
    if (state is! WidgetLaunchRequested) return;

    _pendingExpenseLaunch = true;
    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    final key = widget.navigatorKey;
    final owner = widgetLaunchBloc;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          owner.isClosed ||
          widgetLaunchBloc != owner ||
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
          _openExpenseFromWidget(target);
      }
    });

    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _openExpenseFromWidget(BuildContext target) {
    WidgetExpenseNavigation.open(
      popUntil: target.popUntil,
      baseRoute: target.routeState(listen: false),
      showDashboard: () => target.navigate(RouteEnum.dashboard.path),
      pushExpense: () =>
          unawaited(target.pushNamed<void>(RouteEnum.expense.path)),
    );
  }
}
