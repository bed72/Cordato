sealed class SessionState {
  const SessionState();
}

final class const SessionInitial() extends SessionState {}

final class const SessionLoading() extends SessionState {}

final class const SessionAuthenticated() extends SessionState {}

final class const SessionUnauthenticated() extends SessionState {}

final class const SessionFailure() extends SessionState {}
