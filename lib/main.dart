import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/factory.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final module = await createDependencies();
  final navigatorKey = GlobalKey<NavigatorState>();

  runApp(
    ModularApp(
      module: module,
      navigatorKey: navigatorKey,
      initialRoute: RouteEnum.app.path,
      defaultTransition: TransitionType.fade,
      child: Builder(
        builder: (_) {
          return AppWidget(
            navigatorKey: navigatorKey,
            homeWidgetSyncBloc: inject<HomeWidgetSyncBloc>,
            homeWidgetLaunchBloc: inject<HomeWidgetLaunchBloc>,
          );
        },
      ),
    ),
  );
}
