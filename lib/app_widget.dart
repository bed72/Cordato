import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_mixin.dart';
import 'package:cordato/features/core/domain/entities/auth_session_state.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/session_guard_widget.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

class AppWidget extends StatefulWidget {
  final Future<void> Function() dispose;
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueListenable<AuthSessionStateEnum> state;

  const AppWidget({
    super.key,
    required this.state,
    required this.dispose,
    required this.navigatorKey,
  });

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

final class _AppWidgetState extends State<AppWidget> with AppMixin {
  @override
  void didUpdateWidget(AppWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      unawaited(oldWidget.dispose());
    }
  }

  @override
  void dispose() {
    unawaited(widget.dispose());
    super.dispose();
  }

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
        child: SessionGuardWidget(
          state: widget.state,
          onAuthenticated: navigateToDashboard,
          onUnauthenticated: navigateToWelcome,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
