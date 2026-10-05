import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/presentation/widgets/app_widget.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/session/presentation/commands/session_command.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final navigatorKey = GlobalKey<NavigatorState>();

  runApp(
    ModularApp(
      module: appModule,
      navigatorKey: navigatorKey,
      initialRoute: RouteEnum.splash.path,
      defaultTransition: TransitionType.none,
      child: Builder(
        builder: (_) => AppWidget(
          navigatorKey: navigatorKey,
          command: inject<SessionCommand>(),
        ),
      ),
    ),
  );
}
