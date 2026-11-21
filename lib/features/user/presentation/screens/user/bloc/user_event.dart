sealed class UserEvent {
  const UserEvent();
}

final class const UserRequestedEvent() extends UserEvent {}

final class const UserAvatarSubmittedEvent({required final String seed})
    extends UserEvent {}
