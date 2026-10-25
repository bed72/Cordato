import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_event.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/bloc/sign_up_state.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class SignUpBloc({required final IAuthenticationRepository repository})
    extends Bloc<SignUpEvent, SignUpState> {
  this : super(const SignUpInitial()) {
    on<SignUpSubmittedEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(
    SignUpSubmittedEvent event,
    Emitter<SignUpState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(const SignUpSubmitting());

    try {
      await repository.signUp(email: event.email, password: event.password);

      if (isClosed || emit.isDone) return;

      emit(SignUpSuccess(email: event.email));
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(SignUpFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(SignUpFailure(errors: .unknown()));
    }
  }
}
