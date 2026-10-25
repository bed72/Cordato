sealed class EditEvent {
  const EditEvent();
}

final class const EditSubmittedEvent({required final String name})
    extends EditEvent {}
