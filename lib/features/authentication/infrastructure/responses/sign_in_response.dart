final class const SignInResponse({
  required final String token,
  required final String userId,
  required final String tokenType,
  required final DateTime expiresAt,
}) {
  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final attributes = data['attributes'] as Map<String, dynamic>;

    return SignInResponse(
      userId: data['id'] as String,
      token: attributes['token'] as String,
      tokenType: attributes['token_type'] as String,
      expiresAt: .parse(attributes['expires_at'] as String),
    );
  }
}
