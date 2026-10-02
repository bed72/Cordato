final class const SignUpResponse({required final String userId}) {
  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    final root = json['data'] as Map<String, dynamic>;
    final userId = root['id'] as String;

    return SignUpResponse(userId: userId);
  }
}
