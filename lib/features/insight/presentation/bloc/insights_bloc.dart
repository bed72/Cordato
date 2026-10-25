import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/insight/presentation/bloc/insights_event.dart';
import 'package:cordato/features/insight/presentation/bloc/insights_state.dart';
import 'package:cordato/features/insight/application/exceptions/insight_exception.dart';
import 'package:cordato/features/insight/application/repositories/interface_insight_repository.dart';

final class InsightsBloc({required final IInsightRepository repository})
    extends Bloc<InsightsEvent, InsightsState> {
  this : super(const InsightsInitial()) {
    on<InsightsRequestedEvent>(_execute, transformer: restartable());
  }

  Future<void> _execute(
    InsightsRequestedEvent event,
    Emitter<InsightsState> emit,
  ) async {
    emit(const InsightsLoading());

    try {
      final data = await repository.get(year: event.year, month: event.month);

      if (isClosed || emit.isDone) return;

      emit(InsightsSuccess(data: data));
    } on InsightException catch (exception) {
      if (isClosed || emit.isDone) return;

      emit(InsightsFailure(errors: exception.errors));
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);
      emit(InsightsFailure(errors: .unknown()));
    }
  }
}
