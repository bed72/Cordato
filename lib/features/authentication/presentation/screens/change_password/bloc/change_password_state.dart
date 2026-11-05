import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class ChangePasswordState {
  const ChangePasswordState();

  bool get canSubmit =>
      this is ChangePasswordInitial || this is ChangePasswordFailure;

  bool get isBusy =>
      this is ChangePasswordSubmitting || this is ChangePasswordSigningOut;

  bool get passwordChanged =>
      this is ChangePasswordSigningOut ||
      this is ChangePasswordSignOutFailure ||
      this is ChangePasswordSuccess;
}

final class const ChangePasswordInitial() extends ChangePasswordState {}

final class const ChangePasswordSubmitting() extends ChangePasswordState {}

final class const ChangePasswordSigningOut() extends ChangePasswordState {}

final class const ChangePasswordSignOutFailure() extends ChangePasswordState {}

final class const ChangePasswordSuccess() extends ChangePasswordState {}

final class const ChangePasswordFailure({required final ErrorsEntity errors})
    extends ChangePasswordState {}
