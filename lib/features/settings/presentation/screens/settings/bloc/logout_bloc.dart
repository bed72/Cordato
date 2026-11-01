import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_state.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class LogoutBloc({required final IAuthenticationRepository repository})
    extends Bloc<LogoutEvent, LogoutState> {
  this : super(const LogoutInitial()) {
    on<LogoutRequestedEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(
    LogoutRequestedEvent event,
    Emitter<LogoutState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(const LogoutSubmitting());

    try {
      await repository.signOut();

      if (isClosed || emit.isDone) return;

      emit(const LogoutSuccess());
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(LogoutFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(LogoutFailure(errors: .unknown()));
    }
  }
}
