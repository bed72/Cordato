import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/authentication/presentation/widgets/redirect_widget.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

class AppWidget extends StatelessWidget {
  final Stream<void> events;

  const AppWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final routerConfig = ModularApp.routerConfigOf(context);

    return RedirectWidget(
      events: events,
      onAuthenticated: () => unawaited(
        routerConfig.routerDelegate.setNewRoutePath(
          RouteState(uri: Uri.parse('/dashboard')),
        ),
      ),
      child: MaterialApp.router(
        title: 'Cordato',
        themeMode: .system,
        theme: Themes.light,
        darkTheme: Themes.dark,
        routerConfig: routerConfig,
        builder: (context, child) =>
            ToastProviderWidget(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
