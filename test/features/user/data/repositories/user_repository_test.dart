import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/user/data/repositories/user_repository.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/infrastructure/remoto/user_remote_data_source.dart';
import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

import '../../../../support/user/mocks/user_remote_data_source_mock.dart';
import '../../../../support/user/mocks/user_local_data_source_mock.dart';

void main() {
  const id = 'requested-id';
  const userResponse = UserResponse(
    id: 'returned-id',
    name: 'Gabriel',
    email: 'gabriel@example.com',
    status: 'active',
  );
  const errorsResponse = ErrorsResponse(
    errors: [
      ErrorResponse(
        status: '422',
        title: 'Nome inválido',
        detail: 'Informe um nome válido.',
        pointer: '/data/attributes/name',
      ),
      ErrorResponse(detail: 'Não foi possível atualizar o usuário.'),
    ],
  );

  late UserRemoteDataSourceMock dataSource;
  late UserLocalDataSourceMock localDataSource;
  late IUserRepository repository;

  setUp(() {
    dataSource = UserRemoteDataSourceMock();
    localDataSource = UserLocalDataSourceMock();
    when(() => localDataSource.clear()).thenAnswer((_) async {});
    repository = UserRepository(
      remoteDataSource: dataSource,
      localDataSource: localDataSource,
    );
  });

  group('UserRepository', () {
    test('returns the requested user as a domain entity', () async {
      when(() => dataSource.getById(id: id))
          .thenAnswer((_) async => const Right(userResponse));

      final result = await repository.getById(id: id);

      expect(result.right, isA<UserEntity>());
      expect(result.right.id, userResponse.id);
      expect(result.right.name, userResponse.name);
      expect(result.right.email, userResponse.email);
      expect(result.right.status, userResponse.status);
      verify(() => dataSource.getById(id: id)).called(1);
      verifyNoMoreInteractions(dataSource);
      verifyZeroInteractions(localDataSource);
    });

    test(
      'forwards the new name and returns the updated domain entity',
      () async {
        when(() => dataSource.update(id: id, name: 'Gabriel'))
            .thenAnswer((_) async => const Right(userResponse));

        final result = await repository.update(id: id, name: 'Gabriel');

        expect(result.right, isA<UserEntity>());
        expect(result.right.id, userResponse.id);
        expect(result.right.name, userResponse.name);
        expect(result.right.email, userResponse.email);
        expect(result.right.status, userResponse.status);
        verify(() => dataSource.update(id: id, name: 'Gabriel')).called(1);
        verifyNoMoreInteractions(dataSource);
        verifyZeroInteractions(localDataSource);
      },
    );

    test('forwards an update without a name', () async {
      when(() => dataSource.update(id: id, name: null))
          .thenAnswer((_) async => const Right(userResponse));

      expect((await repository.update(id: id)).right.id, userResponse.id);

      verify(() => dataSource.update(id: id, name: null)).called(1);
      verifyNoMoreInteractions(dataSource);
      verifyZeroInteractions(localDataSource);
    });

    for (final deleted in [true, false]) {
      test('preserves the deletion result $deleted', () async {
        when(() => dataSource.delete(id: id))
            .thenAnswer((_) async => Right(deleted));

        expect((await repository.delete(id: id)).right, deleted);

        if (deleted) {
          verifyInOrder([
            () => dataSource.delete(id: id),
            () => localDataSource.clear(),
          ]);
          verifyNoMoreInteractions(localDataSource);
        } else {
          verify(() => dataSource.delete(id: id)).called(1);
          verifyZeroInteractions(localDataSource);
        }
        verifyNoMoreInteractions(dataSource);
      });
    }

    test(
      'clears local storage only after remote deletion is confirmed',
      () async {
        final pending = Completer<DeleteDataSourceType>();
        when(() => dataSource.delete(id: id)).thenAnswer((_) => pending.future);

        final result = repository.delete(id: id);
        verifyZeroInteractions(localDataSource);
        pending.complete(const Right(true));

        expect((await result).right, isTrue);
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
        final result = repository.delete(id: id)..then((_) => completed = true);
        await clearing.future;
        expect(completed, isFalse);
        pending.complete();

        expect((await result).right, isTrue);
        expect(completed, isTrue);
      },
    );

    test('returns an unknown error when local clearing fails', () async {
      when(() => dataSource.delete(id: id))
          .thenAnswer((_) async => const Right(true));
      when(() => localDataSource.clear())
          .thenAnswer((_) async => throw StateError('storage unavailable'));

      final result = await repository.delete(id: id);

      expect(result.left.errors.single.title, 'Erro desconhecido');
      expect(
        result.left.errors.single.detail,
        'Não foi possível processar a resposta.',
      );
      verifyInOrder([
        () => dataSource.delete(id: id),
        () => localDataSource.clear(),
      ]);
      verifyNoMoreInteractions(dataSource);
      verifyNoMoreInteractions(localDataSource);
    });

    for (final operation in ['getById', 'update', 'delete']) {
      group(operation, () {
        late Future<Either<ErrorsEntity, Object>> Function() execute;

        setUp(() {
          execute = switch (operation) {
            'getById' => () => repository.getById(id: id),
            'update' => () => repository.update(id: id, name: 'Gabriel'),
            _ => () => repository.delete(id: id),
          };
        });

        test('preserves remote error details as domain errors', () async {
          when(() => dataSource.getById(id: id))
              .thenAnswer((_) async => const Left(errorsResponse));
          when(() => dataSource.update(id: id, name: 'Gabriel'))
              .thenAnswer((_) async => const Left(errorsResponse));
          when(() => dataSource.delete(id: id))
              .thenAnswer((_) async => const Left(errorsResponse));

          final result = await execute();

          expect(result.left, isA<ErrorsEntity>());
          expect(result.left.errors, hasLength(2));
          expect(result.left.errors.first.status, '422');
          expect(result.left.errors.first.title, 'Nome inválido');
          expect(result.left.errors.first.detail, 'Informe um nome válido.');
          expect(result.left.errors.first.pointer, '/data/attributes/name');
          expect(
            result.left.errors.last.detail,
            'Não foi possível atualizar o usuário.',
          );
          verifyZeroInteractions(localDataSource);
        });

        test('converts unexpected exceptions into an unknown error', () async {
          when(() => dataSource.getById(id: id))
              .thenAnswer((_) async => throw StateError('offline'));
          when(() => dataSource.update(id: id, name: 'Gabriel'))
              .thenAnswer((_) async => throw StateError('offline'));
          when(() => dataSource.delete(id: id))
              .thenAnswer((_) async => throw StateError('offline'));

          final result = await execute();

          expect(result.left.errors.single.title, 'Erro desconhecido');
          expect(
            result.left.errors.single.detail,
            'Não foi possível processar a resposta.',
          );
          verifyZeroInteractions(localDataSource);
        });
      });
    }
  });
}
