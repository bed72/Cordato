import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/session/infrastructure/repositories/session_repository.dart';
import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';

import '../../../../support/core/mocks/storage_client_mock.dart';
import '../../../../support/core/mocks/http_client_mock.dart';

void main() {
  late StorageClientMock storage;
  late HttpClientMock http;
  late SessionRepository repository;

  const refreshed = Responses(
    status: 200,
    body: {
      'token': 'refreshed-token',
      'record': {'id': 'fixture-user', 'verified': true},
    },
  );
  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    storage = StorageClientMock();
    http = HttpClientMock();
    repository = SessionRepository(storageClient: storage, httpClient: http);
    when(() => http.post(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => refreshed);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
  });

  group('Initial load and refresh persistence', () {
    for (final scenario in [
      (token: null, present: false),
      (token: '', present: false),
    ]) {
      test(
        'skips refresh when token is absent: ${scenario.token?.length}',
        () async {
          when(() => storage.read(key: StorageKeyEnum.token.key))
              .thenAnswer((_) async => scenario.token);
          expect(await repository.loadSession(), scenario.present);
          verify(() => storage.read(key: StorageKeyEnum.token.key)).called(1);
          verifyNoMoreInteractions(storage);
          verifyZeroInteractions(http);
        },
      );
    }

    test('waits for the initial storage read', () async {
      final pending = Completer<String?>();
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) => pending.future);
      var finished = false;
      final result = repository.loadSession().then((value) {
        finished = true;
        return value;
      });
      expect(finished, isFalse);
      pending.complete('opaque-token');
      expect(await result, isTrue);
    });

    test('posts auth-refresh without body or headers and awaits both persisted values', () async {
      when(() => storage.read(key: StorageKeyEnum.token.key))
          .thenAnswer((_) async => 'old-token');
      final savingId = Completer<void>();
      final savedId = Completer<void>();
      final savingToken = Completer<void>();
      final savedToken = Completer<void>();
      when(
        () => storage.write(
          key: StorageKeyEnum.userId.key,
          value: 'fixture-user',
        ),
      ).thenAnswer((_) {
        savingId.complete();
        return savedId.future;
      });
      when(
        () => storage.write(
          key: StorageKeyEnum.token.key,
          value: 'refreshed-token',
        ),
      ).thenAnswer((_) {
        savingToken.complete();
        return savedToken.future;
      });
      var finished = false;
      final pending = repository.loadSession().then((value) {
        finished = true;
        return value;
      });
      await savingId.future;
      expect(finished, isFalse);
      verifyNever(
        () => storage.write(
          key: StorageKeyEnum.token.key,
          value: any(named: 'value'),
        ),
      );
      savedId.complete();
      await savingToken.future;
      expect(finished, isFalse);
      savedToken.complete();
      expect(await pending, isTrue);
      final request =
          verify(() => http.post(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'collections/users/auth-refresh');
      expect(request.body, isNull);
      expect(request.query, isNull);
      expect(request.headers, isNull);
    });

    test(
      'coalesces concurrent loads and allows a later explicit load',
      () async {
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'old-token');
        final response = Completer<Responses>();
        final started = Completer<void>();
        when(() => http.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) {
              started.complete();
              return response.future;
            });
        final first = repository.loadSession();
        final second = repository.loadSession();
        expect(identical(first, second), isTrue);
        await started.future;
        verify(() => http.post(parameter: any(named: 'parameter'))).called(1);
        response.complete(refreshed);
        expect(await first, isTrue);
        expect(await second, isTrue);
        when(() => http.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => refreshed);
        expect(await repository.loadSession(), isTrue);
        verify(() => http.post(parameter: any(named: 'parameter'))).called(1);
      },
    );
  });

  group('Obsolete refresh responses', () {
    for (final replacement in <String?>[null, 'new-login-token']) {
      for (final status in [200, 401, 403]) {
        test(
          'ignores stale refresh $status after token replacement ${replacement != null}',
          () async {
            String? token = 'old-token';
            when(() => storage.read(key: StorageKeyEnum.token.key))
                .thenAnswer((_) async => token);
            final response = Completer<Responses>();
            final started = Completer<void>();
            when(() => http.post(parameter: any(named: 'parameter')))
                .thenAnswer((_) {
                  started.complete();
                  return response.future;
                });
            final pending = repository.loadSession();
            await started.future;
            token = replacement;
            if (status == 200) {
              response.complete(refreshed);
            } else {
              response.completeError(
                HttpResponseException(status: status, errors: .unknown()),
              );
            }
            expect(await pending, replacement != null);
            verifyNever(
              () => storage.write(
                key: any(named: 'key'),
                value: any(named: 'value'),
              ),
            );
            verifyNever(() => storage.delete(key: any(named: 'key')));
            verifyNever(storage.clear);
          },
        );
      }
    }

    test(
      'does not restore the token if sign-out happens while saving the user id',
      () async {
        String? token = 'old-token';
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => token);
        when(
          () => storage.write(
            key: StorageKeyEnum.userId.key,
            value: 'fixture-user',
          ),
        ).thenAnswer((_) async {
          token = null;
        });
        expect(await repository.loadSession(), isFalse);
        verifyNever(
          () => storage.write(
            key: StorageKeyEnum.token.key,
            value: any(named: 'value'),
          ),
        );
      },
    );
  });

  group('HTTP, transport and persistence failures', () {
    test(
      'returns absence for a 401 without writing or clearing all storage',
      () async {
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'old-token');
        when(() => http.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async =>
              throw HttpResponseException(status: 401, errors: .unknown()),
        );
        expect(await repository.loadSession(), isFalse);
        verifyNever(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
        verifyNever(storage.clear);
      },
    );

    for (final status in [403, 429, 500]) {
      test('preserves session and native errors for HTTP $status', () async {
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'old-token');
        when(() => http.post(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => throw HttpResponseException.fromResponse(
            Responses(
              status: status,
              body: {
                'status': status,
                'message': 'Refresh rejected.',
                'data': <String, dynamic>{},
              },
            ),
          ),
        );
        await expectLater(
          repository.loadSession(),
          throwsA(
            isA<SessionException>()
                .having(
                  (error) => error.errors.errors.single.detail,
                  'detail',
                  'Refresh rejected.',
                )
                .having(
                  (error) => error.errors.errors.single.status,
                  'status',
                  '$status',
                ),
          ),
        );
        verifyNever(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
        verifyNever(() => storage.delete(key: any(named: 'key')));
        verifyNever(storage.clear);
      });
    }

    for (final kind in HttpExceptionEnum.values) {
      test('preserves storage on transport ${kind.name}', () async {
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'old-token');
        when(
          () => http.post(parameter: any(named: 'parameter')),
        ).thenAnswer((_) async => throw HttpTransportException(failure: kind));
        await expectLater(
          repository.loadSession(),
          throwsA(isA<SessionException>()),
        );
        verifyNever(() => storage.delete(key: any(named: 'key')));
        verifyNever(storage.clear);
      });
    }

    for (final body in <Map<String, dynamic>>[
      {},
      {
        'token': 1,
        'record': {'id': 'user'},
      },
      {
        'token': 'token',
        'record': {'id': 1},
      },
    ]) {
      test('propagates malformed refresh data without persisting', () async {
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'old-token');
        when(() => http.post(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => Responses(status: 200, body: body));
        await expectLater(repository.loadSession(), throwsA(isA<TypeError>()));
        verifyNever(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
      });
    }

    for (final key in [StorageKeyEnum.userId, StorageKeyEnum.token]) {
      test('propagates persistence failure for ${key.name}', () async {
        final failure = StateError('storage unavailable');
        when(() => storage.read(key: StorageKeyEnum.token.key))
            .thenAnswer((_) async => 'old-token');
        when(
          () => storage.write(
            key: key.key,
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async => throw failure);
        await expectLater(repository.loadSession(), throwsA(same(failure)));
        verifyNever(storage.clear);
      });
    }
  });

  group('Storage reads and continuous observation', () {
    test(
      'maps token changes to booleans without exposing token values',
      () async {
        when(() => storage.watch(key: StorageKeyEnum.token.key)).thenAnswer(
          (_) => Stream.fromIterable(['token', null, '', ' ', 'new-token']),
        );
        await expectLater(
          repository.sessionChanges,
          emitsInOrder([true, false, false, true, true, emitsDone]),
        );
        verify(() => storage.watch(key: StorageKeyEnum.token.key)).called(1);
        verifyNoMoreInteractions(storage);
      },
    );

    for (final synchronous in [false, true]) {
      test(
        'propagates ${synchronous ? 'synchronous' : 'asynchronous'} read failures without inventing absence',
        () async {
          final failure = StateError('storage unavailable');
          if (synchronous) {
            when(() => storage.read(key: StorageKeyEnum.token.key))
                .thenThrow(failure);
          } else {
            when(() => storage.read(key: StorageKeyEnum.token.key))
                .thenAnswer((_) async => throw failure);
          }
          await expectLater(repository.loadSession(), throwsA(same(failure)));
          verify(() => storage.read(key: StorageKeyEnum.token.key)).called(1);
          verifyNoMoreInteractions(storage);
        },
      );
    }

    test(
      'propagates stream errors and continues forwarding later token changes',
      () async {
        final changes = StreamController<String?>();
        addTearDown(changes.close);
        when(() => storage.watch(key: StorageKeyEnum.token.key))
            .thenAnswer((_) => changes.stream);
        final failure = StateError('watch unavailable');
        final result = expectLater(
          repository.sessionChanges,
          emitsInOrder([emitsError(same(failure)), true, emitsDone]),
        );
        changes.addError(failure);
        changes.add('token');
        await changes.close();
        await result;
      },
    );

    test('cancelling observation releases the storage listener', () async {
      final changes = StreamController<String?>.broadcast();
      addTearDown(changes.close);
      when(() => storage.watch(key: StorageKeyEnum.token.key))
          .thenAnswer((_) => changes.stream);
      final subscription = repository.sessionChanges.listen((_) {});
      expect(changes.hasListener, isTrue);
      await subscription.cancel();
      expect(changes.hasListener, isFalse);
    });

    test('propagates a synchronous watch failure', () {
      final failure = StateError('watch unavailable');
      when(() => storage.watch(key: StorageKeyEnum.token.key))
          .thenThrow(failure);
      expect(() => repository.sessionChanges, throwsA(same(failure)));
    });
  });
}
