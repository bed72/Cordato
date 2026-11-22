import 'package:cordato/app_module.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final navigatorKey = GlobalKey<NavigatorState>();

  runApp(
    ModularApp(
      module: appModule,
      navigatorKey: navigatorKey,
      initialRoute: RouteEnum.dashboard.path,
      defaultTransition: TransitionType.fade,
      child: Builder(
        builder: (_) {
          return AppWidget(
            navigatorKey: navigatorKey,
            widgetSyncBloc: inject<WidgetSyncBloc>,
            widgetLaunchBloc: inject<WidgetLaunchBloc>,
          );
        },
      ),
    ),
  );
}
