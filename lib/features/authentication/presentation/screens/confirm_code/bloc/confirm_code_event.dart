sealed class ConfirmCodeEvent {
  const ConfirmCodeEvent();
}

final class const ConfirmCodeSubmittedEvent({
  required final String code,
  required final String userId,
}) extends ConfirmCodeEvent {}
