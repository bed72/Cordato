import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';
import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  test('account deletion notifies Session through the shared SDK AuthStore', () async {
    final fixture = PocketBaseFixture();
    fixture.authenticate();
    fixture.respond = (request) {
      if (request.url.path.endsWith('/auth-refresh')) {
        return PocketBaseFixture.authResponse();
      }

      return http.Response('', 204);
    };
    addTearDown(fixture.client.close);
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<PocketBase>(fixture.client)
          ..module(userModule)
          ..module(sessionModule),
      ),
    );
    addTearDown(boot.injector.dispose);
    final session = boot.injector.get<SessionBloc>();
    addTearDown(session.close);
    final authenticated = session.stream.firstWhere(
      (state) => state is SessionAuthenticated,
    );

    session.add(const SessionStartedEvent());
    await authenticated;
    final signedOut = session.stream.firstWhere(
      (state) => state is SessionUnauthenticated,
    );

    await boot.injector.get<IUserRepository>().delete();
    await signedOut;

    expect(fixture.client.authStore.token, isEmpty);
    expect(fixture.requests.map((request) => request.method), ['POST', 'DELETE']);
  });
}
