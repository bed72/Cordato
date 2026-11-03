import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

import 'package:cordato/features/authentication/presentation/email_cooldown.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_event.dart';
import 'package:cordato/features/authentication/presentation/screens/password_recovery/bloc/password_recovery_state.dart';

final class PasswordRecoveryBloc({
  required final IAuthenticationRepository repository,
}) extends Bloc<PasswordRecoveryEvent, PasswordRecoveryState> {
  this : super(const PasswordRecoveryInitial()) {
    on<PasswordRecoveryEvent>(_send, transformer: droppable());
  }

  Future<void> _send(
    PasswordRecoveryEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) async {
    if (!state.canSubmit) return;
    final previousEmail = state.sentEmail;
    final email = switch (event) {
      PasswordRecoverySubmitted(:final email) when previousEmail == null =>
        email,
      PasswordRecoveryResendRequested(:final email)
          when previousEmail != null =>
        email,
      _ => null,
    };
    if (email == null || email.isEmpty) return;

    emit(PasswordRecoverySubmitting(previousEmail: previousEmail));

    try {
      await repository.requestPasswordReset(email: email);
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;
      emit(
        PasswordRecoveryFailure(
          errors: error.errors,
          previousEmail: previousEmail,
        ),
      );
      return;
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;
      addError(error, stackTrace);
      emit(
        PasswordRecoveryFailure(
          errors: .unknown(),
          previousEmail: previousEmail,
        ),
      );
      return;
    }

    if (isClosed || emit.isDone) return;

    emit(PasswordRecoverySent(email: email, remaining: EmailCooldown.duration));

    await emit.forEach<int>(
      EmailCooldown.ticks(),
      onData: (seconds) => PasswordRecoverySent(
        email: email,
        remaining: EmailCooldown.duration - Duration(seconds: seconds),
      ),
    );
  }
}
