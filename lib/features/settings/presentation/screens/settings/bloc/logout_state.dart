import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class LogoutState {
  const LogoutState();

  bool get isSubmitting => this is LogoutSubmitting;

  bool get canSubmit => this is LogoutInitial || this is LogoutFailure;
}

final class const LogoutInitial() extends LogoutState {}

final class const LogoutSuccess() extends LogoutState {}

final class const LogoutSubmitting() extends LogoutState {}

final class const LogoutFailure({required final ErrorsEntity errors})
    extends LogoutState {}
