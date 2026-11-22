import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_state.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_event.dart';

import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';

final class ExpenseBloc({required final IExpenseRepository repository})
    extends Bloc<ExpenseEvent, ExpenseState> {
  int _revision = 0;
  this : super(const ExpenseInitial()) {
    on<ExpenseRequestedEvent>(_load, transformer: restartable());
    on<ExpenseSubmittedEvent>(
      _submit,
      transformer: (events, mapper) => restartable<ExpenseSubmittedEvent>()(
        events.where((_) => state.canSubmit),
        mapper,
      ),
    );
  }

  Future<void> _load(
    ExpenseRequestedEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    _revision++;
    final id = event.id;
    if (id == null) {
      emit(const ExpenseInitial());
      return;
    }
    emit(const ExpenseLoading());
    try {
      final expense = await repository.getById(id: id);
      if (isClosed || emit.isDone) return;
      emit(ExpenseReady(expense: expense));
    } on ExpenseException catch (error) {
      if (isClosed || emit.isDone) return;
      emit(ExpenseLoadFailure(errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;
      addError(error, stackTrace);
      emit(ExpenseLoadFailure(errors: .unknown()));
    }
  }

  Future<void> _submit(
    ExpenseSubmittedEvent event,
    Emitter<ExpenseState> emit,
  ) async {
    if (!state.canSubmit) return;
    final revision = _revision;
    final previous = state.expense;
    emit(ExpenseSubmitting(expense: previous));
    try {
      final expense = event.id == null
          ? await repository.create(
              category: event.category ?? .other,
              cents: event.cents!,
              description: event.description!,
              occurredOn: event.occurredOn,
            )
          : await repository.update(
              id: event.id!,
              category: event.category,
              cents: event.cents,
              description: event.description,
              occurredOn: event.occurredOn,
            );
      if (isClosed || emit.isDone) return;
      if (revision != _revision) return;
      emit(
        ExpenseSuccess(
          expense: expense,
          isEditing: event.id != null,
          keepFormOpen: event.id == null && event.keepFormOpen,
        ),
      );
    } on ExpenseException catch (error) {
      if (isClosed || emit.isDone) return;
      if (revision != _revision) return;
      emit(ExpenseSubmissionFailure(errors: error.errors, expense: previous));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;
      if (revision != _revision) return;
      addError(error, stackTrace);
      emit(ExpenseSubmissionFailure(errors: .unknown(), expense: previous));
    }
  }
}
