import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/session/presentation/commands/session_command.dart';

class const AppWidget({
  super.key,
  required final GlobalKey<NavigatorState> navigatorKey,
}) extends StatefulWidget {
  @override
  State<AppWidget> createState() => _AppWidgetState();
}

final class _AppWidgetState extends State<AppWidget> {
  late final SessionCommand _sessionCommand;

  static final _protectedPaths = {
    RouteEnum.dashboard.path,
    RouteEnum.settings.path,
    RouteEnum.expense.path,
  };

  @override
  void initState() {
    super.initState();
    _sessionCommand = inject<SessionCommand>();
    _sessionCommand.execute.addListener(_handleSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = widget.navigatorKey.currentContext;
      if (context != null &&
          _protectedPaths.contains(
            context.routeState(listen: false).uri.path,
          )) {
        context.navigate(RouteEnum.splash.path);
      }
    });
  }

  void _handleSession() {
    final hasSession = _sessionCommand.execute.value;
    if (hasSession == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = widget.navigatorKey.currentContext;
      if (context == null) return;
      final path = context.routeState(listen: false).uri.path;

      if (hasSession &&
          (path == RouteEnum.welcome.path ||
              path == RouteEnum.authenticationSignIn.path)) {
        navigateToDashboard();
      } else if (!hasSession && _protectedPaths.contains(path)) {
        navigateToWelcome();
      }
    });
  }

  @override
  void dispose() {
    _sessionCommand.execute.removeListener(_handleSession);
    super.dispose();
  }

  void navigateToWelcome() => _navigate(RouteEnum.welcome.path);
  void navigateToDashboard() => _navigate(RouteEnum.dashboard.path);

  void _navigate(String path) =>
      widget.navigatorKey.currentContext?.navigate(path);

  @override
  Widget build(BuildContext context) {
    final routerConfig = ModularApp.routerConfigOf(context);

    return MaterialApp.router(
      title: 'Cordato',
      themeMode: .system,
      theme: Themes.light,
      darkTheme: Themes.dark,
      routerConfig: routerConfig,
      locale: const Locale('pt', 'BR'),
      debugShowCheckedModeBanner: kDebugMode,
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (_, child) =>
          ToastProviderWidget(child: child ?? const SizedBox.shrink()),
    );
  }
}
