import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/presentation/widgets/app_widget.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

mixin AppWidgetStateMixin on State<AppWidget> {
  @override
  void initState() {
    super.initState();

    widget.command.execute.addListener(_handleSession);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_context == null) return;

      if (_contains(_context!)) _context?.navigate(RouteEnum.app.path);
    });
  }

  void _handleSession() {
    final hasSession = widget.command.execute.value;

    if (hasSession == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_context == null) return;

      final path = _context?.routeState(listen: false).uri.path;

      if (hasSession) {
        final isEntryRoute =
            path == RouteEnum.welcome.path ||
            path == RouteEnum.authenticationSignIn.path;

        if (isEntryRoute) navigateToDashboard();

        return;
      }

      final authentication = RouteEnum.authenticatedPaths().contains(path);

      if (authentication) navigateToWelcome();
    });
  }

  @override
  void dispose() {
    widget.command.execute.removeListener(_handleSession);
    super.dispose();
  }

  void navigateToWelcome() => _navigate(RouteEnum.welcome.path);
  void navigateToDashboard() => _navigate(RouteEnum.dashboard.path);

  BuildContext? get _context => widget.navigatorKey.currentContext;

  void _navigate(String path) =>
      widget.navigatorKey.currentContext?.navigate(path);

  bool _contains(BuildContext context) => RouteEnum.authenticatedPaths()
      .contains(context.routeState(listen: false).uri.path);
}
