import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_event.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_state.dart';

final class ExpenseSuggestionsBloc({
  required final IExpenseRepository repository,
}) extends Bloc<ExpenseSuggestionsEvent, ExpenseSuggestionsState> {
  int _generation = 0;

  static const minimumQueryLength = 3;
  static const debounce = Duration(milliseconds: 300);

  this : super(const ExpenseSuggestionsIdle()) {
    on<ExpenseSuggestionsEvent>(_handle, transformer: concurrent());
  }

  Future<void> _handle(
    ExpenseSuggestionsEvent event,
    Emitter<ExpenseSuggestionsState> emit,
  ) async {
    final revision = event.revision;
    final generation = ++_generation;
    if (event is! ExpenseSuggestionsRequested ||
        event.query.length < minimumQueryLength) {
      emit(ExpenseSuggestionsIdle(revision: revision));
      return;
    }

    emit(ExpenseSuggestionsLoading(revision: revision));

    await Future<void>.delayed(debounce);
    if (isClosed || emit.isDone || generation != _generation) return;

    try {
      final suggestions = await repository.suggestions(query: event.query);

      if (isClosed || emit.isDone || generation != _generation) return;

      emit(
        ExpenseSuggestionsSuccess(revision: revision, suggestions: suggestions),
      );
    } on ExpenseException catch (error) {
      if (isClosed || emit.isDone || generation != _generation) return;

      emit(ExpenseSuggestionsFailure(revision: revision, errors: error.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone || generation != _generation) return;

      addError(error, stackTrace);

      emit(ExpenseSuggestionsFailure(revision: revision, errors: .unknown()));
    }
  }
}
