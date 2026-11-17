import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_state.dart';

import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/root/presentation/navigation/session_route_policy.dart';
import 'package:cordato/features/root/presentation/navigation/home_widget_launch_policy.dart';
import 'package:cordato/features/root/presentation/navigation/home_widget_expense_navigation.dart';

import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

mixin AppWidgetStateMixin on State<AppWidget> {
  bool _pendingExpenseLaunch = false;

  late SessionBloc bloc;
  late HomeWidgetSyncBloc homeWidgetSyncBloc;
  late HomeWidgetLaunchBloc homeWidgetLaunchBloc;

  @override
  void initState() {
    super.initState();
    bloc = widget.sessionBloc();
    homeWidgetLaunchBloc = widget.homeWidgetLaunchBloc();
    homeWidgetSyncBloc = widget.homeWidgetSyncBloc();
    homeWidgetLaunchBloc.add(const HomeWidgetLaunchStartedEvent());
    homeWidgetSyncBloc.add(const HomeWidgetSyncStartedEvent());

    bloc.add(const SessionStartedEvent());
    _scheduleInitialRoute();
  }

  @override
  void didUpdateWidget(covariant AppWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeWidgetLaunchBloc != widget.homeWidgetLaunchBloc) {
      unawaited(homeWidgetLaunchBloc.close());
      homeWidgetLaunchBloc = widget.homeWidgetLaunchBloc();
      homeWidgetLaunchBloc.add(const HomeWidgetLaunchStartedEvent());
    }

    if (oldWidget.homeWidgetSyncBloc != widget.homeWidgetSyncBloc) {
      unawaited(homeWidgetSyncBloc.close());
      homeWidgetSyncBloc = widget.homeWidgetSyncBloc();
      homeWidgetSyncBloc.add(const HomeWidgetSyncStartedEvent());
      handleSessionChange(bloc.state);
    }

    if (oldWidget.sessionBloc != widget.sessionBloc) {
      unawaited(bloc.close());
      bloc = widget.sessionBloc();
      bloc.add(const SessionStartedEvent());
      handleSession(bloc.state);
    } else if (oldWidget.navigatorKey != widget.navigatorKey) {
      handleSession(bloc.state);
    }
  }

  @override
  void dispose() {
    unawaited(homeWidgetLaunchBloc.close());
    unawaited(homeWidgetSyncBloc.close());
    unawaited(bloc.close());

    super.dispose();
  }

  void handleSessionChange(SessionState state) {
    switch (state) {
      case SessionAuthenticated():
        homeWidgetSyncBloc.add(
          const HomeWidgetSessionChangedEvent(authenticated: true),
        );
      case SessionUnauthenticated():
        homeWidgetSyncBloc.add(
          const HomeWidgetSessionChangedEvent(authenticated: false),
        );
      case SessionInitial() || SessionLoading() || SessionFailure():
        break;
    }
    handleSession(state);
  }

  void handleHomeWidgetLaunch(HomeWidgetLaunchState state) {
    if (state is! HomeWidgetLaunchRequested) return;

    _pendingExpenseLaunch = true;
    handleSession(bloc.state);
  }

  bool _handleHomeWidgetLaunch(BuildContext target, SessionState state) {
    final path = target.routeState(listen: false).uri.path;
    final action = HomeWidgetLaunchPolicy.action(
      state: state,
      pending: _pendingExpenseLaunch,
    );

    switch (action) {
      case .wait:
        return false;
      case .signIn:
        if (path != RouteEnum.authenticationSignIn.path &&
            path != RouteEnum.authenticationConfirm.path) {
          target.navigate(RouteEnum.authenticationSignIn.path);
        }
        return true;
      case .openExpense:
        _pendingExpenseLaunch = false;
        _openExpenseFromHomeWidget(target);
        return true;
    }
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

  void _scheduleInitialRoute() {
    final owner = bloc;
    final key = widget.navigatorKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(bloc, owner) ||
          owner.isClosed ||
          widget.navigatorKey != key) {
        return;
      }

      final target = key.currentContext;
      if (target == null) {
        _scheduleInitialRoute();
        return;
      }

      if (RouteEnum.authenticatedPaths().contains(
        target.routeState(listen: false).uri.path,
      )) {
        target.navigate(RouteEnum.app.path);
      }

      handleSession(owner.state);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void handleSession(SessionState state) {
    final owner = bloc;
    final key = widget.navigatorKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(bloc, owner) ||
          owner.isClosed ||
          owner.state != state ||
          widget.navigatorKey != key) {
        return;
      }

      final target = key.currentContext;
      if (target == null) return;
      if (_handleHomeWidgetLaunch(target, state)) return;

      final path = target.routeState(listen: false).uri.path;
      final redirect = SessionRoutePolicy.redirect(state: state, path: path);
      if (redirect != null) target.navigate(redirect);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
