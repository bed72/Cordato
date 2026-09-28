import 'package:cordato/features/dashboard/domain/entities/user_entity.dart';

abstract interface class IUserClient {
  Future<UserEntity?> getUser();
}

final class const UserClient() implements IUserClient {
  @override
  Future<UserEntity?> getUser() async {
    return UserEntity(name: 'Bed', email: 'developer.bed@gmail.com');
  }
}
