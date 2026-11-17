import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/presentation/screens/confirm_code/bloc/confirm_code_event.dart';
import 'package:cordato/features/authentication/presentation/screens/confirm_code/bloc/confirm_code_state.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class ConfirmCodeBloc({
  required final IAuthenticationRepository repository,
}) extends Bloc<ConfirmCodeEvent, ConfirmCodeState> {
  this : super(const ConfirmCodeInitial()) {
    on<ConfirmCodeSubmittedEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(
    ConfirmCodeSubmittedEvent event,
    Emitter<ConfirmCodeState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(const ConfirmCodeSubmitting());

    try {
      await repository.confirmCode(userId: event.userId, code: event.code);

      if (isClosed || emit.isDone) return;

      emit(const ConfirmCodeSuccess());
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(ConfirmCodeFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(ConfirmCodeFailure(errors: .unknown()));
    }
  }
}
