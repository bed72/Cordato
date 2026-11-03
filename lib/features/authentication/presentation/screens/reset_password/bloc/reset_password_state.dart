import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class ResetPasswordState {
  const ResetPasswordState();

  bool get canSubmit =>
      this is ResetPasswordReady || this is ResetPasswordFailure;

  bool get isSubmitting => this is ResetPasswordSubmitting;
}

final class const ResetPasswordInitial() extends ResetPasswordState {}

final class const ResetPasswordPreparing() extends ResetPasswordState {}

final class const ResetPasswordReady() extends ResetPasswordState {}

final class const ResetPasswordSessionFailure() extends ResetPasswordState {}

final class const ResetPasswordSubmitting() extends ResetPasswordState {}

final class const ResetPasswordSuccess() extends ResetPasswordState {}

final class const ResetPasswordInvalid() extends ResetPasswordState {}

final class const ResetPasswordFailure({required final ErrorsEntity errors})
    extends ResetPasswordState {}
