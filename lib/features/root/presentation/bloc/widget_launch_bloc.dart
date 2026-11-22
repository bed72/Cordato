import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/root/application/repositories/interface_widget_launch_repository.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_state.dart';

final class WidgetLaunchBloc({
  required final IWidgetLaunchRepository repository,
}) extends Bloc<WidgetLaunchEvent, WidgetLaunchState> {
  this : super(const WidgetLaunchInitial()) {
    on<WidgetLaunchStartedEvent>(_observe, transformer: droppable());
  }

  Future<void> _observe(
    WidgetLaunchStartedEvent event,
    Emitter<WidgetLaunchState> emit,
  ) async {
    if (state is! WidgetLaunchInitial) return;

    emit(const WidgetLaunchListening());
    int observedLaunches = 0;
    try {
      final observation = emit.onEach<void>(
        repository.expenseLaunches,
        onData: (_) {
          if (isClosed || emit.isDone) return;

          emit(WidgetLaunchRequested(sequence: ++observedLaunches));
        },
        onError: (error, stackTrace) => _reportFailure(emit, error, stackTrace),
      );

      try {
        final launched = await repository.initialExpenseLaunch();
        if (!isClosed && !emit.isDone && launched && observedLaunches == 0) {
          emit(WidgetLaunchRequested(sequence: ++observedLaunches));
        }
      } catch (error, stackTrace) {
        _reportFailure(emit, error, stackTrace);
      }
      await observation;
    } catch (error, stackTrace) {
      _reportFailure(emit, error, stackTrace);
    }
  }

  void _reportFailure(
    Emitter<WidgetLaunchState> emit,
    Object error,
    StackTrace stackTrace,
  ) {
    if (isClosed || emit.isDone) return;

    addError(error, stackTrace);
    emit(const WidgetLaunchFailure());
  }
}
