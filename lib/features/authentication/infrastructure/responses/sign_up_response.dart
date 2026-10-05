final class const SignUpResponse({required final String id}) {
  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    final root = json['data'] as Map<String, dynamic>;

    return SignUpResponse(id: root['id'] as String);
  }
}
