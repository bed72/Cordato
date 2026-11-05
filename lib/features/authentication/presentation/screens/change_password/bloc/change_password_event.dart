sealed class ChangePasswordEvent {
  const ChangePasswordEvent();
}

final class const ChangePasswordSubmitted({
  required final String password,
  required final String oldPassword,
  required final String passwordConfirm,
}) extends ChangePasswordEvent {}

final class const ChangePasswordSignOutRetried() extends ChangePasswordEvent {}
