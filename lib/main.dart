import 'package:flutter/foundation.dart';
import 'package:command_it/command_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';

import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/session/presentation/commands/session_command.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/commands/command_failure_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/firebase/crash_client.dart';
import 'package:cordato/features/core/infrastructure/clients/firebase/firebase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseClient.initialize();

  final navigatorKey = GlobalKey<NavigatorState>();

  runApp(
    ModularApp(
      module: appModule,
      navigatorKey: navigatorKey,
      initialRoute: RouteEnum.app.path,
      defaultTransition: TransitionType.none,
      child: Builder(
        builder: (_) {
          final client = inject<ICrashClient>();
          configureCommandExceptionHandler(client);
          FlutterError.onError = client.recordFlutterError;
          PlatformDispatcher.instance.onError = (error, stackTrace) {
            client.recordError(
              fatal: true,
              error: error,
              stackTrace: stackTrace,
            );

            return true;
          };

          return AppWidget(
            navigatorKey: navigatorKey,
            command: inject<SessionCommand>(),
          );
        },
      ),
    ),
  );
}

void configureCommandExceptionHandler(ICrashClient client) {
  Command.globalExceptionHandler = (error, stackTrace) {
    if (error.error is CommandFailureException) return;

    client.recordError(
      error: error.error,
      stackTrace: stackTrace,
      fatal: false,
    );
  };
}
