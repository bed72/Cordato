final class const CodeArguments({
  required final String email,
  required final String userId,
}) {
  bool get isValid => email.trim().isNotEmpty && userId.trim().isNotEmpty;
}
