import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';
import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/infrastructure/repositories/user_repository.dart';

import '../../../../support/core/fakes/pocketbase_fixture.dart';

void main() {
  const body = {
    'id': 'user-1',
    'collectionName': 'users',
    'name': 'Nome da API',
    'avatar': 'api-avatar',
    'email': 'person@example.com',
  };
  late PocketBaseFixture fixture;
  late IUserRepository repository;

  setUp(() {
    fixture = PocketBaseFixture();
    fixture.authenticate();
    fixture.respond = (_) => PocketBaseFixture.jsonResponse(body);
    repository = UserRepository(pocketBase: fixture.client);
    addTearDown(fixture.client.close);
  });

  group('Profile reads and updates', () {
    test(
      'reads the current auth identity and maps the remote record',
      () async {
        final user = await repository.getById();

        expect(user.id, 'user-1');
        expect(user.name, 'Nome da API');
        expect(user.email, 'person@example.com');
        expect(user.avatar, 'api-avatar');
        final request = fixture.requests.single;
        expect(request.method, 'GET');
        expect(request.url.path, '/api/collections/users/records/user-1');
        expect(request.headers['Authorization'], PocketBaseFixture.token);
        expect(request.body, isEmpty);
        expect(request.url.query, isEmpty);
      },
    );

    test('reads the current auth record on each operation', () async {
      await repository.getById();
      fixture.authenticate(id: 'new-user');

      await repository.getById();

      expect(
        fixture.requests.last.url.path,
        '/api/collections/users/records/new-user',
      );
    });

    test('delegates ID encoding to the SDK without trimming', () async {
      const id = ' a/b?c#d ';
      fixture.authenticate(id: id);

      await repository.getById();

      expect(fixture.requests.single.url.pathSegments.last, id);
      expect(fixture.requests.single.url.query, isEmpty);
      expect(fixture.requests.single.url.fragment, isEmpty);
    });

    for (final name in <String?>[null, '', '  Nome  ']) {
      for (final avatar in <String?>[null, '', '  seed  ']) {
        if (name == null && avatar == null) {
          continue;
        }

        test('patches only supplied attributes: $name / $avatar', () async {
          final user = await repository.update(name: name, avatar: avatar);

          expect(user.name, 'Nome da API');
          expect(user.avatar, 'api-avatar');
          final request = fixture.requests.single;
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/collections/users/records/user-1');
          expect(jsonDecode(request.body), {'name': ?name, 'avatar': ?avatar});
          expect(request.headers['Authorization'], PocketBaseFixture.token);
          expect(fixture.client.authStore.token, PocketBaseFixture.token);
          expect(fixture.client.authStore.record?.data['name'], 'Nome da API');
        });
      }
    }

    test(
      'delegates an update without attributes as an empty SDK body',
      () async {
        final user = await repository.update();

        expect(user.name, 'Nome da API');
        expect(fixture.requests.single.method, 'PATCH');
        expect(fixture.requests.single.body, isEmpty);
        expect(fixture.client.authStore.token, PocketBaseFixture.token);
      },
    );

    test(
      'maps an empty avatar to absence and preserves an empty name',
      () async {
        fixture.respond = (_) =>
            PocketBaseFixture.jsonResponse({...body, 'name': '', 'avatar': ''});

        final user = await repository.getById();

        expect(user.name, isEmpty);
        expect(user.avatar, isNull);
      },
    );
  });

  group('Shared failure handling', () {
    for (final operation in ['get', 'update', 'delete']) {
      Future<dynamic> execute() => switch (operation) {
        'get' => repository.getById(),
        'update' => repository.update(name: 'Nome', avatar: 'seed'),
        _ => repository.delete(),
      };

      for (final missingId in <String?>[null, '', '   ']) {
        test(
          '$operation rejects missing auth ID $missingId without HTTP',
          () async {
            if (missingId == null) {
              fixture.client.authStore.clear();
            } else {
              fixture.authenticate(id: missingId);
            }

            await expectLater(
              execute(),
              throwsA(
                isA<MissingAuthenticatedUserException>().having(
                  (exception) => exception.errors.errors.single.title,
                  'title',
                  'Usuário não identificado',
                ),
              ),
            );

            expect(fixture.requests, isEmpty);
          },
        );
      }

      test(
        '$operation preserves ordered native field errors and metadata',
        () async {
          fixture.respond = (_) => PocketBaseFixture.jsonResponse({
            'message': 'Failed to update record.',
            'data': {
              'name': {
                'code': 'validation_length_out_of_range',
                'message': 'Must be between 2 and 32 characters.',
              },
              'avatar': {
                'code': 'validation_length_out_of_range',
                'message': 'Must be at most 2048 characters.',
              },
            },
          }, status: 400);

          await expectLater(
            execute(),
            throwsA(
              isA<UserException>().having(
                (exception) => exception.errors.errors
                    .map(
                      (error) => (
                        error.status,
                        error.code,
                        error.pointer,
                        error.parameter,
                        error.detail,
                      ),
                    )
                    .toList(),
                'ordered errors',
                [
                  (
                    '400',
                    'validation_length_out_of_range',
                    '/name',
                    'name',
                    'Must be between 2 and 32 characters.',
                  ),
                  (
                    '400',
                    'validation_length_out_of_range',
                    '/avatar',
                    'avatar',
                    'Must be at most 2048 characters.',
                  ),
                ],
              ),
            ),
          );
          expect(fixture.client.authStore.token, PocketBaseFixture.token);
        },
      );

      for (final status in [401, 403, 404, 500]) {
        test(
          '$operation maps HTTP $status without clearing the session',
          () async {
            fixture.respond = (_) => PocketBaseFixture.jsonResponse({
              'message': 'Remote failure',
            }, status: status);

            await expectLater(
              execute(),
              throwsA(
                isA<UserException>().having(
                  (exception) => exception.errors.errors.single.status,
                  'status',
                  '$status',
                ),
              ),
            );
            expect(fixture.client.authStore.token, PocketBaseFixture.token);
            expect(fixture.client.authStore.record?.id, 'user-1');
          },
        );
      }

      test(
        '$operation does not clear a newer login after a late 401',
        () async {
          fixture.respond = (_) {
            fixture.authenticate(authToken: 'new-token', id: 'new-user');
            return PocketBaseFixture.jsonResponse({}, status: 401);
          };

          await expectLater(execute(), throwsA(isA<UserException>()));

          expect(fixture.client.authStore.token, 'new-token');
          expect(fixture.client.authStore.record?.id, 'new-user');
        },
      );

      test(
        '$operation maps network failures without clearing the session',
        () async {
          fixture.respond = (_) => throw const SocketException('offline');

          await expectLater(
            execute(),
            throwsA(
              isA<UserException>().having(
                (exception) => exception.errors.errors.single.title,
                'title',
                'Erro desconhecido',
              ),
            ),
          );
          expect(fixture.client.authStore.token, PocketBaseFixture.token);
        },
      );

      test(
        '$operation preserves a replaced auth record after a late 401',
        () async {
          fixture.respond = (_) {
            fixture.authenticate();
            return PocketBaseFixture.jsonResponse({}, status: 401);
          };

          await expectLater(execute(), throwsA(isA<UserException>()));

          expect(fixture.client.authStore.token, PocketBaseFixture.token);
          expect(fixture.client.authStore.record?.id, 'user-1');
        },
      );

      test('$operation propagates unexpected errors unchanged', () async {
        final failure = StateError('unexpected');
        fixture.respond = (_) => throw failure;

        await expectLater(execute(), throwsA(same(failure)));
      });

      test(
        '$operation propagates unexpected format failures unchanged',
        () async {
          const failure = FormatException('invalid payload');
          fixture.respond = (_) => throw failure;

          await expectLater(execute(), throwsA(same(failure)));
        },
      );
    }

    for (final operation in ['get', 'update']) {
      for (final field in ['id', 'name', 'email', 'avatar']) {
        for (final invalid in [null, 123, false]) {
          test('$operation rejects invalid $field: $invalid', () async {
            fixture.respond = (_) =>
                PocketBaseFixture.jsonResponse({...body, field: invalid});

            final pending = switch (operation) {
              'get' => repository.getById(),
              _ => repository.update(name: 'Nome'),
            };

            await expectLater(pending, throwsA(isA<TypeError>()));
          });
        }

        test('$operation rejects missing $field', () async {
          final malformed = {...body}..remove(field);
          fixture.respond = (_) => PocketBaseFixture.jsonResponse(malformed);

          final pending = switch (operation) {
            'get' => repository.getById(),
            _ => repository.update(name: 'Nome'),
          };

          await expectLater(pending, throwsA(isA<TypeError>()));
        });
      }
    }
  });

  group('Account deletion and session cleanup', () {
    test(
      'awaits remote confirmation before clearing the shared AuthStore',
      () async {
        final remote = Completer<http.Response>();
        final started = Completer<void>();
        fixture.respond = (_) {
          started.complete();
          return remote.future;
        };
        final events = <String>[];
        final cleared = Completer<void>();
        final subscription = fixture.client.authStore.onChange.listen((event) {
          events.add(event.token);
          cleared.complete();
        });
        addTearDown(subscription.cancel);
        var completed = false;

        final deletion = repository.delete().then((_) => completed = true);
        await started.future;
        expect(completed, isFalse);
        expect(fixture.client.authStore.token, PocketBaseFixture.token);
        expect(events, isEmpty);
        remote.complete(http.Response('', 204));
        await deletion;
        await cleared.future;

        expect(completed, isTrue);
        expect(fixture.client.authStore.token, isEmpty);
        expect(fixture.client.authStore.record, isNull);
        expect(events, ['']);
        final request = fixture.requests.single;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/collections/users/records/user-1');
        expect(request.body, isEmpty);
        expect(request.url.query, isEmpty);
      },
    );

    test(
      'uses native SDK success semantics instead of requiring exactly 204',
      () async {
        fixture.respond = (_) =>
            PocketBaseFixture.jsonResponse({}, status: 200);

        await repository.delete();

        expect(fixture.client.authStore.token, isEmpty);
      },
    );

    test(
      'does not clear a different user authenticated during deletion',
      () async {
        fixture.respond = (_) {
          fixture.authenticate(authToken: 'new-token', id: 'new-user');
          return http.Response('', 204);
        };

        await repository.delete();

        expect(fixture.client.authStore.token, 'new-token');
        expect(fixture.client.authStore.record?.id, 'new-user');
      },
    );

    test(
      'does not wait for durable deletion from the native AsyncAuthStore',
      () async {
        final cleared = Completer<void>();
        final clearing = Completer<void>();
        final store = AsyncAuthStore(
          initial: jsonEncode({
            'token': PocketBaseFixture.token,
            'model': body,
          }),
          save: (_) async {},
          clear: () {
            clearing.complete();
            return cleared.future;
          },
        );
        final client = PocketBase(
          fixture.client.baseURL,
          authStore: store,
          httpClientFactory: fixture.client.httpClientFactory,
        );
        addTearDown(client.close);
        addTearDown(() {
          if (!cleared.isCompleted) {
            cleared.complete();
          }
        });
        fixture.respond = (_) => http.Response('', 204);
        final persistentRepository = UserRepository(pocketBase: client);

        await persistentRepository.delete();
        await clearing.future;

        expect(store.token, isEmpty);
        expect(cleared.isCompleted, isFalse);
        cleared.complete();
      },
    );
  });
}
