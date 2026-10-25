import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_event.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class CallbackBloc({required final IAuthenticationRepository repository})
    extends Bloc<CallbackEvent, CallbackState> {
  this : super(const CallbackInitial()) {
    on<CallbackRequestedEvent>(_execute, transformer: restartable());
  }

  Future<void> _execute(
    CallbackRequestedEvent event,
    Emitter<CallbackState> emit,
  ) async {
    emit(const CallbackConfirming());

    final url = event.verificationUrl;
    if (url == null || url.isEmpty) {
      emit(const CallbackInvalid());
      return;
    }

    try {
      final status = await repository.confirmEmail(url);

      if (isClosed || emit.isDone) return;

      emit(switch (status) {
        .success => const CallbackSuccess(),
        .invalid => const CallbackInvalid(),
        .failure => const CallbackFailure(),
      });
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(const CallbackFailure());
    }
  }
}
