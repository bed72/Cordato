import 'package:deep_pick/deep_pick.dart';

import 'package:cordato/features/authentication/domain/entities/session_entity.dart';

final class const SignInResponse({
  required final String token,
  required final String userId,
  required final DateTime expiresAt,
}) {
  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    final token = pick(json, 'data', 'attributes', 'token').asStringOrThrow();
    final expiresAt = pick(
      json,
      'data',
      'attributes',
      'expires_at',
    ).asDateTimeOrThrow();
    final userId = pick(
      json,
      'data',
      'relationships',
      'user',
      'data',
      'id',
    ).asStringOrThrow();

    return SignInResponse(token: token, userId: userId, expiresAt: expiresAt);
  }
}

extension SignInResponseToEntity on SignInResponse {
  SessionEntity toEntity() =>
      SessionEntity(token: token, userId: userId, expiresAt: expiresAt);
}
