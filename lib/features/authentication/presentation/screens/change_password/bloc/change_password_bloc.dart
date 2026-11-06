import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_event.dart';
import 'package:cordato/features/authentication/presentation/screens/change_password/bloc/change_password_state.dart';

final class ChangePasswordBloc({
  required final IAuthenticationRepository repository,
}) extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  this : super(const ChangePasswordInitial()) {
    on<ChangePasswordEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(
    ChangePasswordEvent event,
    Emitter<ChangePasswordState> emit,
  ) async {
    switch (event) {
      case ChangePasswordSubmitted():
        if (!state.canSubmit) {
          return;
        }

        final passwordChanged = await _changePassword(event, emit);

        if (!passwordChanged) {
          return;
        }
      case ChangePasswordSignOutRetried():
        if (state is! ChangePasswordSignOutFailure) {
          return;
        }
    }

    await _signOut(emit);
  }

  Future<bool> _changePassword(
    ChangePasswordSubmitted event,
    Emitter<ChangePasswordState> emit,
  ) async {
    emit(const ChangePasswordSubmitting());

    try {
      await repository.changePassword(
        oldPassword: event.oldPassword,
        password: event.password,
        passwordConfirm: event.passwordConfirm,
      );

      return true;
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) {
        return false;
      }

      emit(ChangePasswordFailure(errors: error.errors));
    } on MissingAuthenticatedUserException catch (error) {
      if (isClosed || emit.isDone) {
        return false;
      }

      emit(ChangePasswordFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) {
        return false;
      }

      addError(error, stackTrace);
      emit(ChangePasswordFailure(errors: .unknown()));
    }

    return false;
  }

  Future<void> _signOut(Emitter<ChangePasswordState> emit) async {
    if (isClosed || emit.isDone) {
      return;
    }

    emit(const ChangePasswordSigningOut());

    try {
      await repository.signOut();
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) {
        return;
      }

      addError(error, stackTrace);
      emit(const ChangePasswordSignOutFailure());
      return;
    }

    if (isClosed || emit.isDone) {
      return;
    }

    emit(const ChangePasswordSuccess());
  }
}
