import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/infrastructure/repositories/session_repository.dart';

import '../../../../support/core/mocks/auth_store_mock.dart';
import '../../../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  late PocketBaseFixture fixture;
  late SessionRepository repository;

  setUp(() {
    fixture = PocketBaseFixture();
    repository = SessionRepository(pocketBase: fixture.client);
    addTearDown(fixture.client.close);
  });

  group('initial load', () {
    test('does not request refresh without a token', () async {
      expect(await repository.loadSession(), isFalse);
      expect(fixture.requests, isEmpty);
    });

    test('receives the restored session before the first load', () async {
      fixture.authenticate();
      final restoredRepository = SessionRepository(pocketBase: fixture.client);
      fixture.respond = (_) =>
          PocketBaseFixture.authResponse(authToken: 'refreshed-token');

      expect(fixture.requests, isEmpty);
      expect(fixture.client.authStore.token, isNotEmpty);

      expect(await restoredRepository.loadSession(), isTrue);
      expect(fixture.client.authStore.token, 'refreshed-token');
    });

    test(
      'publishes the SDK auth change once and permits another explicit refresh',
      () async {
        fixture.authenticate();
        fixture.respond = (_) => PocketBaseFixture.authResponse();
        final changes = <bool>[];
        final firstChange = Completer<void>();
        final subscription = repository.sessionChanges.listen((hasSession) {
          changes.add(hasSession);
          if (!firstChange.isCompleted) {
            firstChange.complete();
          }
        });
        addTearDown(subscription.cancel);

        expect(await repository.loadSession(), isTrue);
        await firstChange.future;

        expect(changes, [true]);
        expect(fixture.requests, hasLength(2));
        expect(await repository.loadSession(), isTrue);
      },
    );

    test(
      'uses native auth-refresh and commits the returned auth data',
      () async {
        fixture.authenticate();
        fixture.respond = (_) => PocketBaseFixture.authResponse(
          id: 'refreshed-user',
          authToken: 'refreshed-token',
        );

        expect(await repository.loadSession(), isTrue);

        final request = fixture.requests.single;
        expect(request.body, isEmpty);
        expect(request.method, 'POST');
        expect(request.headers['Accept-Language'], 'pt-BR');
        expect(fixture.client.authStore.token, 'refreshed-token');
        expect(fixture.client.authStore.record?.id, 'refreshed-user');
        expect(request.url.path, '/api/collections/users/auth-refresh');
        expect(request.headers['Authorization'], PocketBaseFixture.token);
      },
    );

    test(
      'shares concurrent requests and does not publish until refresh completes',
      () async {
        fixture.authenticate();
        final started = Completer<void>();
        final response = Completer<http.Response>();
        fixture.respond = (_) {
          started.complete();
          return response.future;
        };

        final first = repository.loadSession();
        final second = repository.loadSession();

        await started.future;
        expect(second, same(first));
        expect(fixture.requests, hasLength(1));
        expect(fixture.client.authStore.token, PocketBaseFixture.token);

        response.complete(
          PocketBaseFixture.authResponse(authToken: 'refreshed-token'),
        );
        expect(await first, isTrue);
        expect(await second, isTrue);
        expect(fixture.client.authStore.token, 'refreshed-token');
      },
    );
  });

  group('refresh session isolation', () {
    for (final replacement in [
      'logout',
      'new-login',
      'same-token-new-record',
    ]) {
      Future<(Future<bool>, Completer<http.Response>)>
      startRefreshAfterReplacement() async {
        fixture.authenticate();
        final response = Completer<http.Response>();
        final started = Completer<void>();
        fixture.respond = (_) {
          started.complete();
          return response.future;
        };

        final pending = repository.loadSession();
        await started.future;
        switch (replacement) {
          case 'logout':
            fixture.client.authStore.clear();
          case 'new-login':
            fixture.authenticate(authToken: 'new-login-token', id: 'new-user');
          case 'same-token-new-record':
            fixture.authenticate(id: 'new-user');
        }
        return (pending, response);
      }

      test('discards a late refresh after $replacement', () async {
        final (pending, response) = await startRefreshAfterReplacement();
        final currentToken = fixture.client.authStore.token;
        final hasSession = currentToken.isNotEmpty;
        final currentRecord = fixture.client.authStore.record;

        response.complete(
          PocketBaseFixture.authResponse(
            id: 'obsolete-user',
            authToken: 'obsolete-token',
          ),
        );

        expect(await pending, hasSession);
        expect(fixture.client.authStore.token, currentToken);
        expect(fixture.client.authStore.record, same(currentRecord));
      });

      test(
        'a late 401 preserves the current AuthStore after $replacement',
        () async {
          final (pending, response) = await startRefreshAfterReplacement();
          final currentToken = fixture.client.authStore.token;
          final currentRecord = fixture.client.authStore.record;

          response.complete(PocketBaseFixture.jsonResponse({}, status: 401));

          expect(await pending, currentToken.isNotEmpty);
          expect(fixture.client.authStore.token, currentToken);
          expect(fixture.client.authStore.record, same(currentRecord));
        },
      );

      for (final status in [403, 500]) {
        test('ignores stale HTTP $status after $replacement', () async {
          final (pending, response) = await startRefreshAfterReplacement();
          final currentToken = fixture.client.authStore.token;
          final currentRecord = fixture.client.authStore.record;
          response.complete(PocketBaseFixture.jsonResponse({}, status: status));

          expect(await pending, currentToken.isNotEmpty);

          expect(fixture.client.authStore.token, currentToken);
          expect(fixture.client.authStore.record, same(currentRecord));
        });
      }
    }

    test('does not hide an unexpected late failure after logout', () async {
      fixture.authenticate();
      final response = Completer<http.Response>();
      final started = Completer<void>();
      fixture.respond = (_) {
        started.complete();
        return response.future;
      };
      final failure = StateError('unexpected');

      final pending = repository.loadSession();
      final assertion = expectLater(pending, throwsA(same(failure)));
      await started.future;
      fixture.client.authStore.clear();
      response.completeError(failure);
      await assertion;

      expect(fixture.client.authStore.token, isEmpty);
    });

    test('ignores a late transport failure after logout', () async {
      fixture.authenticate();
      final response = Completer<http.Response>();
      final started = Completer<void>();
      fixture.respond = (_) {
        started.complete();
        return response.future;
      };

      final pending = repository.loadSession();
      await started.future;
      fixture.client.authStore.clear();
      response.completeError(const SocketException('offline'));

      expect(await pending, isFalse);
      expect(fixture.client.authStore.token, isEmpty);
    });

    test(
      'detects logout and restoration of the same token and record',
      () async {
        fixture.authenticate();
        final token = fixture.client.authStore.token;
        final record = fixture.client.authStore.record;
        final response = Completer<http.Response>();
        final started = Completer<void>();
        fixture.respond = (_) {
          started.complete();
          return response.future;
        };

        final pending = repository.loadSession();
        await started.future;
        fixture.client.authStore.clear();
        fixture.client.authStore.save(token, record);
        response.complete(
          PocketBaseFixture.authResponse(authToken: 'obsolete-token'),
        );

        expect(await pending, isTrue);
        expect(fixture.client.authStore.token, token);
        expect(fixture.client.authStore.record, same(record));
      },
    );

    test(
      'refreshes a replacement session without sharing an older request',
      () async {
        fixture.authenticate();
        final firstResponse = Completer<http.Response>();
        final firstStarted = Completer<void>();
        final secondResponse = Completer<http.Response>();
        final secondStarted = Completer<void>();
        fixture.respond = (request) {
          if (request.headers['Authorization'] == PocketBaseFixture.token) {
            firstStarted.complete();
            return firstResponse.future;
          }

          secondStarted.complete();
          return secondResponse.future;
        };

        final first = repository.loadSession();
        await firstStarted.future;
        fixture.authenticate(authToken: 'new-login-token', id: 'new-user');
        final second = repository.loadSession();
        await secondStarted.future;
        expect(second, isNot(same(first)));

        firstResponse.complete(PocketBaseFixture.authResponse());
        expect(await first, isTrue);
        expect(repository.loadSession(), same(second));

        secondResponse.complete(
          PocketBaseFixture.authResponse(
            authToken: 'new-refreshed-token',
            id: 'new-user',
          ),
        );
        expect(await second, isTrue);
        expect(fixture.client.authStore.token, 'new-refreshed-token');
        expect(fixture.client.authStore.record?.id, 'new-user');
        expect(fixture.requests, hasLength(2));
      },
    );
  });

  group('failures', () {
    setUp(() => fixture.authenticate());

    test('clears the AuthStore on 401', () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({}, status: 401);

      expect(await repository.loadSession(), isFalse);
      expect(fixture.client.authStore.token, isEmpty);
      expect(fixture.client.authStore.record, isNull);
    });

    for (final status in [400, 403, 429, 500]) {
      test('preserves session and HTTP $status metadata', () async {
        fixture.respond = (_) => PocketBaseFixture.jsonResponse({
          'message': 'Remote failure',
          'data': {
            'identity': {'code': 'validation_invalid', 'message': 'Invalid'},
          },
        }, status: status);

        await expectLater(
          repository.loadSession(),
          throwsA(
            isA<SessionException>()
                .having(
                  (error) => error.errors.errors.single.status,
                  'status',
                  '$status',
                )
                .having(
                  (error) => error.errors.errors.single.pointer,
                  'pointer',
                  '/identity',
                )
                .having(
                  (error) => error.errors.errors.single.code,
                  'code',
                  'validation_invalid',
                ),
          ),
        );
        expect(fixture.client.authStore.token, PocketBaseFixture.token);
      });
    }

    test(
      'preserves session on transport failure and permits manual retry',
      () async {
        fixture.respond = (_) => throw const SocketException('offline');

        await expectLater(
          repository.loadSession(),
          throwsA(isA<SessionException>()),
        );
        expect(fixture.client.authStore.token, PocketBaseFixture.token);
        expect(fixture.requests, hasLength(1));

        fixture.respond = (_) => PocketBaseFixture.authResponse();
        expect(await repository.loadSession(), isTrue);
        expect(fixture.requests, hasLength(2));
      },
    );

    for (final body in <Map<String, dynamic>>[
      {
        'token': 1,
        'record': {'id': 'user-1'},
      },
      {'token': 'token', 'record': []},
    ]) {
      test('does not commit malformed auth response $body', () async {
        fixture.respond = (_) => PocketBaseFixture.jsonResponse(body);

        await expectLater(
          repository.loadSession(),
          throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
        );
        expect(fixture.client.authStore.token, PocketBaseFixture.token);
      });
    }

    test('delegates missing auth fields to SDK defaults', () async {
      fixture.respond = (_) => PocketBaseFixture.jsonResponse({});

      expect(await repository.loadSession(), isFalse);
      expect(fixture.client.authStore.token, isEmpty);
      expect(fixture.client.authStore.record?.id, isEmpty);
    });

    test('does not add record ID validation to native SDK success', () async {
      fixture.respond = (_) =>
          PocketBaseFixture.authResponse(authToken: 'refreshed-token', id: '');

      expect(await repository.loadSession(), isTrue);
      expect(fixture.client.authStore.token, 'refreshed-token');
      expect(fixture.client.authStore.record?.id, isEmpty);
    });

    test('propagates unexpected SDK failures', () async {
      final failure = StateError('unexpected');
      fixture.respond = (_) => throw failure;

      await expectLater(repository.loadSession(), throwsA(same(failure)));
      expect(fixture.client.authStore.token, PocketBaseFixture.token);
    });
  });

  group('observation', () {
    test('forwards boolean session changes and stream failures and cancels the SDK subscription', () async {
      final store = AuthStoreMock();
      final subscribed = Completer<void>();
      final cancelled = Completer<void>();
      final changes = StreamController<AuthStoreEvent>.broadcast(
        onListen: subscribed.complete,
        onCancel: cancelled.complete,
      );
      when(() => store.onChange).thenAnswer((_) => changes.stream);
      final client = PocketBase('https://example.com', authStore: store);
      final observedRepository = SessionRepository(pocketBase: client);
      final events = <bool>[];
      final errors = <Object>[];
      final delivered = Completer<void>();
      final failure = StateError('stream failure');
      final subscription = observedRepository.sessionChanges.listen((
        hasSession,
      ) {
        events.add(hasSession);
        if (events.length == 2) {
          delivered.complete();
        }
      }, onError: errors.add);
      addTearDown(subscription.cancel);
      addTearDown(changes.close);
      addTearDown(client.close);
      await subscribed.future;

      changes.add(AuthStoreEvent('token', null));
      changes.addError(failure);
      changes.add(AuthStoreEvent('', null));
      await delivered.future;

      expect(events, [true, false]);
      expect(errors, [same(failure)]);
      await subscription.cancel();
      await cancelled.future;
      expect(changes.hasListener, isFalse);
    });
  });
}
