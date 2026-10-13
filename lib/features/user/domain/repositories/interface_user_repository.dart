import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';

typedef DeleteRepositoryType = Either<ErrorsEntity, bool>;
typedef UpdateRepositoryType = Either<ErrorsEntity, UserEntity>;
typedef GetByIdRepositoryType = Either<ErrorsEntity, UserEntity>;

abstract interface class IUserRepository {
  Future<DeleteRepositoryType> delete();

  Future<GetByIdRepositoryType> getById();

  Future<UpdateRepositoryType> update({String? name, String? avatar});
}
