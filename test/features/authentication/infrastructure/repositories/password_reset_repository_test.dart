import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/exceptions/password_reset_token_exception.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';

import '../../../../support/core/mocks/http_client_mock.dart';
import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  const token = 'fixture.reset.token';
  const password = ' NewPass1 ';
  const confirmation = ' OtherPass2 ';
  const email = ' Person@Example.com ';
  late HttpClientMock client;
  late StorageClientMock storage;
  late AuthenticationRepository repository;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    storage = StorageClientMock();
    repository = AuthenticationRepository(
      httpClient: client,
      storageClient: storage,
    );
  });

  for (final operation in ['request', 'confirm']) {
    group('Password reset $operation', () {
      Future<void> execute() => operation == 'request'
          ? repository.requestPasswordReset(email: email)
          : repository.confirmPasswordReset(
              token: token,
              password: password,
              passwordConfirm: confirmation,
            );

      test(
        'sends the native JSON payload unchanged without touching storage',
        () async {
          when(() => client.post(parameter: any(named: 'parameter')))
              .thenAnswer((_) async => const Responses(status: 204, body: {}));

          await execute();

          final request =
              verify(
                    () =>
                        client.post(parameter: captureAny(named: 'parameter')),
                  ).captured.single
                  as Requests;
          expect(request.path, 'collections/users/$operation-password-reset');
          expect(
            request.body,
            operation == 'request'
                ? {'email': email}
                : {
                    'token': token,
                    'password': password,
                    'passwordConfirm': confirmation,
                  },
          );
          expect(request.query, isNull);
          expect(request.headers, isNull);
          verifyNoMoreInteractions(client);
          verifyZeroInteractions(storage);
        },
      );

      test('waits for HTTP completion', () async {
        final pending = Completer<Responses>();
        final started = Completer<void>();
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) {
              started.complete();
              return pending.future;
            });
        var completed = false;
        final pendingOperation = execute().then((_) => completed = true);
        await started.future;
        expect(completed, isFalse);
        pending.complete(const Responses(status: 204, body: {}));
        await pendingOperation;
        expect(completed, isTrue);
        verifyZeroInteractions(storage);
      });

      for (final status in [200, 202]) {
        test('rejects unexpected success status $status', () async {
          when(() => client.post(parameter: any(named: 'parameter')))
              .thenAnswer((_) async => Responses(status: status, body: {}));
          await expectLater(execute(), throwsA(isA<AuthenticationException>()));
          verifyZeroInteractions(storage);
        });
      }

      for (final status in [400, 429, 500]) {
        test(
          'preserves ordered remote errors and metadata for $status',
          () async {
            final failure = HttpResponseException.fromResponse(
              Responses(
                status: status,
                body: {
                  'status': status,
                  'message': 'Cannot continue.',
                  'data': {
                    'password': {
                      'code': 'validation_length',
                      'message': 'Invalid password.',
                    },
                    'passwordConfirm': {
                      'code': 'validation_values_mismatch',
                      'message': 'Does not match.',
                    },
                  },
                },
              ),
            );
            when(() => client.post(parameter: any(named: 'parameter')))
                .thenThrow(failure);

            await expectLater(
              execute(),
              throwsA(
                isA<AuthenticationException>().having(
                  (error) => error.errors.errors
                      .map(
                        (item) => (
                          item.pointer,
                          item.code,
                          item.parameter,
                          item.detail,
                        ),
                      )
                      .toList(),
                  'ordered errors',
                  failure.errors
                      .toEntity()
                      .errors
                      .map(
                        (item) => (
                          item.pointer,
                          item.code,
                          item.parameter,
                          item.detail,
                        ),
                      )
                      .toList(),
                ),
              ),
            );
            verifyZeroInteractions(storage);
          },
        );
      }

      test('maps transport failures to an application fallback', () async {
        when(() => client.post(parameter: any(named: 'parameter'))).thenThrow(
          HttpTransportException(failure: HttpExceptionEnum.connection),
        );
        await expectLater(execute(), throwsA(isA<AuthenticationException>()));
        verifyZeroInteractions(storage);
      });

      test('propagates unexpected failures unchanged', () async {
        final failure = StateError('fixture failure');
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenThrow(failure);
        await expectLater(execute(), throwsA(same(failure)));
        verifyZeroInteractions(storage);
      });
    });
  }

  group('Invalid password reset token', () {
    test(
      'distinguishes a PocketBase token error from password validation',
      () async {
        final failure = HttpResponseException.fromResponse(
          const Responses(
            status: 400,
            body: {
              'message': 'Invalid request.',
              'data': {
                'token': {
                  'code': 'validation_invalid_token',
                  'message': 'Invalid or expired token.',
                },
              },
            },
          ),
        );
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenThrow(failure);

        await expectLater(
          repository.confirmPasswordReset(
            token: token,
            password: password,
            passwordConfirm: confirmation,
          ),
          throwsA(
            isA<PasswordResetTokenException>().having(
              (error) => error.errors.errors.single.pointer,
              'pointer',
              '/token',
            ),
          ),
        );
        verifyZeroInteractions(storage);
      },
    );
  });
}
