sealed class ResetPasswordEvent {
  const ResetPasswordEvent();
}

final class const ResetPasswordOpened({required final bool hasToken})
    extends ResetPasswordEvent {}

final class const ResetPasswordSubmitted({
  required final String token,
  required final String password,
  required final String passwordConfirm,
}) extends ResetPasswordEvent {}
