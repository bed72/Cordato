import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class ConfirmCodeState {
  const ConfirmCodeState();

  bool get isSubmitting => this is ConfirmCodeSubmitting;

  bool get canSubmit =>
      this is ConfirmCodeInitial || this is ConfirmCodeFailure;
}

final class const ConfirmCodeInitial() extends ConfirmCodeState {}

final class const ConfirmCodeSuccess() extends ConfirmCodeState {}

final class const ConfirmCodeSubmitting() extends ConfirmCodeState {}

final class const ConfirmCodeFailure({required final ErrorsEntity errors})
    extends ConfirmCodeState {}
