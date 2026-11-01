import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';
import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/presentation/bloc/session_event.dart';
import 'package:cordato/features/session/presentation/bloc/session_state.dart';

final class SessionBloc({required final ISessionRepository repository})
    extends Bloc<SessionEvent, SessionState> {
  this : super(const SessionInitial()) {
    on<SessionStartedEvent>(_observe, transformer: droppable());
  }

  Future<void> _observe(
    SessionStartedEvent event,
    Emitter<SessionState> emit,
  ) async {
    if (state is! SessionInitial) return;

    emit(const SessionLoading());

    try {
      final observation = emit.onEach<bool>(
        repository.sessionChanges,
        onData: (hasSession) {
          if (isClosed || emit.isDone) return;
          emit(
            hasSession
                ? const SessionAuthenticated()
                : const SessionUnauthenticated(),
          );
        },
        onError: (error, stackTrace) {
          if (isClosed || emit.isDone) return;
          addError(error, stackTrace);
          emit(const SessionFailure());
        },
      );

      await _load(emit);
      await observation;
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;
      addError(error, stackTrace);
      emit(const SessionFailure());
    }
  }

  Future<void> _load(Emitter<SessionState> emit) async {
    try {
      final hasSession = await repository.loadSession();
      if (isClosed || emit.isDone || state is! SessionLoading) return;

      emit(
        hasSession
            ? const SessionAuthenticated()
            : const SessionUnauthenticated(),
      );
    } on SessionException catch (error) {
      if (isClosed || emit.isDone || state is! SessionLoading) return;
      emit(SessionFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      if (state is SessionLoading) emit(const SessionFailure());
    }
  }
}
