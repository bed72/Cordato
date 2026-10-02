import 'package:cordato/features/authentication/domain/entities/session_entity.dart';

final class const SignInResponse({
  required final String token,
  required final String userId,
  required final DateTime expiresAt,
}) {
  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    final root = json['data'] as Map<String, dynamic>;
    final attributes = root['attributes'] as Map<String, dynamic>;
    final relationships = root['relationships'] as Map<String, dynamic>;
    final user = relationships['user'] as Map<String, dynamic>;
    final data = user['data'] as Map<String, dynamic>;

    return SignInResponse(
      userId: data['id'] as String,
      token: attributes['token'] as String,
      expiresAt: DateTime.parse(attributes['expires_at'] as String),
    );
  }
}

extension SignInResponseToEntity on SignInResponse {
  SessionEntity toEntity() =>
      SessionEntity(token: token, userId: userId, expiresAt: expiresAt);
}
