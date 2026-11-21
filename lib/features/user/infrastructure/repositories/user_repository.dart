import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_mapper.dart';
import 'package:cordato/features/core/infrastructure/clients/pocketbase/pocketbase_extension.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/user/infrastructure/responses/user_response.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class UserRepository({required final PocketBase pocketBase})
    implements IUserRepository {
  @override
  Future<UserEntity> getById() async {
    final id = pocketBase.userId();

    try {
      final user = await pocketBase.collection('users').getOne(id);

      return UserResponse.fromJson(user.toJson()).toEntity();
    } on ClientException catch (exception) {
      throw UserException(errors: PocketBaseMapper.fromException(exception));
    }
  }

  @override
  Future<UserEntity> update({String? name, String? avatar}) async {
    final id = pocketBase.userId();

    try {
      final user = await pocketBase
          .collection('users')
          .update(id, body: {'name': ?name, 'avatar': ?avatar});

      return UserResponse.fromJson(user.toJson()).toEntity();
    } on ClientException catch (exception) {
      throw UserException(errors: PocketBaseMapper.fromException(exception));
    }
  }

  @override
  Future<void> delete() async {
    final id = pocketBase.userId();

    try {
      await pocketBase.collection('users').delete(id);
    } on ClientException catch (exception) {
      throw UserException(errors: PocketBaseMapper.fromException(exception));
    }
  }
}
