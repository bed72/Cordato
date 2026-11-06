import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  test('resolves independent Bloc factories with the SDK repository without sibling routes', () async {
    final fixture = PocketBaseFixture();
    fixture.authenticate();
    fixture.respond = (_) => PocketBaseFixture.authResponse();
    addTearDown(fixture.client.close);
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<PocketBase>(fixture.client)
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
    expect(
      fixture.requests.single.url.path,
      '/api/collections/users/auth-refresh',
    );

    final signedOut = first.stream.firstWhere(
      (state) => state is SessionUnauthenticated,
    );
    fixture.client.authStore.clear();
    await signedOut;
    expect(fixture.requests, hasLength(1));
  });
}
