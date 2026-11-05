import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_state.dart';
import 'package:cordato/features/root/presentation/mixins/app_widget_state_mixin.dart';

import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/core/presentation/widgets/session_redirect_scope_widget.dart';

class const AppWidget({
  super.key,
  required final SessionBloc Function() sessionBloc,
  required final GlobalKey<NavigatorState> navigatorKey,
  required final HomeWidgetSyncBloc Function() homeWidgetSyncBloc,
  required final HomeWidgetLaunchBloc Function() homeWidgetLaunchBloc,
}) extends StatefulWidget {
  @override
  State<AppWidget> createState() => _AppWidgetState();
}

final class _AppWidgetState extends State<AppWidget> with AppWidgetStateMixin {
  @override
  Widget build(BuildContext context) {
    final routerConfig = ModularApp.routerConfigOf(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<SessionBloc, SessionState>(
          bloc: bloc,
          listener: (_, state) => handleSessionChange(state),
        ),
        BlocListener<HomeWidgetLaunchBloc, HomeWidgetLaunchState>(
          bloc: homeWidgetLaunchBloc,
          listener: (_, state) => handleHomeWidgetLaunch(state),
        ),
      ],
      child: MaterialApp.router(
        title: 'Cordato',
        themeMode: .system,
        theme: Themes.light,
        darkTheme: Themes.dark,
        routerConfig: routerConfig,
        locale: const Locale('pt', 'BR'),
        debugShowCheckedModeBanner: kDebugMode,
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (_, child) => SessionRedirectScopeWidget(
          deferral: sessionRedirectDeferral,
          child: ToastProviderWidget(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
