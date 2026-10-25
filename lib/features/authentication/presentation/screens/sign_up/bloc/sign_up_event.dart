sealed class SignUpEvent {
  const SignUpEvent();
}

final class const SignUpSubmittedEvent({
  required final String email,
  required final String password,
}) extends SignUpEvent {}
