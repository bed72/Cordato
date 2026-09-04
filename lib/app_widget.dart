import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/domain/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/redirect_widget.dart';
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
          RouteState(uri: Uri.parse(RouteEnum.dashboard.path)),
        ),
      ),
      child: MaterialApp.router(
        title: 'Cordato',
        themeMode: .system,
        theme: Themes.light,
        darkTheme: Themes.dark,
        routerConfig: routerConfig,
        debugShowCheckedModeBanner: kDebugMode,
        builder: (_, child) =>
            ToastProviderWidget(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
