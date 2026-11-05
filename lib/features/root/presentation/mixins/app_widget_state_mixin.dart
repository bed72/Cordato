import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/navigation/session_redirect_deferral.dart';

import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/root/presentation/navigation/session_route_policy.dart';
import 'package:cordato/features/root/presentation/navigation/home_widget_launch_policy.dart';
import 'package:cordato/features/root/presentation/navigation/home_widget_expense_navigation.dart';

import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

mixin AppWidgetStateMixin on State<AppWidget> {
  late SessionBloc bloc;
  late final SessionRedirectDeferral sessionRedirectDeferral;
  StreamSubscription<Uri?>? _homeWidgetLaunches;
  bool _pendingExpenseLaunch = false;

  @override
  void initState() {
    super.initState();
    sessionRedirectDeferral = SessionRedirectDeferral(
      onReleased: () => handleSession(bloc.state, afterDeferral: true),
    );

    bloc = widget.bloc();
    bloc.add(const SessionStartedEvent());
    _listenToHomeWidget();
    _scheduleInitialRoute();
  }

  @override
  void didUpdateWidget(covariant AppWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeWidgetClient != widget.homeWidgetClient) {
      unawaited(_homeWidgetLaunches?.cancel());
      _listenToHomeWidget();
    }
    if (oldWidget.bloc != widget.bloc) {
      unawaited(bloc.close());
      bloc = widget.bloc();
      bloc.add(const SessionStartedEvent());
      handleSession(bloc.state);
    } else if (oldWidget.navigatorKey != widget.navigatorKey) {
      handleSession(bloc.state);
    }
  }

  @override
  void dispose() {
    unawaited(_homeWidgetLaunches?.cancel());
    unawaited(bloc.close());
    super.dispose();
  }

  void _listenToHomeWidget() {
    _homeWidgetLaunches = widget.homeWidgetClient.launches.listen(
      _receiveHomeWidgetLaunch,
      onError: _reportHomeWidgetError,
    );
    unawaited(_readInitialHomeWidgetLaunch());
  }

  Future<void> _readInitialHomeWidgetLaunch() async {
    final client = widget.homeWidgetClient;
    try {
      final uri = await client.initialLaunch();
      if (mounted && identical(client, widget.homeWidgetClient)) {
        _receiveHomeWidgetLaunch(uri);
      }
    } catch (error, stackTrace) {
      _reportHomeWidgetError(error, stackTrace);
    }
  }

  void _reportHomeWidgetError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'home screen widget',
      ),
    );
  }

  void _receiveHomeWidgetLaunch(Uri? uri) {
    if (!mounted || !HomeWidgetLaunchPolicy.accepts(uri)) {
      return;
    }

    _pendingExpenseLaunch = true;
    handleSession(bloc.state);
  }

  bool _handleHomeWidgetLaunch(BuildContext target, SessionState state) {
    final path = target.routeState(listen: false).uri.path;
    final action = HomeWidgetLaunchPolicy.action(
      state: state,
      pending: _pendingExpenseLaunch,
      deferred: sessionRedirectDeferral.isDeferredFor(path),
    );

    switch (action) {
      case HomeWidgetLaunchAction.wait:
        return false;
      case HomeWidgetLaunchAction.signIn:
        if (path != RouteEnum.authenticationSignIn.path) {
          target.navigate(RouteEnum.authenticationSignIn.path);
        }
        return true;
      case HomeWidgetLaunchAction.openExpense:
        _pendingExpenseLaunch = false;
        _openExpenseFromHomeWidget(target);
        return true;
    }
  }

  void _openExpenseFromHomeWidget(BuildContext target) {
    HomeWidgetExpenseNavigation.open(
      baseRoute: target.routeState(listen: false),
      popUntil: target.popUntil,
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

  void handleSession(SessionState state, {bool afterDeferral = false}) {
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
      if (_handleHomeWidgetLaunch(target, state)) {
        return;
      }
      final path = target.routeState(listen: false).uri.path;
      final redirect = SessionRoutePolicy.redirect(
        state: state,
        path: path,
        deferred: sessionRedirectDeferral.isDeferredFor(path),
        afterDeferral: afterDeferral,
      );
      if (redirect != null) target.navigate(redirect);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
