import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_event.dart';
import 'package:cordato/features/authentication/presentation/screens/code/bloc/code_state.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class CodeBloc({required final IAuthenticationRepository repository})
    extends Bloc<CodeEvent, CodeState> {
  this : super(const CodeInitial()) {
    on<CodeSubmittedEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(
    CodeSubmittedEvent event,
    Emitter<CodeState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(const CodeSubmitting());

    try {
      await repository.confirmCode(userId: event.userId, code: event.code);

      if (isClosed || emit.isDone) return;

      emit(const CodeSuccess());
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(CodeFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(CodeFailure(errors: .unknown()));
    }
  }
}
