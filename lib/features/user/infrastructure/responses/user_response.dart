import 'package:cordato/features/user/domain/entities/user_entity.dart';

final class const UserResponse({
  required final String name,
  final String? avatar,
}) {
  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
    );
  }
}

extension UserResponseToEntity on UserResponse {
  UserEntity toEntity() => UserEntity(name: name, avatar: avatar);
}
