import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/auth_session_state.dart';
import 'package:cordato/features/core/presentation/mixins/session_guard_widget_state_mixin.dart';

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

final class _SessionGuardWidgetState extends State<SessionGuardWidget>
    with SessionGuardWidgetStateMixin {
  @override
  Widget build(BuildContext context) => switch (sessionState) {
    .loading => const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
    .authenticated || .unauthenticated || .restorationFailure => widget.child,
  };
}
