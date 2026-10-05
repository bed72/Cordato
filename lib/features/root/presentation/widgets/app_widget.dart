import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/root/presentation/mixins/app_widget_state_mixin.dart';

import 'package:cordato/features/session/presentation/commands/session_command.dart';

import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

class const AppWidget({
  super.key,
  required final SessionCommand command,
  required final GlobalKey<NavigatorState> navigatorKey,
}) extends StatefulWidget {
  @override
  State<AppWidget> createState() => _AppWidgetState();
}

final class _AppWidgetState extends State<AppWidget> with AppWidgetStateMixin {
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
