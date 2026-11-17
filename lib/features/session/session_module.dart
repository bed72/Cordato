import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/infrastructure/repositories/session_repository.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';

final sessionModule = createModule(
  register: (context) => context
    ..addLazySingleton<ISessionRepository>(SessionRepository.new)
    ..add<SessionBloc>(SessionBloc.new),
);
