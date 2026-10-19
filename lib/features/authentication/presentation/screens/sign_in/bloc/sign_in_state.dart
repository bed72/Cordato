import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class SignInState {
  const SignInState();

  bool get isSubmitting => this is SignInSubmitting;

  bool get canSubmit => this is SignInInitial || this is SignInFailure;
}

final class const SignInSuccess() extends SignInState {}

final class const SignInInitial() extends SignInState {}

final class const SignInSubmitting() extends SignInState {}

final class const SignInFailure({required final ErrorsEntity errors})
    extends SignInState {}
