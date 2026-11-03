import 'package:cordato/features/user/domain/entities/user_entity.dart';

final class const UserResponse({
  required final String id,
  required final String name,
  required final String email,
  final String? avatar,
}) {
  factory UserResponse.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as String;

    return UserResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatar: avatar.isEmpty ? null : avatar,
    );
  }
}

extension UserResponseToEntity on UserResponse {
  UserEntity toEntity() =>
      UserEntity(id: id, name: name, email: email, avatar: avatar);
}
