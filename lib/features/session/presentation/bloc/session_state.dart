import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class SessionState {
  const SessionState();
}

final class const SessionInitial() extends SessionState {}

final class const SessionLoading() extends SessionState {}

final class const SessionAuthenticated() extends SessionState {}

final class const SessionUnauthenticated() extends SessionState {}

final class const SessionFailure({final ErrorsEntity? errors})
    extends SessionState {}
