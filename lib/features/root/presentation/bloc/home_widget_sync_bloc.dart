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
  this : super(const HomeWidgetSyncInitial()) {
    on<HomeWidgetSyncStartedEvent>(
      _observeRefreshRequests,
      transformer: droppable(),
    );
    on<HomeWidgetRefreshRequestedEvent>(
      _synchronize,
      transformer: restartable(),
    );
  }

  Future<void> _observeRefreshRequests(
    HomeWidgetSyncStartedEvent event,
    Emitter<HomeWidgetSyncState> emit,
  ) async {
    try {
      final observation = emit.onEach<void>(
        repository.refreshRequests,
        onData: (_) {
          if (!isClosed && !emit.isDone) {
            add(const HomeWidgetRefreshRequestedEvent());
          }
        },
        onError: (error, stackTrace) {
          if (!isClosed && !emit.isDone) addError(error, stackTrace);
        },
      );

      add(const HomeWidgetRefreshRequestedEvent());
      await observation;
    } catch (error, stackTrace) {
      if (!isClosed && !emit.isDone) {
        addError(error, stackTrace);
      }
    }
  }

  Future<void> _synchronize(
    HomeWidgetRefreshRequestedEvent event,
    Emitter<HomeWidgetSyncState> emit,
  ) async {
    emit(const HomeWidgetSyncUpdating());
    try {
      await repository.enable();
      if (isClosed || emit.isDone) return;

      await repository.refresh();
      if (!isClosed && !emit.isDone) emit(const HomeWidgetSyncReady());
    } on MetricsException catch (exception) {
      if (!isClosed && !emit.isDone) {
        emit(HomeWidgetSyncFailure(errors: exception.errors));
      }
    } catch (error, stackTrace) {
      if (isClosed || emit.isDone) return;

      addError(error, stackTrace);
      emit(HomeWidgetSyncFailure(errors: ErrorsEntity.unknown()));
    }
  }
}
