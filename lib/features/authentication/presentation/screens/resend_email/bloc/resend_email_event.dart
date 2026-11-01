sealed class const ResendEmailEvent({required final String email});

final class const ResendEmailStartedEvent({required super.email})
    extends ResendEmailEvent;

final class const ResendEmailSubmittedEvent({required super.email})
    extends ResendEmailEvent {}
