import 'package:cordato/features/user/domain/entities/user_entity.dart';

final class const UserResponse({
  required final String name,
  final String? avatar,
}) {
  factory UserResponse.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as String;

    return UserResponse(
      name: json['name'] as String,
      avatar: avatar.isEmpty ? null : avatar,
    );
  }
}

extension UserResponseToEntity on UserResponse {
  UserEntity toEntity() => UserEntity(name: name, avatar: avatar);
}
