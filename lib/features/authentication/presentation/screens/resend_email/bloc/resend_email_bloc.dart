import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cordato/features/authentication/presentation/email_cooldown.dart';

import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class ResendEmailBloc({
  required final IAuthenticationRepository repository,
}) extends Bloc<ResendEmailEvent, ResendEmailState> {
  this : super(const ResendEmailInitial()) {
    on<ResendEmailEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(
    ResendEmailEvent event,
    Emitter<ResendEmailState> emit,
  ) async {
    switch (event) {
      case ResendEmailStartedEvent():
        if (state is! ResendEmailInitial) return;

        emit(const ResendEmailCooldown(timeLeft: EmailCooldown.duration));
        await _cooldown(emit);
      case ResendEmailSubmittedEvent():
        await _requestCode(event, emit);
    }
  }

  Future<void> _requestCode(
    ResendEmailSubmittedEvent event,
    Emitter<ResendEmailState> emit,
  ) async {
    if (!state.canSubmit || event.email.isEmpty) return;

    emit(const ResendEmailSubmitting());

    final String userId;
    try {
      userId = await repository.requestCode(email: event.email);
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(ResendEmailFailure(errors: error.errors));

      return;
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(ResendEmailFailure(errors: .unknown()));

      return;
    }

    if (isClosed || emit.isDone) return;

    emit(ResendEmailSuccess(userId: userId));
    await _cooldown(emit);
  }

  Future<void> _cooldown(Emitter<ResendEmailState> emit) => emit.forEach<int>(
    EmailCooldown.ticks(),
    onData: (seconds) => seconds >= EmailCooldown.duration.inSeconds
        ? const ResendEmailReady()
        : ResendEmailCooldown(
            timeLeft: EmailCooldown.duration - Duration(seconds: seconds),
          ),
  );
}
