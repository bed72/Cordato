import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';

import 'package:cordato/features/root/presentation/bloc/widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_state.dart';
import 'package:cordato/features/root/application/repositories/interface_widget_sync_repository.dart';

final class WidgetSyncBloc({required final IWidgetSyncRepository repository})
    extends Bloc<WidgetSyncEvent, WidgetSyncState> {
  this : super(const WidgetSyncInitial()) {
    on<WidgetSyncStartedEvent>(
      _observeRefreshRequests,
      transformer: droppable(),
    );
    on<WidgetRefreshRequestedEvent>(_synchronize, transformer: restartable());
  }

  Future<void> _observeRefreshRequests(
    WidgetSyncStartedEvent event,
    Emitter<WidgetSyncState> emit,
  ) async {
    try {
      final observation = emit.onEach<void>(
        repository.refreshRequests,
        onData: (_) {
          if (!isClosed && !emit.isDone) {
            add(const WidgetRefreshRequestedEvent());
          }
        },
        onError: (error, stackTrace) {
          if (!isClosed && !emit.isDone) addError(error, stackTrace);
        },
      );

      add(const WidgetRefreshRequestedEvent());
      await observation;
    } catch (error, stackTrace) {
      if (!isClosed && !emit.isDone) {
        addError(error, stackTrace);
      }
    }
  }

  Future<void> _synchronize(
    WidgetRefreshRequestedEvent event,
    Emitter<WidgetSyncState> emit,
  ) async {
    emit(const WidgetSyncUpdating());
    try {
      await repository.enable();
      if (isClosed || emit.isDone) return;

      await repository.refresh();
      if (!isClosed && !emit.isDone) emit(const WidgetSyncReady());
    } on MetricsException catch (exception) {
      if (!isClosed && !emit.isDone) {
        emit(WidgetSyncFailure(errors: exception.errors));
      }
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);
      emit(WidgetSyncFailure(errors: ErrorsEntity.unknown()));
    }
  }
}
