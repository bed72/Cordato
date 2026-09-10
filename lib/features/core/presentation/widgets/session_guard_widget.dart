import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/auth_session_state.dart';

final class SessionGuardWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onAuthenticated;
  final VoidCallback onUnauthenticated;
  final ValueListenable<AuthSessionStateEnum> sessionState;

  const SessionGuardWidget({
    super.key,
    required this.child,
    required this.sessionState,
    required this.onAuthenticated,
    required this.onUnauthenticated,
  });

  @override
  State<SessionGuardWidget> createState() => _SessionGuardWidgetState();
}

final class _SessionGuardWidgetState extends State<SessionGuardWidget> {
  int _transitionId = 0;
  late AuthSessionStateEnum _state;

  @override
  void initState() {
    super.initState();
    _state = widget.sessionState.value;
    widget.sessionState.addListener(_onSessionChanged);
    _scheduleNavigation(
      _state,
      shouldNavigate: _state == .authenticated || _state == .restorationFailure,
    );
  }

  @override
  void didUpdateWidget(SessionGuardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.sessionState, widget.sessionState)) return;

    oldWidget.sessionState.removeListener(_onSessionChanged);
    _state = widget.sessionState.value;
    widget.sessionState.addListener(_onSessionChanged);
    _scheduleNavigation(_state, shouldNavigate: _state != .unauthenticated);
  }

  void _onSessionChanged() {
    final nextState = widget.sessionState.value;
    if (_state == nextState) return;

    final previousState = _state;
    setState(() => _state = nextState);
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

  @override
  Widget build(BuildContext context) => switch (_state) {
    .loading => const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
    .authenticated || .unauthenticated || .restorationFailure => widget.child,
  };
}
