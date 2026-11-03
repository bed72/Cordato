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
    final isInitialRequest = event is ResendEmailStartedEvent;
    if (event.email.isEmpty) return;
    if (isInitialRequest ? state is! ResendEmailInitial : !state.canSubmit) {
      return;
    }

    emit(const ResendEmailSubmitting());

    try {
      await repository.resendEmail(email: event.email);
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(
        ResendEmailFailure(
          errors: error.errors,
          isInitialRequest: isInitialRequest,
        ),
      );
      return;
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(
        ResendEmailFailure(
          errors: .unknown(),
          isInitialRequest: isInitialRequest,
        ),
      );
      return;
    }

    if (isClosed || emit.isDone) return;

    emit(ResendEmailSuccess(isInitialRequest: isInitialRequest));
    await emit.forEach<int>(
      EmailCooldown.ticks(),
      onData: (seconds) => seconds >= EmailCooldown.duration.inSeconds
          ? const ResendEmailReady()
          : ResendEmailCooldown(
              timeLeft: EmailCooldown.duration - Duration(seconds: seconds),
            ),
    );
  }
}
