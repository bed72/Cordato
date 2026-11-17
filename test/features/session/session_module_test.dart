import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';

import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

import '../../support/session/mocks/session_repository_mock.dart';

void main() {
  test(
    'resolves independent Bloc factories with an application repository',
    () async {
      final repository = SessionRepositoryMock();
      final changes = StreamController<bool>();
      addTearDown(changes.close);
      when(repository.loadSession).thenAnswer((_) async => true);
      when(() => repository.sessionChanges).thenAnswer((_) => changes.stream);
      final boot = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<ISessionRepository>(repository)
            ..module(sessionModule),
        ),
      );
      addTearDown(boot.injector.dispose);
      final first = boot.injector.get<SessionBloc>();
      final second = boot.injector.get<SessionBloc>();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(first, isNot(same(second)));
      final authenticated = first.stream.firstWhere(
        (state) => state is SessionAuthenticated,
      );
      first.add(const SessionStartedEvent());
      await authenticated;

      expect(second.state, isA<SessionInitial>());
      verify(repository.loadSession).called(1);

      final signedOut = first.stream.firstWhere(
        (state) => state is SessionUnauthenticated,
      );
      changes.add(false);
      await signedOut;
      verifyNever(repository.loadSession);
    },
  );
}
