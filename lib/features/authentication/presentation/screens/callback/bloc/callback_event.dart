sealed class CallbackEvent {
  const CallbackEvent();
}

final class const CallbackRequestedEvent({required final String? token})
    extends CallbackEvent {}
