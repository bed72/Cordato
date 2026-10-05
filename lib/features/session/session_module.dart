import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/session/data/repositories/session_repository.dart';

import 'package:cordato/features/session/presentation/commands/session_command.dart';

import 'package:cordato/features/session/infrastructure/local/session_local_data_source.dart';
import 'package:cordato/features/session/domain/repositories/interface_session_repository.dart';

final sessionDependenciesModule = createModule(
  register: (context) => context
    ..addLazySingleton<ISessionLocalDataSource>(SessionLocalDataSource.new)
    ..addLazySingleton<ISessionRepository>(SessionRepository.new)
    ..addLazySingleton<SessionCommand>(SessionCommand.new),
);
