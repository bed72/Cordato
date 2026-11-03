sealed class PasswordRecoveryEvent {
  const PasswordRecoveryEvent();
}

final class const PasswordRecoverySubmitted({required final String email})
    extends PasswordRecoveryEvent {}

final class const PasswordRecoveryResendRequested({required final String email})
    extends PasswordRecoveryEvent {}
