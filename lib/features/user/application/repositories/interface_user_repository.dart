import 'package:cordato/features/user/domain/entities/user_entity.dart';

abstract interface class IUserRepository {
  Future<UserEntity> get();

  Future<UserEntity> update({String? name, String? seed});
}
