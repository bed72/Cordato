import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/bloc/sign_in_state.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class SignInBloc({required final IAuthenticationRepository repository})
    extends Bloc<SignInEvent, SignInState> {
  this : super(const SignInInitial()) {
    on<SignInSubmittedEvent>(_submit, transformer: droppable());
  }

  Future<void> _submit(
    SignInSubmittedEvent event,
    Emitter<SignInState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(const SignInSubmitting());

    try {
      await repository.signIn(email: event.email, password: event.password);

      if (isClosed || emit.isDone) return;

      emit(const SignInSuccess());
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(SignInFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(SignInFailure(errors: .unknown()));
    }
  }
}
