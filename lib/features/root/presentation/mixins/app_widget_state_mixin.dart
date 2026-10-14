import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/widgets/app_widget.dart';

mixin AppWidgetStateMixin on State<AppWidget> {
  int _sessionRevision = 0;

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

  @override
  void didUpdateWidget(covariant AppWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command != widget.command) {
      oldWidget.command.execute.removeListener(_handleSession);
      widget.command.execute.addListener(_handleSession);
    }

    if (oldWidget.command != widget.command ||
        oldWidget.navigatorKey != widget.navigatorKey) {
      _handleSession();
    }
  }

  void _handleSession() {
    final revision = ++_sessionRevision;
    final command = widget.command;
    final navigatorKey = widget.navigatorKey;
    final hasSession = widget.command.execute.value;

    if (hasSession == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _sessionRevision ||
          widget.command != command ||
          widget.navigatorKey != navigatorKey) {
        return;
      }
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
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _sessionRevision++;
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
