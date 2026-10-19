sealed class SignInEvent {
  const SignInEvent();
}

final class const SignInSubmittedEvent({
  required final String email,
  required final String password,
}) extends SignInEvent {}
