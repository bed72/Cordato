import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_event.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_state.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

final class ExpenseMetricsBloc({required final IMetricsRepository repository})
    extends Bloc<ExpenseMetricsEvent, ExpenseMetricsState> {
  this : super(const ExpenseMetricsInitial()) {
    on<ExpenseMetricsRequestedEvent>(_execute, transformer: restartable());
  }

  Future<void> _execute(
    ExpenseMetricsRequestedEvent event,
    Emitter<ExpenseMetricsState> emit,
  ) async {
    emit(const ExpenseMetricsLoading());

    try {
      final data = await repository.getExpenses(
        groupBy: event.groupBy,
        endDate: event.endDate,
        startDate: event.startDate,
      );

      if (isClosed || emit.isDone) return;

      emit(ExpenseMetricsSuccess(data: data));
    } on MetricsException catch (exception) {
      if (isClosed || emit.isDone) return;

      emit(ExpenseMetricsFailure(errors: exception.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);
      emit(ExpenseMetricsFailure(errors: ErrorsEntity.unknown()));
    }
  }
}
