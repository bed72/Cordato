import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class ResendEmailState {
  const ResendEmailState();

  bool get isSubmitting => this is ResendEmailSubmitting;

  bool get canSubmit => !isSubmitting;
}

final class const ResendEmailInitial() extends ResendEmailState {}

final class const ResendEmailSuccess() extends ResendEmailState {}

final class const ResendEmailSubmitting() extends ResendEmailState {}

final class const ResendEmailFailure({required final ErrorsEntity errors})
    extends ResendEmailState {}
