import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/root/application/repositories/interface_home_widget_launch_repository.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_state.dart';

final class HomeWidgetLaunchBloc({
  required final IHomeWidgetLaunchRepository repository,
}) extends Bloc<HomeWidgetLaunchEvent, HomeWidgetLaunchState> {
  this : super(const HomeWidgetLaunchInitial()) {
    on<HomeWidgetLaunchStartedEvent>(_observe, transformer: droppable());
  }

  Future<void> _observe(
    HomeWidgetLaunchStartedEvent event,
    Emitter<HomeWidgetLaunchState> emit,
  ) async {
    if (state is! HomeWidgetLaunchInitial) return;

    emit(const HomeWidgetLaunchListening());
    int observedLaunches = 0;
    try {
      final observation = emit.onEach<void>(
        repository.expenseLaunches,
        onData: (_) {
          if (isClosed || emit.isDone) return;

          emit(HomeWidgetLaunchRequested(sequence: ++observedLaunches));
        },
        onError: (error, stackTrace) => _reportFailure(emit, error, stackTrace),
      );

      try {
        final launched = await repository.initialExpenseLaunch();
        if (!isClosed && !emit.isDone && launched && observedLaunches == 0) {
          emit(HomeWidgetLaunchRequested(sequence: ++observedLaunches));
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
    Emitter<HomeWidgetLaunchState> emit,
    Object error,
    StackTrace stackTrace,
  ) {
    if (isClosed || emit.isDone) return;

    addError(error, stackTrace);
    emit(const HomeWidgetLaunchFailure());
  }
}
