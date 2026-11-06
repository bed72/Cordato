import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/exceptions/password_reset_token_exception.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';

import '../../../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  const email = ' Person@Example.com ';
  const token = 'reset-token';
  const password = ' NewPass1 ';
  const confirmation = ' Confirm1 ';
  late PocketBaseFixture fixture;
  late AuthenticationRepository repository;

  setUp(() {
    fixture = PocketBaseFixture();
    repository = AuthenticationRepository(pocketBase: fixture.client);
    addTearDown(fixture.client.close);
  });

  for (final operation in [
    (
      name: 'request',
      body: <String, dynamic>{'email': email},
      execute: (AuthenticationRepository repository) =>
          repository.requestPasswordReset(email: email),
    ),
    (
      name: 'confirm',
      body: <String, dynamic>{
        'token': token,
        'password': password,
        'passwordConfirm': confirmation,
      },
      execute: (AuthenticationRepository repository) =>
          repository.confirmPasswordReset(
            token: token,
            password: password,
            passwordConfirm: confirmation,
          ),
    ),
  ]) {
    group('password reset ${operation.name}', () {
      test(
        'sends the unchanged native payload without creating a session',
        () async {
          await operation.execute(repository);

          final request = fixture.requests.single;
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/collections/users/${operation.name}-password-reset',
          );
          expect(request.url.query, isEmpty);
          expect(jsonDecode(request.body), operation.body);
          expect(request.headers['Authorization'], isNull);
          expect(fixture.client.authStore.token, isEmpty);
        },
      );

      test('waits for remote completion', () async {
        final response = Completer<http.Response>();
        final started = Completer<void>();
        fixture.respond = (_) {
          started.complete();
          return response.future;
        };
        var completed = false;

        final pending = operation
            .execute(repository)
            .then((_) => completed = true);
        await started.future;
        expect(completed, isFalse);
        response.complete(http.Response('', 204));
        await pending;
        expect(completed, isTrue);
      });

      for (final status in [400, 429, 500]) {
        test('preserves remote fields for HTTP $status', () async {
          fixture.respond = (_) => PocketBaseFixture.jsonResponse({
            'message': 'Remote validation',
            'data': {
              'password': {'code': 'validation_length', 'message': 'Invalid'},
              'passwordConfirm': {
                'code': 'validation_values_mismatch',
                'message': 'Mismatch',
              },
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
                    ['/password', '/passwordConfirm'],
                  )
                  .having(
                    (error) => error.errors.errors.first.status,
                    'status',
                    '$status',
                  ),
            ),
          );
        });
      }

      test('maps transport failure to application fallback', () async {
        fixture.respond = (_) => throw const SocketException('offline');

        await expectLater(
          operation.execute(repository),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test('propagates unexpected failures', () async {
        final failure = StateError('unexpected');
        fixture.respond = (_) => throw failure;

        await expectLater(
          operation.execute(repository),
          throwsA(same(failure)),
        );
      });
    });
  }

  test(
    'classifies HTTP 400 token errors without discarding their metadata',
    () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({
        'message': 'Remote validation',
        'data': {
          'token': {'code': 'validation_invalid_token', 'message': 'Invalid'},
        },
      }, status: 400);

      await expectLater(
        repository.confirmPasswordReset(
          token: token,
          password: password,
          passwordConfirm: confirmation,
        ),
        throwsA(
          isA<PasswordResetTokenException>()
              .having(
                (error) => error.errors.errors.single.pointer,
                'pointer',
                '/token',
              )
              .having(
                (error) => error.errors.errors.single.code,
                'code',
                'validation_invalid_token',
              ),
        ),
      );
    },
  );
}
