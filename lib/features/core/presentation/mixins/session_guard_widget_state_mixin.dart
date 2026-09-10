import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/auth_session_state.dart';
import 'package:cordato/features/core/presentation/widgets/session_guard_widget.dart';

mixin SessionGuardWidgetStateMixin on State<SessionGuardWidget> {
  int _transitionId = 0;
  late AuthSessionStateEnum _state;

  AuthSessionStateEnum get sessionState => _state;

  @override
  void initState() {
    super.initState();
    _state = widget.state.value;
    widget.state.addListener(_onSessionChanged);
    _scheduleNavigation(
      _state,
      shouldNavigate: _state == .authenticated || _state == .restorationFailure,
    );
  }

  @override
  void didUpdateWidget(covariant SessionGuardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.state, widget.state)) return;

    oldWidget.state.removeListener(_onSessionChanged);
    _state = widget.state.value;
    widget.state.addListener(_onSessionChanged);
    _scheduleNavigation(_state, shouldNavigate: _state != .unauthenticated);
  }

  void _onSessionChanged() {
    final nextState = widget.state.value;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    widget.state.removeListener(_onSessionChanged);
    super.dispose();
  }
}
