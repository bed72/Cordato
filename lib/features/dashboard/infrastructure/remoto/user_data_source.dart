import 'package:cordato/features/dashboard/domain/entities/user_entity.dart';
import 'package:cordato/features/dashboard/infrastructure/clients/supabase_user_client.dart';

abstract interface class IUserDataSource {
  Future<UserEntity?> getUser();
}

final class const UserDataSource({required final IUserClient _client})
    implements IUserDataSource {
  @override
  Future<UserEntity?> getUser() => _client.getUser();
}
