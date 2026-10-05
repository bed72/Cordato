import 'package:cordato/features/core/domain/either.dart';
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
  Future<DeleteRepositoryType> delete({required String id}) async {
    try {
      final data = await _remoteDataSource.delete(id: id);

      if (data case Left(:final value)) return Left(value.toEntity());
      if (!data.right) return const Right(false);

      await _localDataSource.clear();

      return const Right(true);
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<GetByIdRepositoryType> getById({required String id}) async {
    try {
      final data = await _remoteDataSource.getById(id: id);

      return data.either(
        (errors) => errors.toEntity(),
        (user) => user.toEntity(),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }

  @override
  Future<UpdateRepositoryType> update({
    required String id,
    String? name,
  }) async {
    try {
      final data = await _remoteDataSource.update(id: id, name: name);

      return data.either(
        (errors) => errors.toEntity(),
        (user) => user.toEntity(),
      );
    } catch (_) {
      return Left(.unknown());
    }
  }
}
