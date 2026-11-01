final class const SignInResponse({
  required final String token,
  required final String userId,
}) {
  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    final root = json['record'] as Map<String, dynamic>;

    return SignInResponse(
      userId: root['id'] as String,
      token: json['token'] as String,
    );
  }
}
