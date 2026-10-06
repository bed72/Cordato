import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/user/data/repositories/user_repository.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

import 'package:cordato/features/user/infrastructure/responses/user_response.dart';
import 'package:cordato/features/user/infrastructure/remoto/user_remote_data_source.dart';

import '../../../../support/user/mocks/user_local_data_source_mock.dart';
import '../../../../support/user/mocks/user_remote_data_source_mock.dart';

void main() {
  const id = 'requested-id';
  const userResponse = UserResponse(
    name: 'Gabriel',
    status: 'active',
    id: 'returned-id',
    email: 'gabriel@example.com',
  );

  const errorsResponse = ErrorsResponse(
    errors: [
      ErrorResponse(
        status: '422',
        title: 'Nome inválido',
        pointer: '/data/attributes/name',
        detail: 'Informe um nome válido.',
      ),
      ErrorResponse(detail: 'Não foi possível atualizar o usuário.'),
    ],
  );

  late IUserRepository repository;
  late UserRemoteDataSourceMock dataSource;
  late UserLocalDataSourceMock localDataSource;

  setUp(() {
    dataSource = UserRemoteDataSourceMock();
    localDataSource = UserLocalDataSourceMock();
    when(() => localDataSource.getId()).thenAnswer((_) async => id);
    when(() => localDataSource.clear()).thenAnswer((_) async {});
    repository = UserRepository(
      remoteDataSource: dataSource,
      localDataSource: localDataSource,
    );
  });

  group('UserRepository', () {
    group('update', () {
      late Future<Either<ErrorsEntity, UserEntity>> Function() execute;

      setUp(() {
        execute = () => repository.update(name: 'Gabriel');
      });

      test(
        'uses the stored ID and returns the user supplied by the API',
        () async {
          final pendingId = Completer<String?>();
          when(() => localDataSource.getId())
              .thenAnswer((_) => pendingId.future);
          when(() => dataSource.update(id: id, name: 'Gabriel'))
              .thenAnswer((_) async => const Right(userResponse));

          final pendingResult = execute();
          verifyZeroInteractions(dataSource);
          pendingId.complete(id);
          final response = await pendingResult;

          expect(response.right.id, userResponse.id);
          expect(response.right.name, userResponse.name);
          expect(response.right.email, userResponse.email);
          verify(() => localDataSource.getId()).called(1);
          verify(() => dataSource.update(id: id, name: 'Gabriel')).called(1);
          verifyNoMoreInteractions(dataSource);
          verifyNoMoreInteractions(localDataSource);
        },
      );

      for (final missingId in [null, '', '   ']) {
        test(
          'returns an identification error for ID $missingId without a remote call',
          () async {
            when(() => localDataSource.getId())
                .thenAnswer((_) async => missingId);

            final response = await execute();

            expect(
              response.left.errors.single.title,
              'Usuário não identificado',
            );
            expect(
              response.left.errors.single.detail,
              'Não foi possível identificar o usuário atual.',
            );
            verify(() => localDataSource.getId()).called(1);
            verifyZeroInteractions(dataSource);
            verifyNoMoreInteractions(localDataSource);
          },
        );
      }

      test('returns an unknown error when reading the ID fails', () async {
        when(() => localDataSource.getId())
            .thenAnswer((_) async => throw StateError('storage unavailable'));

        final response = await execute();

        expect(response.left.errors.single.title, 'Erro desconhecido');
        verify(() => localDataSource.getId()).called(1);
        verifyZeroInteractions(dataSource);
        verifyNoMoreInteractions(localDataSource);
      });

      test('preserves remote validation errors', () async {
        when(() => localDataSource.getId()).thenAnswer((_) async => id);
        when(() => dataSource.update(id: id, name: 'Gabriel'))
            .thenAnswer((_) async => const Left(errorsResponse));

        final response = await execute();

        expect(response.left.errors.first.status, '422');
        expect(response.left.errors.first.detail, 'Informe um nome válido.');
        expect(response.left.errors.first.pointer, '/data/attributes/name');
      });

      test('returns an unknown error when the remote source throws', () async {
        when(() => localDataSource.getId()).thenAnswer((_) async => id);
        when(() => dataSource.update(id: id, name: 'Gabriel'))
            .thenAnswer((_) async => throw StateError('offline'));

        final response = await execute();

        expect(response.left.errors.single.title, 'Erro desconhecido');
      });
    });

    test('returns the requested user as a domain entity', () async {
      when(() => dataSource.getById(id: id))
          .thenAnswer((_) async => const Right(userResponse));

      final response = await repository.getById();

      expect(response.right, isA<UserEntity>());
      expect(response.right.id, userResponse.id);
      expect(response.right.name, userResponse.name);
      expect(response.right.email, userResponse.email);
      expect(response.right.status, userResponse.status);
      verify(() => dataSource.getById(id: id)).called(1);
      verifyNoMoreInteractions(dataSource);
      verify(() => localDataSource.getId()).called(1);
      verifyNoMoreInteractions(localDataSource);
    });

    test(
      'forwards the new name and returns the updated domain entity',
      () async {
        when(() => localDataSource.getId()).thenAnswer((_) async => id);
        when(() => dataSource.update(id: id, name: 'Gabriel'))
            .thenAnswer((_) async => const Right(userResponse));

        final response = await repository.update(name: 'Gabriel');

        expect(response.right, isA<UserEntity>());
        expect(response.right.id, userResponse.id);
        expect(response.right.name, userResponse.name);
        expect(response.right.email, userResponse.email);
        expect(response.right.status, userResponse.status);
        verify(() => dataSource.update(id: id, name: 'Gabriel')).called(1);
        verifyNoMoreInteractions(dataSource);
        verify(() => localDataSource.getId()).called(1);
        verifyNoMoreInteractions(localDataSource);
      },
    );

    test('forwards an update without a name', () async {
      when(() => localDataSource.getId()).thenAnswer((_) async => id);
      when(() => dataSource.update(id: id, name: null))
          .thenAnswer((_) async => const Right(userResponse));

      expect((await repository.update()).right.id, userResponse.id);

      verify(() => dataSource.update(id: id, name: null)).called(1);
      verifyNoMoreInteractions(dataSource);
      verify(() => localDataSource.getId()).called(1);
      verifyNoMoreInteractions(localDataSource);
    });

    for (final deleted in [true, false]) {
      test('preserves the deletion result $deleted', () async {
        when(() => dataSource.delete(id: id))
            .thenAnswer((_) async => Right(deleted));

        expect((await repository.delete()).right, deleted);

        if (deleted) {
          verifyInOrder([
            () => localDataSource.getId(),
            () => dataSource.delete(id: id),
            () => localDataSource.clear(),
          ]);
          verifyNoMoreInteractions(localDataSource);
        } else {
          verify(() => dataSource.delete(id: id)).called(1);
          verify(() => localDataSource.getId()).called(1);
          verifyNoMoreInteractions(localDataSource);
        }
        verifyNoMoreInteractions(dataSource);
      });
    }

    test(
      'clears local storage only after remote deletion is confirmed',
      () async {
        final pending = Completer<DeleteDataSourceType>();
        final started = Completer<void>();
        when(() => dataSource.delete(id: id)).thenAnswer((_) {
          started.complete();
          return pending.future;
        });

        final response = repository.delete();
        await started.future;
        verifyNever(() => localDataSource.clear());
        pending.complete(const Right(true));

        expect((await response).right, isTrue);
        verify(() => localDataSource.clear()).called(1);
      },
    );

    test(
      'waits for local clearing before returning deletion success',
      () async {
        final clearing = Completer<void>();
        final pending = Completer<void>();
        when(() => dataSource.delete(id: id))
            .thenAnswer((_) async => const Right(true));
        when(() => localDataSource.clear()).thenAnswer((_) {
          clearing.complete();
          return pending.future;
        });

        var completed = false;
        final response = repository.delete().then((result) {
          completed = true;
          return result;
        });
        await clearing.future;
        expect(completed, isFalse);
        pending.complete();

        expect((await response).right, isTrue);
        expect(completed, isTrue);
      },
    );

    test('returns an unknown error when local clearing fails', () async {
      when(() => dataSource.delete(id: id))
          .thenAnswer((_) async => const Right(true));
      when(() => localDataSource.clear())
          .thenAnswer((_) async => throw StateError('storage unavailable'));

      final response = await repository.delete();

      expect(response.left.errors.single.title, 'Erro desconhecido');
      expect(
        response.left.errors.single.detail,
        'Não foi possível processar a resposta.',
      );
      verifyInOrder([
        () => localDataSource.getId(),
        () => dataSource.delete(id: id),
        () => localDataSource.clear(),
      ]);
      verifyNoMoreInteractions(dataSource);
      verifyNoMoreInteractions(localDataSource);
    });

    for (final operation in ['getById', 'delete']) {
      group(operation, () {
        late Future<Either<ErrorsEntity, Object>> Function() execute;

        setUp(() {
          execute = switch (operation) {
            'getById' => repository.getById,
            _ => repository.delete,
          };
        });

        test(
          'waits for the stored ID before calling the remote source',
          () async {
            final pendingId = Completer<String?>();
            when(() => localDataSource.getId())
                .thenAnswer((_) => pendingId.future);
            when(() => dataSource.getById(id: id))
                .thenAnswer((_) async => const Right(userResponse));
            when(() => dataSource.delete(id: id))
                .thenAnswer((_) async => const Right(false));

            final response = execute();
            verifyZeroInteractions(dataSource);
            verifyNever(() => localDataSource.clear());
            pendingId.complete(id);

            expect((await response).isRight, isTrue);
            verify(() => localDataSource.getId()).called(1);
            if (operation == 'getById') {
              verify(() => dataSource.getById(id: id)).called(1);
            } else {
              verify(() => dataSource.delete(id: id)).called(1);
            }
            verifyNoMoreInteractions(dataSource);
            verifyNoMoreInteractions(localDataSource);
          },
        );

        for (final missingId in [null, '', '   ']) {
          test(
            'rejects ID $missingId without a remote call or storage clearing',
            () async {
              when(() => localDataSource.getId())
                  .thenAnswer((_) async => missingId);

              final response = await execute();

              expect(
                response.left.errors.single.title,
                'Usuário não identificado',
              );
              expect(
                response.left.errors.single.detail,
                'Não foi possível identificar o usuário atual.',
              );
              verify(() => localDataSource.getId()).called(1);
              verifyNoMoreInteractions(localDataSource);
              verifyZeroInteractions(dataSource);
            },
          );
        }

        test('returns an unknown error when reading the ID fails', () async {
          when(() => localDataSource.getId())
              .thenAnswer((_) async => throw StateError('storage unavailable'));

          final response = await execute();

          expect(response.left.errors.single.title, 'Erro desconhecido');
          verify(() => localDataSource.getId()).called(1);
          verifyNoMoreInteractions(localDataSource);
          verifyZeroInteractions(dataSource);
        });

        test('preserves remote error details as domain errors', () async {
          when(() => dataSource.getById(id: id))
              .thenAnswer((_) async => const Left(errorsResponse));
          when(() => dataSource.update(id: id, name: 'Gabriel'))
              .thenAnswer((_) async => const Left(errorsResponse));
          when(() => dataSource.delete(id: id))
              .thenAnswer((_) async => const Left(errorsResponse));

          final response = await execute();

          expect(response.left, isA<ErrorsEntity>());
          expect(response.left.errors, hasLength(2));
          expect(response.left.errors.first.status, '422');
          expect(response.left.errors.first.title, 'Nome inválido');
          expect(response.left.errors.first.detail, 'Informe um nome válido.');
          expect(response.left.errors.first.pointer, '/data/attributes/name');
          expect(
            response.left.errors.last.detail,
            'Não foi possível atualizar o usuário.',
          );
          verify(() => localDataSource.getId()).called(1);
          verifyNoMoreInteractions(localDataSource);
        });

        test('converts unexpected exceptions into an unknown error', () async {
          when(() => dataSource.getById(id: id))
              .thenAnswer((_) async => throw StateError('offline'));
          when(() => dataSource.update(id: id, name: 'Gabriel'))
              .thenAnswer((_) async => throw StateError('offline'));
          when(() => dataSource.delete(id: id))
              .thenAnswer((_) async => throw StateError('offline'));

          final response = await execute();

          expect(response.left.errors.single.title, 'Erro desconhecido');
          expect(
            response.left.errors.single.detail,
            'Não foi possível processar a resposta.',
          );
          verify(() => localDataSource.getId()).called(1);
          verifyNoMoreInteractions(localDataSource);
        });
      });
    }
  });
}
