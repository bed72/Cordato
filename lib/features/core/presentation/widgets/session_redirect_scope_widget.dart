import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/core/presentation/navigation/session_redirect_deferral.dart';

final class const SessionRedirectScopeWidget({
  required final SessionRedirectDeferral deferral,
  required super.child,
  super.key,
}) extends InheritedWidget {
  static SessionRedirectDeferral? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<SessionRedirectScopeWidget>()
      ?.deferral;

  @override
  bool updateShouldNotify(SessionRedirectScopeWidget oldWidget) =>
      deferral != oldWidget.deferral;
}
