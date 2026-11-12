import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/session/infrastructure/repositories/session_repository.dart';

import 'package:cordato/features/authentication/domain/enums/email_status_enum.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';

import '../../../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  const password = ' Secret1 ';
  const email = ' Person@Example.com ';

  late PocketBaseFixture fixture;
  late AuthenticationRepository repository;

  setUp(() {
    fixture = PocketBaseFixture();
    repository = AuthenticationRepository(pocketBase: fixture.client);
    addTearDown(fixture.client.close);
  });

  group('SDK operations', () {
    final operations =
        <
          ({
            String name,
            String path,
            Map<String, dynamic> body,
            Future<void> Function(AuthenticationRepository) execute,
          })
        >[
          (
            name: 'sign-in',
            path: 'auth-with-password',
            body: {'identity': email, 'password': password},
            execute: (repository) =>
                repository.signIn(email: email, password: password),
          ),
          (
            name: 'sign-up',
            path: 'records',
            body: {
              'email': email,
              'password': password,
              'passwordConfirm': password,
            },
            execute: (repository) =>
                repository.signUp(email: email, password: password),
          ),
          (
            body: {'email': email},
            name: 'verification request',
            path: 'request-verification',
            execute: (repository) => repository.resendEmail(email: email),
          ),
        ];

    for (final operation in operations) {
      group(operation.name, () {
        test('delegates the native payload unchanged', () async {
          fixture.respond = (_) => PocketBaseFixture.authResponse();

          await operation.execute(repository);

          final request = fixture.requests.single;
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), operation.body);
          expect(request.headers['Authorization'], isNull);
          expect(request.url.path, '/api/collections/users/${operation.path}');
        });

        test('awaits remote completion', () async {
          final response = Completer<http.Response>();
          final started = Completer<void>();
          fixture.respond = (_) {
            started.complete();
            return response.future;
          };
          bool completed = false;

          final pending = operation
              .execute(repository)
              .then((_) => completed = true);
          await started.future;
          expect(completed, isFalse);
          response.complete(PocketBaseFixture.authResponse());
          await pending;
          expect(completed, isTrue);
        });

        for (final status in [400, 403, 429, 500]) {
          test('preserves validation metadata for HTTP $status', () async {
            fixture.respond = (_) => PocketBaseFixture.jsonResponse({
              'message': 'Remote validation',
              'data': {
                'identity': {
                  'message': 'Required',
                  'code': 'validation_required',
                },
                'password': {'code': 'validation_length', 'message': 'Invalid'},
              },
            }, status: status);

            await expectLater(
              operation.execute(repository),
              throwsA(
                isA<AuthenticationException>()
                    .having(
                      (error) =>
                          error.errors.errors.map((field) => field.pointer),
                      'pointers',
                      ['/identity', '/password'],
                    )
                    .having(
                      (error) => error.errors.errors.first.code,
                      'code',
                      'validation_required',
                    )
                    .having(
                      (error) => error.errors.errors.first.parameter,
                      'parameter',
                      'identity',
                    )
                    .having(
                      (error) => error.errors.errors.first.status,
                      'status',
                      '$status',
                    ),
              ),
            );
            expect(fixture.client.authStore.token, isEmpty);
          });
        }

        test('maps transport failures to application fallback', () async {
          fixture.respond = (_) => throw const SocketException('offline');

          await expectLater(
            operation.execute(repository),
            throwsA(
              isA<AuthenticationException>().having(
                (error) => error.errors.errors.single.title,
                'fallback',
                'Erro desconhecido',
              ),
            ),
          );
        });

        test('does not hide unexpected failures wrapped by the SDK', () async {
          final failure = StateError('unexpected');
          fixture.respond = (_) => throw failure;

          await expectLater(
            operation.execute(repository),
            throwsA(same(failure)),
          );
        });
      });
    }
  });

  group('session ownership', () {
    test('sign-in updates the shared AuthStore', () async {
      fixture.respond = (_) => PocketBaseFixture.authResponse();

      await repository.signIn(email: email, password: password);

      expect(fixture.client.authStore.token, PocketBaseFixture.token);
      expect(fixture.client.authStore.record?.id, 'user-1');
    });

    test('sign-up does not create a session', () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({'id': 'user-1'});

      await repository.signUp(email: email, password: password);

      expect(fixture.client.authStore.token, isEmpty);
      expect(fixture.client.authStore.record, isNull);
    });

    test(
      'logout clears the shared AuthStore without an HTTP request',
      () async {
        fixture.authenticate();

        await repository.signOut();

        expect(fixture.client.authStore.token, isEmpty);
        expect(fixture.client.authStore.record, isNull);
        expect(fixture.requests, isEmpty);
      },
    );

    test('does not mask incompatible auth response parsing', () async {
      fixture.respond = (_) =>
          PocketBaseFixture.jsonResponse({'token': 1, 'record': []});

      await expectLater(
        repository.signIn(email: email, password: password),
        throwsA(isA<TypeError>()),
      );
      expect(fixture.client.authStore.token, isEmpty);
    });
  });

  group('local logout during refresh', () {
    test('a late refresh cannot restore the logged-out session', () async {
      fixture.authenticate();
      final response = Completer<http.Response>();
      final started = Completer<void>();
      fixture.respond = (_) {
        started.complete();
        return response.future;
      };
      final session = SessionRepository(pocketBase: fixture.client);

      final refresh = session.loadSession();
      await started.future;
      await repository.signOut();
      response.complete(PocketBaseFixture.authResponse());

      expect(await refresh, isFalse);
      expect(fixture.requests, hasLength(1));
      expect(fixture.client.authStore.token, isEmpty);
      expect(
        fixture.requests.single.url.path,
        '/api/collections/users/auth-refresh',
      );
    });
  });

  group('email confirmation', () {
    test(
      'does not hide unexpected confirmation failures wrapped by the SDK',
      () async {
        final failure = StateError('unexpected');
        fixture.respond = (_) => throw failure;

        await expectLater(
          repository.confirmEmail('verification-token'),
          throwsA(same(failure)),
        );
      },
    );

    test('rejects an empty token without making a request', () async {
      expect(
        await repository.confirmEmail(''),
        EmailVerificationStatusEnum.invalid,
      );
      expect(fixture.requests, isEmpty);
    });

    test('confirms through the SDK with token only in the body', () async {
      expect(
        await repository.confirmEmail('verification-token'),
        EmailVerificationStatusEnum.success,
      );

      final request = fixture.requests.single;
      expect(request.url.path, '/api/collections/users/confirm-verification');
      expect(request.url.query, isEmpty);
      expect(jsonDecode(request.body), {'token': 'verification-token'});
    });

    for (final scenario in [
      (status: 400, expected: EmailVerificationStatusEnum.invalid),
      (status: 403, expected: EmailVerificationStatusEnum.failure),
      (status: 500, expected: EmailVerificationStatusEnum.failure),
    ]) {
      test('maps confirmation HTTP ${scenario.status}', () async {
        fixture.respond = (_) =>
            PocketBaseFixture.jsonResponse({}, status: scenario.status);

        expect(
          await repository.confirmEmail('verification-token'),
          scenario.expected,
        );
      });
    }

    test('maps a transport error to confirmation failure', () async {
      fixture.respond = (_) => throw const SocketException('offline');

      expect(
        await repository.confirmEmail('verification-token'),
        EmailVerificationStatusEnum.failure,
      );
    });
  });
}
