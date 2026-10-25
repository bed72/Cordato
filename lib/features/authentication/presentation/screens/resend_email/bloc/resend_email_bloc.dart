import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_event.dart';
import 'package:cordato/features/authentication/presentation/screens/resend_email/bloc/resend_email_state.dart';

import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/application/repositories/interface_authentication_repository.dart';

final class ResendEmailBloc({
  required final IAuthenticationRepository repository,
}) extends Bloc<ResendEmailEvent, ResendEmailState> {
  this : super(const ResendEmailInitial()) {
    on<ResendEmailSubmittedEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(
    ResendEmailSubmittedEvent event,
    Emitter<ResendEmailState> emit,
  ) async {
    if (!state.canSubmit) return;

    emit(const ResendEmailSubmitting());

    try {
      await repository.resendEmail(email: event.email);

      if (isClosed || emit.isDone) return;

      emit(const ResendEmailSuccess());
    } on AuthenticationException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(ResendEmailFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(ResendEmailFailure(errors: .unknown()));
    }
  }
}
