import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class SignUpState {
  const SignUpState();

  bool get isSubmitting => this is SignUpSubmitting;

  bool get canSubmit => this is SignUpInitial || this is SignUpFailure;
}

final class const SignUpInitial() extends SignUpState {}

final class const SignUpSubmitting() extends SignUpState {}

final class const SignUpSuccess({required final String email})
    extends SignUpState {}

final class const SignUpFailure({required final ErrorsEntity errors})
    extends SignUpState {}
