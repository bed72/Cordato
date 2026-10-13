import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/user/infrastructure/responses/user_response.dart';
import 'package:cordato/features/user/infrastructure/local/user_local_data_source.dart';
import 'package:cordato/features/user/infrastructure/remoto/user_remote_data_source.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class UserRepository({
  required final IUserLocalDataSource _localDataSource,
  required final IUserRemoteDataSource _remoteDataSource,
}) implements IUserRepository {
  @override
  Future<GetByIdRepositoryType> getById() => _withId((id) async {
    final data = await _remoteDataSource.getById(id: id);

    return data.either(
      (errors) => errors.toEntity(),
      (user) => user.toEntity(),
    );
  });

  @override
  Future<DeleteRepositoryType> delete() => _withId((id) async {
    final data = await _remoteDataSource.delete(id: id);

    if (data case Left(:final value)) return Left(value.toEntity());
    if (!data.right) return const Right(false);

    await _localDataSource.clear();

    return const Right(true);
  });

  @override
  Future<UpdateRepositoryType> update({String? name, String? avatar}) =>
      _withId((id) async {
        final data = await _remoteDataSource.update(
          id: id,
          name: name,
          avatar: avatar,
        );

        return data.either(
          (errors) => errors.toEntity(),
          (user) => user.toEntity(),
        );
      });

  ErrorsEntity get _error => ErrorsEntity(
    errors: [
      ErrorEntity(
        title: 'Usuário não identificado',
        detail: 'Não foi possível identificar o usuário atual.',
      ),
    ],
  );

  Future<Either<ErrorsEntity, T>> _withId<T>(
    Future<Either<ErrorsEntity, T>> Function(String id) execute,
  ) async {
    try {
      final id = await _localDataSource.getId();

      if (id == null || id.trim().isEmpty) return Left(_error);

      return await execute(id);
    } catch (_) {
      return Left(.unknown());
    }
  }
}
