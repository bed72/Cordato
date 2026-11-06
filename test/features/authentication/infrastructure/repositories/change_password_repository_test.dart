import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';

import '../../../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  late PocketBaseFixture fixture;
  late AuthenticationRepository repository;

  setUp(() {
    fixture = PocketBaseFixture();
    fixture.authenticate();
    fixture.respond = (_) => PocketBaseFixture.jsonResponse({'id': 'user-1'});
    repository = AuthenticationRepository(pocketBase: fixture.client);
    addTearDown(fixture.client.close);
  });

  Future<void> change() => repository.changePassword(
    oldPassword: ' old ',
    password: ' NewPass1 ',
    passwordConfirm: ' NewPass1 ',
  );

  test('uses the shared auth identity and only the native password fields without logout', () async {
    await change();

    final request = fixture.requests.single;
    expect(request.method, 'PATCH');
    expect(request.url.path, '/api/collections/users/records/user-1');
    expect(request.headers['Authorization'], PocketBaseFixture.token);
    expect(jsonDecode(request.body), {
      'password': ' NewPass1 ',
      'oldPassword': ' old ',
      'passwordConfirm': ' NewPass1 ',
    });
    expect(fixture.client.authStore.token, PocketBaseFixture.token);
  });

  test('rejects missing auth identity before sending a request', () async {
    fixture.client.authStore.clear();

    await expectLater(
      change(),
      throwsA(isA<MissingAuthenticatedUserException>()),
    );
    expect(fixture.requests, isEmpty);
  });

  for (final id in ['', '   ']) {
    test('rejects an empty auth record ID: ${id.length}', () async {
      fixture.authenticate(id: id);

      await expectLater(
        change(),
        throwsA(isA<MissingAuthenticatedUserException>()),
      );
      expect(fixture.requests, isEmpty);
    });
  }

  test('awaits remote confirmation', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    fixture.respond = (_) {
      started.complete();
      return response.future;
    };
    var completed = false;

    final pending = change().then((_) => completed = true);
    await started.future;
    expect(completed, isFalse);
    response.complete(PocketBaseFixture.jsonResponse({'id': 'user-1'}));
    await pending;
    expect(completed, isTrue);
  });

  test('preserves native field order and metadata', () async {
    fixture.respond = (_) => PocketBaseFixture.jsonResponse({
      'message': 'Remote validation',
      'data': {
        'oldPassword': {
          'code': 'validation_invalid_old_password',
          'message': 'Invalid',
        },
        'passwordConfirm': {
          'code': 'validation_values_mismatch',
          'message': 'Mismatch',
        },
      },
    }, status: 400);

    await expectLater(
      change(),
      throwsA(
        isA<AuthenticationException>()
            .having(
              (error) => error.errors.errors.map((field) => field.pointer),
              'pointers',
              ['/oldPassword', '/passwordConfirm'],
            )
            .having(
              (error) => error.errors.errors.first.code,
              'code',
              'validation_invalid_old_password',
            )
            .having(
              (error) => error.errors.errors.first.parameter,
              'parameter',
              'oldPassword',
            ),
      ),
    );
    expect(fixture.client.authStore.token, PocketBaseFixture.token);
  });

  for (final status in [401, 403]) {
    test('maps HTTP $status without managing the session', () async {
      fixture.respond = (_) =>
          PocketBaseFixture.jsonResponse({}, status: status);
      final record = fixture.client.authStore.record;

      await expectLater(
        change(),
        throwsA(
          isA<AuthenticationException>().having(
            (failure) => failure.errors.errors.single.status,
            'status',
            '$status',
          ),
        ),
      );

      expect(fixture.client.authStore.token, PocketBaseFixture.token);
      expect(fixture.client.authStore.record, same(record));
    });
  }

  test('reads the current auth identity for every password change without normalization', () async {
    await change();
    fixture.authenticate(id: ' new-user ');

    await change();

    expect(fixture.requests.last.url.pathSegments.last, ' new-user ');
  });

  test('a late 401 does not clear a newer login', () async {
    fixture.respond = (_) {
      fixture.authenticate(authToken: 'new-token', id: 'new-user');
      return PocketBaseFixture.jsonResponse({}, status: 401);
    };

    await expectLater(change(), throwsA(isA<AuthenticationException>()));
    expect(fixture.client.authStore.token, 'new-token');
    expect(fixture.client.authStore.record?.id, 'new-user');
  });

  test('maps transport failures without signing out', () async {
    fixture.respond = (_) => throw const SocketException('offline');

    await expectLater(change(), throwsA(isA<AuthenticationException>()));
    expect(fixture.client.authStore.token, PocketBaseFixture.token);
  });

  test('does not hide an unexpected failure', () async {
    final failure = StateError('unexpected');
    fixture.respond = (_) => throw failure;

    await expectLater(change(), throwsA(same(failure)));
  });
}
