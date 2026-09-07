import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_mixin.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/redirect_widget.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

class AppWidget extends StatefulWidget {
  final Stream<void> events;
  final Future<void> Function() signOut;
  final GlobalKey<NavigatorState> navigatorKey;

  const AppWidget({
    super.key,
    required this.events,
    required this.signOut,
    required this.navigatorKey,
  });

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

final class _AppWidgetState extends State<AppWidget> with AppMixin {
  @override
  Widget build(BuildContext context) {
    final routerConfig = ModularApp.routerConfigOf(context);

    return MaterialApp.router(
      title: 'Cordato',
      themeMode: .system,
      theme: Themes.light,
      darkTheme: Themes.dark,
      routerConfig: routerConfig,
      debugShowCheckedModeBanner: kDebugMode,
      builder: (_, child) => ToastProviderWidget(
        child: RedirectWidget(
          events: widget.events,
          onAuthenticated: navigateToDashboard,
          onAuthenticationFailure: recoverFromAuthenticationFailure,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
