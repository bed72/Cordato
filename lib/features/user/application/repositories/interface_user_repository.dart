import 'package:cordato/features/user/domain/entities/user_entity.dart';

abstract interface class IUserRepository {
  Future<void> delete();

  Future<UserEntity> getById();

  Future<UserEntity> update({String? name, String? avatar});
}
