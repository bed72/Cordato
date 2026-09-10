import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/app_widget.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/external_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final navigatorKey = GlobalKey<NavigatorState>();
  final client = await ExternalClient.ensureInitialized();

  runApp(
    ModularApp(
      module: appModule,
      navigatorKey: navigatorKey,
      defaultTransition: TransitionType.none,
      initialRoute: RouteEnum.welcome.path,
      child: AppWidget(
        sessionState: client.sessionState,
        disposeSession: client.dispose,
        navigatorKey: navigatorKey,
      ),
    ),
  );
}
