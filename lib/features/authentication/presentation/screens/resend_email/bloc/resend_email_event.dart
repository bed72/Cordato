sealed class ResendEmailEvent {
  const ResendEmailEvent();
}

final class const ResendEmailStartedEvent() extends ResendEmailEvent {}

final class const ResendEmailSubmittedEvent({required final String email})
    extends ResendEmailEvent {}
