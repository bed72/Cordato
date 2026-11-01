import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';

import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
          );
        },
      ),
    ),
  );
}
