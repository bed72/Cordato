final class const SessionResponse({
  required final String token,
  required final String userId,
}) {
  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    final root = json['record'] as Map<String, dynamic>;

    return SessionResponse(
      userId: root['id'] as String,
      token: json['token'] as String,
    );
  }
}
