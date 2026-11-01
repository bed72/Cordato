import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_state.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));

  test('verification retry after creation never recreates the account or a session', () async {
    final client = HttpClientMock();
    final storage = StorageClientMock();
    final requests = <Requests>[];
    var verificationAttempts = 0;
    when(() => client.post(parameter: any(named: 'parameter')))
        .thenAnswer((invocation) async {
          final request = invocation.namedArguments[#parameter] as Requests;
          requests.add(request);
          if (request.path == 'collections/users/records') {
            return const Responses(status: 200, body: {});
          }
          if (++verificationAttempts == 1) throw HttpUnexpectedException();
          return const Responses(status: 204, body: {});
        });

    final boot = bootstrapModule(
      createModule(
        register: (context) {
          context
            ..addInstance<IHttpClient>(client)
            ..addInstance<IStorageClient>(storage)
            ..module(authenticationModule);
        },
      ),
    );
    addTearDown(boot.injector.dispose);
    final signUp = inject<SignUpBloc>();
    final verification = inject<ResendEmailBloc>();
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
    expect(requests.map((request) => request.path), [
      'collections/users/records',
    ]);

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
    expect(requests.map((request) => request.path), [
      'collections/users/records',
      'collections/users/request-verification',
      'collections/users/request-verification',
    ]);
    expect(
      requests.skip(1).map((request) => request.body),
      everyElement({'email': account.email}),
    );
    verifyZeroInteractions(storage);
  });
}
