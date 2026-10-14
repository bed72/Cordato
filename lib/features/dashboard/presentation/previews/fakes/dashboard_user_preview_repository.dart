import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/domain/repositories/interface_user_repository.dart';

final class DashboardUserPreviewRepository({final ErrorsEntity? failure})
    implements IUserRepository {
  @override
  Future<GetByIdRepositoryType> getById() async => failure != null
      ? Left(failure!)
      : const Right(
          UserEntity(
            name: 'Gabriel',
            status: 'active',
            id: 'preview-user',
            email: 'preview@example.com',
          ),
        );

  @override
  Future<DeleteRepositoryType> delete() async => Left(.unknown());

  @override
  Future<UpdateRepositoryType> update({String? name, String? avatar}) async =>
      Left(.unknown());
}
