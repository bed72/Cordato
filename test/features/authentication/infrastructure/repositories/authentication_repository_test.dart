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
  const signed =
      'https://other.example/api/email-verification/12/abc?signature=123&expires=456';

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

  test(
    'sign-in sends credentials unchanged and persists token and record id',
    () async {
      when(
        () => client.post(parameter: any(named: 'parameter')),
      ).thenAnswer((_) async => const Responses(status: 200, body: signInBody));

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
          key: StorageKeyEnum.opaqueToken.key,
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
        key: StorageKeyEnum.opaqueToken.key,
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

  test(
    'sign-in exposes PocketBase validation errors without persisting a session',
    () async {
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
    },
  );

  for (final key in [StorageKeyEnum.opaqueToken, StorageKeyEnum.userId]) {
    test('sign-in propagates a failure writing ${key.name}', () async {
      final failure = StateError('storage unavailable');

      when(
        () => client.post(parameter: any(named: 'parameter')),
      ).thenAnswer((_) async => const Responses(status: 200, body: signInBody));
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
        () =>
            storage.write(key: StorageKeyEnum.opaqueToken.key, value: 'token'),
      ).called(1);
      verify(() => storage.write(key: StorageKeyEnum.userId.key, value: 'user'))
          .called(1);
    },
  );

  test(
    'sign-up sends the default name without avatar or session persistence',
    () async {
      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => const Responses(status: 201, body: {}));

      await repository.signUp(email: email, password: password);

      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, isNull);
      expect(request.headers, isNull);
      expect(request.path, 'authentication/sign-up');
      expect(request.body, {
        'data': {
          'type': 'sign-ups',
          'attributes': {
            'email': email,
            'name': 'Trocado',
            'password': password,
            'password_confirmation': password,
          },
        },
      });
      verifyZeroInteractions(storage);
    },
  );

  test('sign-up does not complete before the HTTP request completes', () async {
    bool completed = false;
    final response = Completer<Responses>();

    when(() => client.post(parameter: any(named: 'parameter')))
        .thenAnswer((_) => response.future);

    final pending = repository.signUp(email: email, password: password)
      ..then((_) => completed = true);

    await Future<void>.delayed(Duration.zero);

    final completedBeforeResponse = completed;

    response.complete(const Responses(status: 201, body: {}));

    await pending;

    expect(completedBeforeResponse, isFalse);
    verifyZeroInteractions(storage);
  });

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

  test(
    'resend sends the email unchanged and accepts an empty 202 response',
    () async {
      when(() => client.post(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => const Responses(status: 202, body: {}));

      await repository.resendEmail(email: email);

      final request =
          verify(() => client.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.query, isNull);
      expect(request.headers, isNull);
      expect(request.path, 'authentication/email-verification/resend');
      expect(request.body, {
        'data': {
          'type': 'email-verifications',
          'attributes': {'email': email},
        },
      });
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

    response.complete(const Responses(status: 202, body: {}));

    await pending;

    expect(completed, isTrue);
    verifyZeroInteractions(storage);
  });

  test('logout revokes remotely before clearing all storage', () async {
    when(() => client.delete(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 204, body: {}));

    await repository.logout();

    final calls = verifyInOrder([
      () => client.delete(parameter: captureAny(named: 'parameter')),
      () => storage.clear(),
    ]);

    final request = calls.first.captured.single as Requests;

    expect(request.body, isNull);
    expect(request.headers, isNull);
    expect(request.path, 'authentication/sign-out');
    verifyNoMoreInteractions(storage);
  });

  test('logout waits for revocation before clearing storage', () async {
    final revoked = Completer<Responses>();

    when(() => client.delete(parameter: any(named: 'parameter')))
        .thenAnswer((_) => revoked.future);

    final pending = repository.logout();

    verifyZeroInteractions(storage);

    revoked.complete(const Responses(status: 204, body: {}));

    await pending;

    verify(() => storage.clear()).called(1);
  });

  test('logout waits for storage clearing before completing', () async {
    bool completed = false;
    final cleared = Completer<void>();
    final clearing = Completer<void>();

    when(() => client.delete(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 204, body: {}));
    when(() => storage.clear()).thenAnswer((_) {
      clearing.complete();
      return cleared.future;
    });

    final pending = repository.logout()..then((_) => completed = true);

    await clearing.future;

    expect(completed, isFalse);
    cleared.complete();

    await pending;
    expect(completed, isTrue);
  });

  test(
    'logout propagates a storage clearing failure without confirming success',
    () async {
      final failure = StateError('storage unavailable');

      when(() => client.delete(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => const Responses(status: 204, body: {}));
      when(() => storage.clear()).thenAnswer((_) async => throw failure);

      await expectLater(repository.logout(), throwsA(same(failure)));
    },
  );

  for (final operation in ['signIn', 'signUp', 'resendEmail', 'logout']) {
    Future<void> execute() async {
      await switch (operation) {
        'signIn' => repository.signIn(email: email, password: password),
        'signUp' => repository.signUp(email: email, password: password),
        'resendEmail' => repository.resendEmail(email: email),
        _ => repository.logout(),
      };
    }

    Future<Responses> request() => operation == 'logout'
        ? client.delete(parameter: any(named: 'parameter'))
        : client.post(parameter: any(named: 'parameter'));

    test('$operation preserves every backend error and its metadata', () async {
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
        (_) async => throw HttpResponseException(status: 422, errors: errors),
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
    });

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
          await expectLater(execute(), throwsA(isA<AuthenticationException>()));
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

  test(
    'confirmation rejects an empty URL without HTTP or storage calls',
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
    'confirmation forwards the complete signed URL without custom headers',
    () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => const Responses(status: 204, body: {}));

      expect(
        await repository.confirmEmail(signed),
        EmailVerificationStatusEnum.success,
      );

      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;

      expect(request.path, signed);
      expect(request.body, isNull);
      expect(request.query, isNull);
      expect(request.headers, isNull);
      verifyZeroInteractions(storage);
    },
  );

  test('confirmation maps 204 to success and unexpected successful statuses to failure', () async {
    for (final code in [200, 202, 204]) {
      when(() => client.get(parameter: any(named: 'parameter')))
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

  test(
    'confirmation maps 403 to invalid and other HTTP errors to failure',
    () async {
      for (final code in [403, 422, 500]) {
        when(() => client.get(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async =>
              throw HttpResponseException(status: code, errors: .unknown()),
        );

        expect(
          await repository.confirmEmail(signed),
          code == 403
              ? EmailVerificationStatusEnum.invalid
              : EmailVerificationStatusEnum.failure,
        );
      }
      verifyZeroInteractions(storage);
    },
  );

  test(
    'confirmation translates typed client failures without creating a session',
    () async {
      for (final failure in <HttpClientException>[
        for (final kind in HttpExceptionEnum.values)
          HttpTransportException(failure: kind),
        HttpInvalidResponseException(status: 200),
        HttpUnexpectedException(),
      ]) {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => throw failure);

        expect(
          await repository.confirmEmail(signed),
          EmailVerificationStatusEnum.failure,
        );
      }
      verifyZeroInteractions(storage);
    },
  );

  test('confirmation propagates unexpected programming errors', () async {
    final failure = StateError('unexpected');

    when(() => client.get(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => throw failure);

    await expectLater(repository.confirmEmail(signed), throwsA(same(failure)));
    verifyZeroInteractions(storage);
  });
}
