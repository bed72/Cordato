import 'package:deep_pick/deep_pick.dart';

final class const SignUpResponse({required final String userId}) {
  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    final userId = pick(json, 'data', 'id').asStringOrThrow();

    return SignUpResponse(userId: userId);
  }
}
