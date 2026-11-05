import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';

import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/logger/logger_client.dart';
import 'package:cordato/features/core/infrastructure/clients/logger/app_bloc_observer.dart';
import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) Bloc.observer = AppBlocObserver(talker: loggerClient);

  final navigatorKey = GlobalKey<NavigatorState>();

  runApp(
    ModularApp(
      module: appModule,
      navigatorKey: navigatorKey,
      initialRoute: RouteEnum.app.path,
      defaultTransition: TransitionType.none,
      child: Builder(
        builder: (_) {
          return AppWidget(
            navigatorKey: navigatorKey,
            bloc: inject<SessionBloc>,
            homeWidgetClient: inject<IHomeWidgetClient>(),
          );
        },
      ),
    ),
  );
}
