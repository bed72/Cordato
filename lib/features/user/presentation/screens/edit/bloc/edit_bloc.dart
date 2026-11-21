import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/user/application/exceptions/user_exception.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_event.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

final class EditBloc({required final IUserRepository repository})
    extends Bloc<EditEvent, EditState> {
  this : super(const EditInitial()) {
    on<EditSubmittedEvent>(_execute, transformer: droppable());
  }

  Future<void> _execute(
    EditSubmittedEvent event,
    Emitter<EditState> emit,
  ) async {
    if (!state.canSubmit) return;
    emit(const EditSubmitting());

    try {
      final user = await repository.update(name: event.name);

      if (isClosed || emit.isDone) return;

      emit(EditSuccess(user: user));
    } on UserException catch (error) {
      if (isClosed || emit.isDone) return;

      emit(EditFailure(errors: error.errors));
    } on MissingAuthenticatedUserException catch (error) {
      if (isClosed || emit.isDone) {
        return;
      }

      emit(EditFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);

      emit(EditFailure(errors: .unknown()));
    }
  }
}
