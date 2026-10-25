sealed class CallbackState {
  const CallbackState();
}

final class const CallbackInitial() extends CallbackState {}

final class const CallbackSuccess() extends CallbackState {}

final class const CallbackInvalid() extends CallbackState {}

final class const CallbackFailure() extends CallbackState {}

final class const CallbackConfirming() extends CallbackState {}
