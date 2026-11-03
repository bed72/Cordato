import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/exceptions/password_reset_token_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/reset_password/bloc/reset_password_state.dart';

final class ResetPasswordBloc({
  required final IAuthenticationRepository repository,
}) extends Bloc<ResetPasswordEvent, ResetPasswordState> {
  this : super(const ResetPasswordInitial()) {
    on<ResetPasswordEvent>(
      _execute,
      transformer: (events, mapper) => restartable<ResetPasswordEvent>()(
        events.where(
          (event) => event is ResetPasswordOpened || state.canSubmit,
        ),
        mapper,
      ),
    );
  }

  Future<void> _execute(
    ResetPasswordEvent event,
    Emitter<ResetPasswordState> emit,
  ) async {
    switch (event) {
      case ResetPasswordOpened(:final hasToken):
        emit(const ResetPasswordPreparing());
        try {
          await repository.signOut();
        } catch (error, stackTrace) {
          if (isClosed || emit.isDone) return;
          addError(error, stackTrace);
          emit(const ResetPasswordSessionFailure());
          return;
        }
        if (isClosed || emit.isDone) return;
        emit(
          hasToken ? const ResetPasswordReady() : const ResetPasswordInvalid(),
        );
      case ResetPasswordSubmitted(
        :final token,
        :final password,
        :final passwordConfirm,
      ):
        if (token.isEmpty) {
          emit(const ResetPasswordInvalid());
          return;
        }
        emit(const ResetPasswordSubmitting());
        try {
          await repository.confirmPasswordReset(
            token: token,
            password: password,
            passwordConfirm: passwordConfirm,
          );
        } on PasswordResetTokenException {
          if (isClosed || emit.isDone) return;
          emit(const ResetPasswordInvalid());
          return;
        } on AuthenticationException catch (error) {
          if (isClosed || emit.isDone) return;
          emit(ResetPasswordFailure(errors: error.errors));
          return;
        } catch (error, stackTrace) {
          if (isClosed || emit.isDone) return;
          addError(error, stackTrace);
          emit(ResetPasswordFailure(errors: .unknown()));
          return;
        }
        if (isClosed || emit.isDone) return;
        emit(const ResetPasswordSuccess());
    }
  }
}
