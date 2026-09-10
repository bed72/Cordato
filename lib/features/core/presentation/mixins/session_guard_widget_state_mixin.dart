import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/auth_session_state.dart';
import 'package:cordato/features/core/presentation/widgets/session_guard_widget.dart';

mixin SessionGuardWidgetStateMixin on State<SessionGuardWidget> {
  int _transitionId = 0;
  late AuthSessionStateEnum _sessionState;

  AuthSessionStateEnum get sessionState => _sessionState;

  @override
  void initState() {
    super.initState();
    _sessionState = widget.sessionState.value;
    widget.sessionState.addListener(_onSessionChanged);
    _scheduleNavigation(
      _sessionState,
      shouldNavigate:
          _sessionState == .authenticated ||
          _sessionState == .restorationFailure,
    );
  }

  @override
  void didUpdateWidget(covariant SessionGuardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.sessionState, widget.sessionState)) return;

    oldWidget.sessionState.removeListener(_onSessionChanged);
    _sessionState = widget.sessionState.value;
    widget.sessionState.addListener(_onSessionChanged);
    _scheduleNavigation(
      _sessionState,
      shouldNavigate: _sessionState != .unauthenticated,
    );
  }

  void _onSessionChanged() {
    final nextState = widget.sessionState.value;
    if (_sessionState == nextState) return;

    final previousState = _sessionState;
    setState(() => _sessionState = nextState);
    _scheduleNavigation(
      nextState,
      shouldNavigate:
          nextState == .authenticated ||
          nextState == .restorationFailure ||
          (nextState == .unauthenticated && previousState != .loading),
    );
  }

  void _scheduleNavigation(
    AuthSessionStateEnum state, {
    required bool shouldNavigate,
  }) {
    final transitionId = ++_transitionId;
    if (!shouldNavigate) return;

    scheduleMicrotask(() {
      if (!mounted || transitionId != _transitionId) return;

      switch (state) {
        case .authenticated:
          widget.onAuthenticated();
        case .unauthenticated || .restorationFailure:
          widget.onUnauthenticated();
        case .loading:
          break;
      }
    });
  }

  @override
  void dispose() {
    widget.sessionState.removeListener(_onSessionChanged);
    super.dispose();
  }
}
