import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  test('authentication and session resolve the same SDK without importing each other', () async {
    final fixture = PocketBaseFixture();
    fixture.respond = (_) => PocketBaseFixture.authResponse();
    addTearDown(fixture.client.close);
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<PocketBase>(fixture.client)
          ..module(authenticationModule)
          ..module(sessionModule),
      ),
    );
    addTearDown(boot.injector.dispose);
    final session = boot.injector.get<SessionBloc>();
    final authentication = boot.injector.get<IAuthenticationRepository>();
    addTearDown(session.close);

    final initiallySignedOut = session.stream.firstWhere(
      (state) => state is SessionUnauthenticated,
    );
    session.add(const SessionStartedEvent());
    await initiallySignedOut;
    final authenticated = session.stream.firstWhere(
      (state) => state is SessionAuthenticated,
    );

    await authentication.signIn(
      email: 'person@example.com',
      password: 'Example1',
    );
    await authenticated;
    expect(fixture.client.authStore.record?.id, 'user-1');
    final signedOut = session.stream.firstWhere(
      (state) => state is SessionUnauthenticated,
    );

    await authentication.signOut();
    await signedOut;

    expect(fixture.client.authStore.token, isEmpty);
    expect(fixture.requests, hasLength(1));
    expect(
      fixture.requests.single.url.path,
      '/api/collections/users/auth-with-password',
    );
  });
}
