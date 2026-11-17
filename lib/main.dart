import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';

import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final navigatorKey = GlobalKey<NavigatorState>();
  final directory = await getApplicationSupportDirectory();

  runApp(
    ModularApp(
      navigatorKey: navigatorKey,
      module: appModule(directory: directory),
      initialRoute: RouteEnum.app.path,
      defaultTransition: TransitionType.fade,
      child: Builder(
        builder: (_) {
          return AppWidget(
            navigatorKey: navigatorKey,
            sessionBloc: inject<SessionBloc>,
            homeWidgetSyncBloc: inject<HomeWidgetSyncBloc>,
            homeWidgetLaunchBloc: inject<HomeWidgetLaunchBloc>,
          );
        },
      ),
    ),
  );
}
