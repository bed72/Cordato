final class PasswordResetTokenValidation {
  const PasswordResetTokenValidation();

  String? call(Uri uri) => switch (uri.queryParametersAll['token']) {
    [final String token] when token.trim().isNotEmpty => token,
    _ => null,
  };
}
