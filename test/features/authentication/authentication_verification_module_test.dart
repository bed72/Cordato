import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_state.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  test('verification retry after SDK creation never recreates the account or a session', () async {
    final fixture = PocketBaseFixture();
    var verificationAttempts = 0;
    fixture.respond = (request) {
      if (request.url.path.endsWith('/records')) {
        return PocketBaseFixture.jsonResponse({'id': 'user-1'});
      }
      if (++verificationAttempts == 1) {
        throw const SocketException('offline');
      }
      return PocketBaseFixture.jsonResponse({}, status: 204);
    };
    addTearDown(fixture.client.close);
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<PocketBase>(fixture.client)
          ..module(authenticationModule),
      ),
    );
    addTearDown(boot.injector.dispose);
    final signUp = boot.injector.get<SignUpBloc>();
    final verification = boot.injector.get<ResendEmailBloc>();
    addTearDown(signUp.close);
    addTearDown(verification.close);

    final created = signUp.stream.firstWhere((state) => state is SignUpSuccess);
    signUp.add(
      const SignUpSubmittedEvent(
        email: 'person@example.com',
        password: 'Example1',
      ),
    );
    final account = await created as SignUpSuccess;

    final failed = verification.stream.firstWhere(
      (state) => state is ResendEmailFailure,
    );
    verification.add(ResendEmailStartedEvent(email: account.email));
    final failure = await failed as ResendEmailFailure;
    expect(failure.isInitialRequest, isTrue);
    expect(failure.canSubmit, isTrue);
    expect(failure.remaining, Duration.zero);
    expect(signUp.state, same(account));
    expect(signUp.state.canSubmit, isFalse);

    final sent = verification.stream.firstWhere(
      (state) => state is ResendEmailSuccess,
    );
    verification.add(ResendEmailSubmittedEvent(email: account.email));
    await sent;

    expect(verification.state.canSubmit, isFalse);
    expect(verification.state.remaining, const Duration(seconds: 60));
    expect(fixture.requests.map((request) => request.url.path), [
      '/api/collections/users/records',
      '/api/collections/users/request-verification',
      '/api/collections/users/request-verification',
    ]);
    expect(
      fixture.requests.skip(1).map((request) => jsonDecode(request.body)),
      everyElement({'email': account.email}),
    );
    expect(fixture.client.authStore.token, isEmpty);
  });
}
