final class const SignUpResponse({required final String userId}) {
  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    return SignUpResponse(userId: data['id'] as String);
  }
}
