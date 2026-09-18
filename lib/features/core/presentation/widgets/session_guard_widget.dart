import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/domain/entities/auth_session_state.dart';
import 'package:cordato/features/core/presentation/mixins/session_guard_widget_state_mixin.dart';

final class const SessionGuardWidget({
  super.key,
  required final Widget child,
  required final ValueListenable<AuthSessionStateEnum> state,
  required final VoidCallback onAuthenticated,
  required final VoidCallback onUnauthenticated,
}) extends StatefulWidget {
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
