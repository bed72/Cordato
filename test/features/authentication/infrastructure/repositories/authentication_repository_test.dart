import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';

import '../../../../support/core/mocks/http_client_mock.dart';
import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  const password = ' secret ';
  const email = ' Person@Example.com ';
  const signed = 'fixture.verification.token';

  const signInBody = <String, dynamic>{
    'token': 'fixture-token',
    'record': {'id': 'user-1', 'verified': false},
  };

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

    when(() => storage.clear()).thenAnswer((_) async {});
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
  });

  group('Sign-in and session persistence', () {
    test(
      'sign-in sends credentials unchanged and persists token and record id',
      () async {
        when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => const Responses(status: 200, body: signInBody),
        );

        await repository.signIn(email: email, password: password);

        final request =
            verify(() => client.post(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;

        expect(request.query, isNull);
        expect(request.headers, isNull);
        expect(request.path, 'collections/users/auth-with-password');
        expect(request.body, {'identity': email, 'password': password});

        verify(
          () => storage.write(
            value: 'fixture-token',
            key: StorageKeyEnum.token.key,
          ),
        ).called(1);
        verify(
          () => storage.write(key: StorageKeyEnum.userId.key, value: 'user-1'),
        ).called(1);
        verifyNoMoreInteractions(storage);
      },
    );

    test('sign-in waits for both storage writes before completing', () async {
      bool completed = false;
      final idSaved = Completer<void>();
      final savingId = Completer<void>();
      final tokenSaved = Completer<void>();
      final savingToken = Completer<void>();

      when(
        () => client.post(parameter: any(named: 'parameter')),
      ).thenAnswer((_) async => const Responses(status: 200, body: signInBody));
      when(
        () => storage.write(
          value: any(named: 'value'),
          key: StorageKeyEnum.token.key,
        ),
      ).thenAnswer((_) {
        savingToken.complete();
        return tokenSaved.future;
      });
      when(
        () => storage.write(
          value: any(named: 'value'),
          key: StorageKeyEnum.userId.key,
        ),
      ).thenAnswer((_) {
        savingId.complete();
        return idSaved.future;
      });

      final pending = repository.signIn(email: email, password: password)
        ..then((_) => completed = true);

      await Future.wait([savingToken.future, savingId.future]);

      expect(completed, isFalse);

      tokenSaved.complete();

      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);

      idSaved.complete();
      await pending;

      expect(completed, isTrue);
    });

    test('sign-in exposes PocketBase validation errors without persisting a session', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => throw HttpResponseException.fromResponse(
          const Responses(
            status: 400,
            body: {
              'status': 400,
              'message': 'Failed to authenticate.',
              'data': {
                'identity': {
                  'code': 'validation_required',
                  'message': 'Missing required value.',
                },
              },
            },
          ),
        ),
      );

      await expectLater(
        repository.signIn(email: email, password: password),
        throwsA(
          isA<AuthenticationException>()
              .having(
                (error) => error.errors.errors.single.code,
                'code',
                'validation_required',
              )
              .having(
                (error) => error.errors.errors.single.pointer,
                'pointer',
                '/identity',
              )
              .having(
                (error) => error.errors.errors.single.status,
                'status',
                '400',
              )
              .having(
                (error) => error.errors.errors.single.detail,
                'detail',
                'Missing required value.',
              ),
        ),
      );
      verifyZeroInteractions(storage);
    });

    for (final key in [StorageKeyEnum.token, StorageKeyEnum.userId]) {
      test('sign-in propagates a failure writing ${key.name}', () async {
        final failure = StateError('storage unavailable');

        when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => const Responses(status: 200, body: signInBody),
        );
        when(
          () => storage.write(
            key: key.key,
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async => throw failure);

        await expectLater(
          repository.signIn(email: email, password: password),
          throwsA(same(failure)),
        );

        verifyNever(() => storage.clear());
      });
    }

    test(
      'sign-in propagates invalid response types before writing storage',
      () async {
        for (final body in <Map<String, dynamic>>[
          {},
          {'record': []},
          {'token': 'token'},
          {
            'token': 1,
            'record': {'id': 'user'},
          },
        ]) {
          when(() => client.post(parameter: any(named: 'parameter')))
              .thenAnswer((_) async => Responses(status: 200, body: body));

          await expectLater(
            repository.signIn(email: email, password: password),
            throwsA(isA<TypeError>()),
          );
        }

        verifyZeroInteractions(storage);
      },
    );

    test(
      'sign-in ignores expiration metadata not present in its contract',
      () async {
        when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => const Responses(
            status: 200,
            body: {
              'token': 'token',
              'record': {'id': 'user', 'created': 'invalid'},
            },
          ),
        );

        await repository.signIn(email: email, password: password);

        verify(
          () => storage.write(key: StorageKeyEnum.token.key, value: 'token'),
        ).called(1);
        verify(
          () => storage.write(key: StorageKeyEnum.userId.key, value: 'user'),
        ).called(1);
      },
    );
  });

  group('Sign-up', () {
    test('sign-up sends credentials without optional profile fields or session persistence', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'id': 'fixture-user',
            'collectionName': 'users',
            'email': email,
            'verified': false,
          },
        ),
      );

      await repository.signUp(email: email, password: password);

      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, isNull);
      expect(request.headers, isNull);
      expect(request.path, 'collections/users/records');
      expect(request.body, {
        'email': email,
        'password': password,
        'passwordConfirm': password,
      });
      verifyZeroInteractions(storage);
    });

    test(
      'sign-up does not complete before the HTTP request completes',
      () async {
        bool completed = false;
        final response = Completer<Responses>();

        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) => response.future);

        final pending = repository.signUp(email: email, password: password)
          ..then((_) => completed = true);

        await Future<void>.delayed(Duration.zero);

        final completedBeforeResponse = completed;

        response.complete(
          const Responses(status: 200, body: {'id': 'fixture-user'}),
        );

        await pending;

        expect(completedBeforeResponse, isFalse);
        verifyZeroInteractions(storage);
      },
    );

    test(
      'sign-up translates a failure received after the request starts',
      () async {
        final response = Completer<Responses>();
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) => response.future);

        final pending = repository.signUp(email: email, password: password);
        final expectation = expectLater(
          pending,
          throwsA(
            isA<AuthenticationException>().having(
              (error) => error.errors.errors.single.detail,
              'detail',
              'E-mail já cadastrado.',
            ),
          ),
        );

        await Future<void>.delayed(Duration.zero);
        response.completeError(
          HttpResponseException(
            status: 422,
            errors: const ErrorsResponse(
              errors: [ErrorResponse(detail: 'E-mail já cadastrado.')],
            ),
          ),
        );

        await expectation;
        verifyZeroInteractions(storage);
      },
    );
  });

  group('Verification requests', () {
    test(
      'resend sends the email unchanged and accepts an empty 204 response',
      () async {
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => const Responses(status: 204, body: {}));

        await repository.resendEmail(email: email);

        final request =
            verify(() => client.post(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;

        expect(request.query, isNull);
        expect(request.headers, isNull);
        expect(request.path, 'collections/users/request-verification');
        expect(request.body, {'email': email});
        verifyZeroInteractions(storage);
      },
    );

    test('resend waits for the HTTP request to complete', () async {
      bool completed = false;
      final response = Completer<Responses>();

      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) => response.future);

      final pending = repository.resendEmail(email: email)
        ..then((_) => completed = true);

      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);

      response.complete(const Responses(status: 204, body: {}));

      await pending;

      expect(completed, isTrue);
      verifyZeroInteractions(storage);
    });

    for (final operation in ['signUp', 'resendEmail']) {
      test(
        '$operation preserves PocketBase 400 errors without changing storage',
        () async {
          when(() => client.post(parameter: any(named: 'parameter')))
              .thenAnswer(
                (_) async => throw HttpResponseException.fromResponse(
                  const Responses(
                    status: 400,
                    body: {
                      'status': 400,
                      'message': 'Failed to create record.',
                      'data': {
                        'email': {
                          'code': 'validation_required',
                          'message': 'Missing required value.',
                        },
                      },
                    },
                  ),
                ),
              );
          final pending = operation == 'signUp'
              ? repository.signUp(email: email, password: password)
              : repository.resendEmail(email: email);
          await expectLater(
            pending,
            throwsA(
              isA<AuthenticationException>()
                  .having(
                    (error) => error.errors.errors.single.code,
                    'code',
                    'validation_required',
                  )
                  .having(
                    (error) => error.errors.errors.single.status,
                    'status',
                    '400',
                  )
                  .having(
                    (error) => error.errors.errors.single.pointer,
                    'pointer',
                    '/email',
                  )
                  .having(
                    (error) => error.errors.errors.single.parameter,
                    'parameter',
                    'email',
                  )
                  .having(
                    (error) => error.errors.errors.single.detail,
                    'detail',
                    'Missing required value.',
                  ),
            ),
          );
          verifyZeroInteractions(storage);
        },
      );
    }
  });

  group('Local sign-out', () {
    test('sign-out clears local storage without any HTTP request', () async {
      await repository.signOut();
      verify(() => storage.clear()).called(1);
      verifyZeroInteractions(client);
      verifyNoMoreInteractions(storage);
    });

    test('sign-out waits for storage clearing before completing', () async {
      bool completed = false;
      final cleared = Completer<void>();
      final clearing = Completer<void>();

      when(() => storage.clear()).thenAnswer((_) {
        clearing.complete();
        return cleared.future;
      });

      final pending = repository.signOut()..then((_) => completed = true);

      await clearing.future;

      expect(completed, isFalse);
      cleared.complete();

      await pending;
      expect(completed, isTrue);
      verifyZeroInteractions(client);
    });

    test('sign-out propagates a storage clearing failure without confirming success', () async {
      final failure = StateError('storage unavailable');

      when(() => storage.clear()).thenAnswer((_) async => throw failure);

      await expectLater(repository.signOut(), throwsA(same(failure)));
      verifyZeroInteractions(client);
    });
  });

  group('Shared HTTP failure handling', () {
    for (final operation in ['signIn', 'signUp', 'resendEmail']) {
      Future<void> execute() async {
        await switch (operation) {
          'signIn' => repository.signIn(email: email, password: password),
          'signUp' => repository.signUp(email: email, password: password),
          _ => repository.resendEmail(email: email),
        };
      }

      Future<Responses> request() =>
          client.post(parameter: any(named: 'parameter'));

      test(
        '$operation preserves every backend error and its metadata',
        () async {
          const errors = ErrorsResponse(
            errors: [
              ErrorResponse(
                status: '422',
                title: 'Validação',
                parameter: 'email',
                detail: 'Entrada inválida',
                pointer: '/data/attributes/email',
              ),
              ErrorResponse(detail: 'Outra falha'),
            ],
          );

          when(request).thenAnswer(
            (_) async =>
                throw HttpResponseException(status: 422, errors: errors),
          );

          await expectLater(
            execute(),
            throwsA(
              isA<AuthenticationException>()
                  .having((error) => error.errors.errors.length, 'length', 2)
                  .having(
                    (error) => error.errors.errors.first.status,
                    'status',
                    '422',
                  )
                  .having(
                    (error) => error.errors.errors.first.title,
                    'title',
                    'Validação',
                  )
                  .having(
                    (error) => error.errors.errors.first.detail,
                    'detail',
                    'Entrada inválida',
                  )
                  .having(
                    (error) => error.errors.errors.first.pointer,
                    'pointer',
                    '/data/attributes/email',
                  )
                  .having(
                    (error) => error.errors.errors.first.parameter,
                    'parameter',
                    'email',
                  )
                  .having(
                    (error) => error.errors.errors.last.detail,
                    'last detail',
                    'Outra falha',
                  )
                  .having(
                    (error) => error.errors.errors.last.pointer,
                    'last pointer',
                    isNull,
                  ),
            ),
          );
          verifyZeroInteractions(storage);
        },
      );

      test('$operation provides a fallback for empty backend errors', () async {
        when(request).thenAnswer(
          (_) async => throw HttpResponseException(
            status: 422,
            errors: const ErrorsResponse(errors: []),
          ),
        );

        await expectLater(
          execute(),
          throwsA(
            isA<AuthenticationException>().having(
              (error) => error.errors.errors.single.title,
              'title',
              'Erro desconhecido',
            ),
          ),
        );
        verifyZeroInteractions(storage);
      });

      for (final kind in HttpExceptionEnum.values) {
        test(
          '$operation translates transport ${kind.name} without touching storage',
          () async {
            when(request).thenAnswer(
              (_) async => throw HttpTransportException(failure: kind),
            );
            await expectLater(
              execute(),
              throwsA(
                isA<AuthenticationException>().having(
                  (error) => error.errors.errors.single.detail,
                  'detail',
                  'Não foi possível processar a resposta.',
                ),
              ),
            );
            verifyZeroInteractions(storage);
          },
        );
      }

      test(
        '$operation translates invalid responses and unexpected client exceptions',
        () async {
          for (final failure in <HttpClientException>[
            HttpInvalidResponseException(status: 200),
            HttpUnexpectedException(),
          ]) {
            when(request).thenAnswer((_) async => throw failure);
            await expectLater(
              execute(),
              throwsA(isA<AuthenticationException>()),
            );
          }

          verifyZeroInteractions(storage);
        },
      );

      test(
        '$operation propagates unexpected programming errors unchanged',
        () async {
          final failure = StateError('unexpected');

          when(request).thenAnswer((_) async => throw failure);

          await expectLater(execute(), throwsA(same(failure)));
          verifyZeroInteractions(storage);
        },
      );
    }
  });

  group('Email confirmation', () {
    test(
      'confirmation rejects an empty token without HTTP or storage calls',
      () async {
        expect(
          await repository.confirmEmail(''),
          EmailVerificationStatusEnum.invalid,
        );

        verifyZeroInteractions(client);
        verifyZeroInteractions(storage);
      },
    );

    test(
      'confirmation posts the unchanged token to the fixed PocketBase endpoint',
      () async {
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => const Responses(status: 204, body: {}));

        expect(
          await repository.confirmEmail(signed),
          EmailVerificationStatusEnum.success,
        );

        final request =
            verify(() => client.post(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;

        expect(request.path, 'collections/users/confirm-verification');
        expect(request.body, {'token': signed});
        expect(request.query, isNull);
        expect(request.headers, isNull);
        verifyZeroInteractions(storage);
      },
    );

    test('confirmation maps 204 to success and unexpected successful statuses to failure', () async {
      for (final code in [200, 202, 204]) {
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => Responses(status: code, body: {}));

        expect(
          await repository.confirmEmail(signed),
          code == 204
              ? EmailVerificationStatusEnum.success
              : EmailVerificationStatusEnum.failure,
        );
      }
      verifyZeroInteractions(storage);
    });

    test('confirmation maps PocketBase 400 to invalid and other HTTP errors to failure', () async {
      for (final code in [400, 401, 403, 429, 500]) {
        when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async =>
              throw HttpResponseException(status: code, errors: .unknown()),
        );

        expect(
          await repository.confirmEmail(signed),
          code == 400
              ? EmailVerificationStatusEnum.invalid
              : EmailVerificationStatusEnum.failure,
        );
      }
      verifyZeroInteractions(storage);
    });

    test('confirmation translates typed client failures without creating a session', () async {
      for (final failure in <HttpClientException>[
        for (final kind in HttpExceptionEnum.values)
          HttpTransportException(failure: kind),
        HttpInvalidResponseException(status: 200),
        HttpUnexpectedException(),
      ]) {
        when(() => client.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => throw failure);

        expect(
          await repository.confirmEmail(signed),
          EmailVerificationStatusEnum.failure,
        );
      }
      verifyZeroInteractions(storage);
    });

    test('confirmation handles native invalid token response without persisting or fetching URLs', () async {
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => throw HttpResponseException.fromResponse(
          const Responses(
            status: 400,
            body: {
              'status': 400,
              'message': 'Failed to confirm verification.',
              'data': {
                'token': {
                  'code': 'validation_invalid_token',
                  'message': 'Invalid or expired token.',
                },
              },
            },
          ),
        ),
      );
      const input = 'https://untrusted.example/verification';
      expect(
        await repository.confirmEmail(input),
        EmailVerificationStatusEnum.invalid,
      );
      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'collections/users/confirm-verification');
      expect(request.body, {'token': input});
      verifyNoMoreInteractions(client);
      verifyZeroInteractions(storage);
    });

    test('confirmation propagates unexpected programming errors', () async {
      final failure = StateError('unexpected');

      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => throw failure);

      await expectLater(
        repository.confirmEmail(signed),
        throwsA(same(failure)),
      );
      verifyZeroInteractions(storage);
    });
  });
}
