import 'package:cordato/features/dashboard/domain/entities/user_entity.dart';
import 'package:cordato/features/dashboard/infrastructure/clients/supabase_user_client.dart';

abstract interface class IUserDataSource {
  Future<UserEntity?> getUser();
}

final class UserDataSource implements IUserDataSource {
  final IUserClient _client;

  const UserDataSource({required this._client});

  @override
  Future<UserEntity?> getUser() => _client.getUser();
}
