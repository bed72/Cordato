import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/infrastructure/repositories/user_repository.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

import '../../../../support/core/mocks/http_client_mock.dart';
import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  const id = ' a/b?c#d ';
  const body = {
    'id': 'api-id',
    'name': 'Nome da API',
    'avatar': 'api-avatar',
    'email': 'person@example.com',
  };
  late HttpClientMock http;
  late StorageClientMock storage;
  late IUserRepository repository;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    http = HttpClientMock();
    storage = StorageClientMock();
    repository = UserRepository(httpClient: http, storageClient: storage);
    when(() => storage.read(key: StorageKeyEnum.userId.key))
        .thenAnswer((_) async => id);
    when(() => storage.clear()).thenAnswer((_) async {});
    when(() => http.get(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 200, body: body));
    when(() => http.patch(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 200, body: body));
    when(() => http.delete(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 204, body: {}));
  });

  group('Profile reads and updates', () {
    test('preserves native PocketBase field errors and metadata', () async {
      final failure = HttpResponseException.fromResponse(
        const Responses(
          status: 400,
          body: {
            'code': 400,
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
          },
        ),
      );
      when(() => http.patch(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => throw failure);

      await expectLater(
        repository.update(name: 'A'),
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
      verifyNever(() => storage.clear());
    });

    test(
      'reads the current ID and maps the API resource into an entity',
      () async {
        final user = await repository.getById();
        expect(user.id, 'api-id');
        expect(user.name, 'Nome da API');
        expect(user.email, 'person@example.com');
        expect(user.avatar, 'api-avatar');
        final request =
            verify(() => http.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(
          request.path,
          'collections/users/records/${Uri.encodeComponent(id)}',
        );
        expect(request.body, isNull);
        expect(request.headers, isNull);
        expect(request.query, isNull);
        verify(() => storage.read(key: StorageKeyEnum.userId.key)).called(1);
        verifyNoMoreInteractions(storage);
      },
    );

    for (final name in <String?>[null, '  Nome  ']) {
      for (final avatar in <String?>[null, '  seed  ']) {
        test('patches only supplied attributes: $name / $avatar', () async {
          final user = await repository.update(name: name, avatar: avatar);
          expect(user.name, 'Nome da API');
          expect(user.avatar, 'api-avatar');
          final request =
              verify(
                    () => http.patch(parameter: captureAny(named: 'parameter')),
                  ).captured.single
                  as Requests;
          expect(
            request.path,
            'collections/users/records/${Uri.encodeComponent(id)}',
          );
          expect(request.body, {'name': ?name, 'avatar': ?avatar});
          expect(request.headers, isNull);
          expect(request.query, isNull);
          verifyNever(() => storage.clear());
        });
      }
    }
  });

  group('Shared failure handling', () {
    for (final operation in ['get', 'update', 'delete']) {
      Future<dynamic> execute() => switch (operation) {
        'get' => repository.getById(),
        'update' => repository.update(name: 'Nome', avatar: 'seed'),
        _ => repository.delete(),
      };
      Future<Responses> request() => switch (operation) {
        'get' => http.get(parameter: any(named: 'parameter')),
        'update' => http.patch(parameter: any(named: 'parameter')),
        _ => http.delete(parameter: any(named: 'parameter')),
      };

      test('$operation waits for the stored ID', () async {
        final pending = Completer<String?>();
        when(() => storage.read(key: StorageKeyEnum.userId.key))
            .thenAnswer((_) => pending.future);
        final result = execute();
        verifyZeroInteractions(http);
        pending.complete(id);
        await result;
        verify(request).called(1);
      });

      for (final missingId in [null, '', '   ']) {
        test('$operation rejects missing ID $missingId without HTTP', () async {
          when(() => storage.read(key: StorageKeyEnum.userId.key))
              .thenAnswer((_) async => missingId);
          await expectLater(
            execute(),
            throwsA(
              isA<UserException>().having(
                (exception) => exception.errors.errors.single.title,
                'title',
                'Usuário não identificado',
              ),
            ),
          );
          verifyZeroInteractions(http);
          verifyNever(() => storage.clear());
        });
      }

      test(
        '$operation propagates storage reading failures unchanged',
        () async {
          final error = StateError('storage');
          when(() => storage.read(key: StorageKeyEnum.userId.key))
              .thenAnswer((_) async => throw error);
          await expectLater(execute(), throwsA(same(error)));
          verifyZeroInteractions(http);
          verifyNever(() => storage.clear());
        },
      );

      test('$operation preserves HTTP error order and metadata', () async {
        final failure = HttpResponseException.fromResponse(
          const Responses(
            status: 422,
            body: {
              'errors': [
                {
                  'status': '422',
                  'title': 'Inválido',
                  'detail': 'Informe um nome.',
                  'source': {
                    'pointer': '/data/attributes/name',
                    'parameter': 'name',
                  },
                },
                {'title': 'Outro erro', 'detail': 'Tente novamente.'},
              ],
            },
          ),
        );
        when(request).thenAnswer((_) async => throw failure);
        try {
          await execute();
          fail('Expected UserException');
        } on UserException catch (exception) {
          final errors = exception.errors.errors;
          expect(errors, hasLength(2));
          expect(errors.first.status, '422');
          expect(errors.first.title, 'Inválido');
          expect(errors.first.detail, 'Informe um nome.');
          expect(errors.first.pointer, '/data/attributes/name');
          expect(errors.first.parameter, 'name');
          expect(errors.last.title, 'Outro erro');
          expect(errors.last.detail, 'Tente novamente.');
        }
        verifyNever(() => storage.clear());
      });

      test(
        '$operation converts typed client failures into a safe failure',
        () async {
          when(request)
              .thenAnswer((_) async => throw HttpUnexpectedException());
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
          verifyNever(() => storage.clear());
        },
      );

      test('$operation propagates unexpected exceptions unchanged', () async {
        final error = StateError('unexpected');
        when(request).thenAnswer((_) async => throw error);
        await expectLater(execute(), throwsA(same(error)));
        verifyNever(() => storage.clear());
      });

      if (operation != 'delete') {
        for (final malformed in <Map<String, dynamic>>[
          {},
          {'id': 'id', 'name': 'Nome', 'email': 'person@example.com'},
          {
            'id': 123,
            'name': 'Nome',
            'email': 'person@example.com',
            'avatar': '',
          },
        ]) {
          test('$operation propagates invalid parsing: $malformed', () async {
            when(
              request,
            ).thenAnswer((_) async => Responses(status: 200, body: malformed));
            await expectLater(execute(), throwsA(isA<TypeError>()));
          });
        }
      }
    }
  });

  group('Account deletion and local cleanup', () {
    test(
      'deletion waits for remote confirmation and then for storage clearing',
      () async {
        final remote = Completer<Responses>();
        final cleared = Completer<void>();
        final clearing = Completer<void>();
        when(() => http.delete(parameter: any(named: 'parameter')))
            .thenAnswer((_) => remote.future);
        when(() => storage.clear()).thenAnswer((_) {
          clearing.complete();
          return cleared.future;
        });
        var completed = false;
        final result = repository.delete().then((_) {
          completed = true;
        });
        verifyNever(() => storage.clear());
        remote.complete(const Responses(status: 204, body: {}));
        await clearing.future;
        expect(completed, isFalse);
        cleared.complete();
        await result;
        expect(completed, isTrue);
        final request =
            verify(() => http.delete(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(
          request.path,
          'collections/users/records/${Uri.encodeComponent(id)}',
        );
        expect(request.body, isNull);
        expect(request.headers, isNull);
        verify(() => storage.clear()).called(1);
      },
    );

    test(
      'unexpected 2xx status does not confirm deletion or clear storage',
      () async {
        when(() => http.delete(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => const Responses(status: 200, body: {}));
        await expectLater(repository.delete(), throwsA(isA<UserException>()));
        verifyNever(() => storage.clear());
      },
    );

    test(
      'storage clearing failures propagate instead of confirming deletion',
      () async {
        final error = StateError('storage');
        when(() => storage.clear()).thenAnswer((_) async => throw error);
        await expectLater(repository.delete(), throwsA(same(error)));
        verify(() => http.delete(parameter: any(named: 'parameter'))).called(1);
      },
    );
  });
}
