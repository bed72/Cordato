import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/metrics/application/exceptions/metrics_exception.dart';

import 'package:cordato/features/root/presentation/bloc/home_widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_state.dart';
import 'package:cordato/features/root/application/repositories/interface_home_widget_sync_repository.dart';

final class HomeWidgetSyncBloc({
  required final IHomeWidgetSyncRepository repository,
}) extends Bloc<HomeWidgetSyncEvent, HomeWidgetSyncState> {
  this : super(const HomeWidgetSyncInactive()) {
    on<HomeWidgetSyncStartedEvent>(
      _observeRefreshRequests,
      transformer: droppable(),
    );
    on<HomeWidgetSyncOperationEvent>(_synchronize, transformer: restartable());
  }

  Future<void> _observeRefreshRequests(
    HomeWidgetSyncStartedEvent event,
    Emitter<HomeWidgetSyncState> emit,
  ) async {
    try {
      await emit.onEach<void>(
        repository.refreshRequests,
        onData: (_) {
          if (!isClosed && !emit.isDone) {
            add(const HomeWidgetRefreshRequestedEvent());
          }
        },
        onError: (error, stackTrace) {
          if (!isClosed && !emit.isDone) {
            addError(error, stackTrace);
          }
        },
      );
    } catch (error, stackTrace) {
      if (!isClosed && !emit.isDone) {
        addError(error, stackTrace);
      }
    }
  }

  Future<void> _synchronize(
    HomeWidgetSyncOperationEvent event,
    Emitter<HomeWidgetSyncState> emit,
  ) async {
    if (event is HomeWidgetRefreshRequestedEvent && !state.active) return;

    final active = switch (event) {
      HomeWidgetSessionChangedEvent(:final authenticated) => authenticated,
      HomeWidgetRefreshRequestedEvent() => state.active,
    };

    emit(
      active ? const HomeWidgetSyncUpdating() : const HomeWidgetSyncInactive(),
    );
    try {
      if (event is HomeWidgetSessionChangedEvent) {
        await repository.setSessionActive(active: active);
      }
      if (!active || isClosed || emit.isDone) return;

      await repository.refresh();
      if (!isClosed && !emit.isDone) emit(const HomeWidgetSyncReady());
    } on MetricsException catch (exception) {
      if (!isClosed && !emit.isDone) {
        emit(HomeWidgetSyncFailure(errors: exception.errors));
      }
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);
      if (active) {
        emit(HomeWidgetSyncFailure(errors: ErrorsEntity.unknown()));
      }
    }
  }
}
