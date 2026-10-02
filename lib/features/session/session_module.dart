import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/session/data/repositories/session_repository.dart';

import 'package:cordato/features/session/presentation/commands/session_command.dart';
import 'package:cordato/features/session/presentation/screens/splash/splash_screen.dart';

import 'package:cordato/features/session/infrastructure/local/session_local_data_source.dart';
import 'package:cordato/features/session/domain/repositories/interface_session_repository.dart';

final sessionModule = createModule(
  register: (context) => context
    ..addLazySingleton<ISessionLocalDataSource>(SessionLocalDataSource.new)
    ..addLazySingleton<ISessionRepository>(SessionRepository.new)
    ..addLazySingleton<SessionCommand>(SessionCommand.new)
    ..route(
      RouteEnum.splash.path,
      child: (_, _) => SplashScreen(
        command: inject<SessionCommand>(),
        onAuthenticated: (BuildContext context) =>
            context.navigate(RouteEnum.dashboard.path),
        onUnauthenticated: (BuildContext context) =>
            context.navigate(RouteEnum.welcome.path),
      ),
    ),
);
