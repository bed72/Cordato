import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_event.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  test(
    'callback factories resolve the SDK repository without sibling routes',
    () async {
      final fixture = PocketBaseFixture();
      addTearDown(fixture.client.close);
      final boot = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<PocketBase>(fixture.client)
            ..module(authenticationModule),
        ),
      );
      addTearDown(boot.injector.dispose);
      final first = boot.injector.get<CallbackBloc>();
      final second = boot.injector.get<CallbackBloc>();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(first, isNot(same(second)));
      final finished = first.stream.firstWhere(
        (state) => state is CallbackSuccess,
      );
      first.add(const CallbackRequestedEvent(token: 'verification-token'));
      await finished;

      expect(second.state, isA<CallbackInitial>());
      final request = fixture.requests.single;
      expect(request.url.path, '/api/collections/users/confirm-verification');
      expect(jsonDecode(request.body), {'token': 'verification-token'});
      expect(fixture.client.authStore.token, isEmpty);
    },
  );
}
