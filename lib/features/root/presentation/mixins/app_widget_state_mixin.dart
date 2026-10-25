import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

mixin AppWidgetStateMixin on State<AppWidget> {
  late SessionBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc();
    bloc.add(const SessionStartedEvent());
    _scheduleInitialRoute();
  }

  @override
  void didUpdateWidget(covariant AppWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    unawaited(bloc.close());
    super.dispose();
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
      final path = target.routeState(listen: false).uri.path;
      final protected = RouteEnum.authenticatedPaths().contains(path);
      final splash = path == RouteEnum.app.path;

      switch (state) {
        case SessionInitial() || SessionLoading():
          if (protected) target.navigate(RouteEnum.app.path);
        case SessionAuthenticated():
          if (splash ||
              path == RouteEnum.welcome.path ||
              path == RouteEnum.authenticationSignIn.path) {
            target.navigate(RouteEnum.dashboard.path);
          }
        case SessionUnauthenticated() || SessionFailure():
          if (splash || protected) target.navigate(RouteEnum.welcome.path);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
