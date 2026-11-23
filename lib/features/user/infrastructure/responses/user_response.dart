import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/user/domain/entities/user_entity.dart';

final class const UserResponse({
  required final int id,
  required final String name,
  required final String seed,
}) {
  factory UserResponse.fromRecord(ProfilesTableData profile) {
    return UserResponse(id: profile.id, name: profile.name, seed: profile.seed);
  }
}

extension UserResponseToEntity on UserResponse {
  UserEntity toEntity() => UserEntity(id: id, name: name, seed: seed);
}
