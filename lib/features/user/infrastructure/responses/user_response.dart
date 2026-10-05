import 'package:cordato/features/user/domain/entities/user_entity.dart';

final class const UserResponse({
  required final String id,
  required final String name,
  required final String email,
  required final String status,
}) {
  factory UserResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final attributes = data['attributes'] as Map<String, dynamic>;

    return UserResponse(
      id: data['id'] as String,
      name: attributes['name'] as String,
      email: attributes['email'] as String,
      status: attributes['status'] as String,
    );
  }
}

extension UserResponseToEntity on UserResponse {
  UserEntity toEntity() =>
      UserEntity(id: id, name: name, email: email, status: status);
}
