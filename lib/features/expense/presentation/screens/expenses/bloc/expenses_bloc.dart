import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_event.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_state.dart';

final class ExpensesBloc({required final IExpenseRepository repository})
    extends Bloc<ExpensesEvent, ExpensesState> {
  int _revision = 0;
  ExpensesRequestedEvent? _pendingQuery;

  this : super(ExpensesInitial(data: ExpensesData())) {
    on<ExpensesRequestedEvent>(_refresh, transformer: restartable());
    on<ExpensesNextPageRequestedEvent>(
      _next,
      transformer: (events, mapper) =>
          restartable<ExpensesNextPageRequestedEvent>()(
            events.where((_) => !state.isBusy && state.data.nextPage != null),
            mapper,
          ),
    );
    on<ExpensesDeleteRequestedEvent>(_delete, transformer: droppable());
    on<ExpensesUpdatedEvent>(_update);
  }

  Future<void> _refresh(
    ExpensesRequestedEvent event,
    Emitter<ExpensesState> emit,
  ) async {
    final previous = state.data;
    final sameFilters =
        previous.category == event.category &&
        previous.from == event.from &&
        previous.to == event.to;
    if (state is ExpensesDeleting) {
      if (!sameFilters || _pendingQuery != null) _pendingQuery = event;
      return;
    }
    final data = ExpensesData(
      items: sameFilters ? previous.items : [],
      nextPage: sameFilters ? previous.nextPage : null,
      hasLoaded: sameFilters && previous.hasLoaded,
      category: event.category,
      from: event.from,
      to: event.to,
    );
    await _load(data, true, ++_revision, emit);
  }

  Future<void> _next(
    ExpensesNextPageRequestedEvent event,
    Emitter<ExpensesState> emit,
  ) async {
    if (state.isBusy || state.data.nextPage == null) return;
    await _load(state.data, false, _revision, emit);
  }

  Future<void> _load(
    ExpensesData data,
    bool refresh,
    int revision,
    Emitter<ExpensesState> emit,
  ) async {
    emit(ExpensesLoading(data: data, refresh: refresh));
    try {
      final page = await repository.get(
        pageSize: 20,
        category: data.category,
        from: data.from,
        to: data.to,
        page: refresh ? 1 : data.nextPage!,
      );
      if (isClosed || emit.isDone || revision != _revision) return;
      final items = <String, ExpenseEntity>{
        for (final item in refresh ? <ExpenseEntity>[] : data.items)
          item.id: item,
        for (final item in page.items) item.id: item,
      };
      emit(
        ExpensesReady(
          data: ExpensesData(
            items: _sorted(items.values),
            nextPage: page.nextPage,
            category: data.category,
            from: data.from,
            to: data.to,
            hasLoaded: true,
          ),
        ),
      );
    } on ExpenseException catch (error) {
      if (isClosed || emit.isDone || revision != _revision) return;
      emit(ExpensesFailure(data: data, errors: error.errors, refresh: refresh));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone || revision != _revision) return;
      addError(error, stackTrace);
      emit(ExpensesFailure(data: data, errors: .unknown(), refresh: refresh));
    }
  }

  Future<void> _delete(
    ExpensesDeleteRequestedEvent event,
    Emitter<ExpensesState> emit,
  ) async {
    if (state.isBusy) return;
    final data = state.data;
    emit(ExpensesDeleting(data: data, id: event.id));
    try {
      await repository.delete(id: event.id);
      if (isClosed || emit.isDone) return;
      emit(
        ExpensesDeleted(
          id: event.id,
          data: _withItems(
            data,
            data.items.where((item) => item.id != event.id),
          ),
        ),
      );
    } on ExpenseException catch (error) {
      if (isClosed || emit.isDone) return;
      emit(
        ExpensesDeleteFailure(data: data, id: event.id, errors: error.errors),
      );
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;
      addError(error, stackTrace);
      emit(ExpensesDeleteFailure(data: data, id: event.id, errors: .unknown()));
    } finally {
      final query = _pendingQuery;
      _pendingQuery = null;
      if (query != null && !isClosed && !emit.isDone) add(query);
    }
  }

  void _update(ExpensesUpdatedEvent event, Emitter<ExpensesState> emit) {
    if (state.isBusy) return;
    final data = state.data;
    final expense = event.expense;
    if (!data.items.any((item) => item.id == expense.id)) return;
    final day = _day(expense.occurredOn);
    final matches =
        (data.category == null || expense.category.value == data.category) &&
        (data.from == null || !day.isBefore(_day(data.from!))) &&
        (data.to == null || !day.isAfter(_day(data.to!)));
    emit(
      ExpensesReady(
        data: _withItems(data, [
          for (final item in data.items)
            if (item.id != expense.id) item else if (matches) expense,
        ]),
      ),
    );
  }

  DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);
  List<ExpenseEntity> _sorted(Iterable<ExpenseEntity> items) {
    final indexed = items.indexed.toList();
    indexed.sort((a, b) {
      final byDay = _day(b.$2.occurredOn).compareTo(_day(a.$2.occurredOn));
      return byDay == 0 ? a.$1.compareTo(b.$1) : byDay;
    });
    return indexed.map((entry) => entry.$2).toList();
  }

  ExpensesData _withItems(ExpensesData data, Iterable<ExpenseEntity> items) =>
      ExpensesData(
        items: _sorted(items),
        nextPage: data.nextPage,
        category: data.category,
        from: data.from,
        to: data.to,
        hasLoaded: data.hasLoaded,
      );
}
