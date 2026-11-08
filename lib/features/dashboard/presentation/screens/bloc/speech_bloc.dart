import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_state.dart';

import 'package:cordato/features/dashboard/application/enums/speech_failure_enum.dart';
import 'package:cordato/features/dashboard/application/events/speech_update_event.dart';
import 'package:cordato/features/dashboard/application/exceptions/speech_exception.dart';
import 'package:cordato/features/dashboard/application/repositories/interface_speech_repository.dart';

final class SpeechBloc({required final ISpeechRepository repository})
    extends Bloc<SpeechEvent, SpeechState> {
  static const _maximumLevelSamples = 32;

  int _operationSequence = 0;

  this : super(const SpeechIdle()) {
    on<SpeechStarted>(_startCapture, transformer: droppable());
    on<SpeechSubmitted>(_submitCapture, transformer: droppable());
    on<SpeechObserved>(_observeCapture, transformer: restartable());
    on<SpeechCancelled>(_cancelCapture, transformer: restartable());
    on<SpeechCollapsed>(_confirmCollapse, transformer: droppable());
  }

  void _startCapture(SpeechStarted event, Emitter<SpeechState> emit) {
    if (state is! SpeechIdle) return;

    final operation = ++_operationSequence;

    emit(SpeechPreparing(operation: operation));
    add(SpeechObserved(operation));
  }

  Future<void> _observeCapture(
    SpeechObserved event,
    Emitter<SpeechState> emit,
  ) async {
    if (state.operation != event.operation) return;

    await emit.onEach<SpeechUpdateEvent>(
      repository.start(operation: event.operation),
      onData: (update) => _applyUpdate(event.operation, update, emit),
      onError: (error, stackTrace) =>
          _handleObservationFailure(event.operation, error, stackTrace, emit),
    );
  }

  void _applyUpdate(
    int operation,
    SpeechUpdateEvent update,
    Emitter<SpeechState> emit,
  ) {
    if (state.operation != operation || !state.canCancel) return;

    switch (update) {
      case SpeechListeningUpdateEvent():
        if (state is SpeechPreparing) {
          emit(SpeechListening(operation: operation));
        }
      case SpeechLevelUpdateEvent(:final level):
        _appendSoundLevel(level, emit);
      case SpeechReadyUpdateEvent():
        emit(SpeechReady(operation: operation));
    }
  }

  void _appendSoundLevel(double level, Emitter<SpeechState> emit) {
    final currentState = state;

    if (currentState is! SpeechListening) return;

    final sampledLevels = [...currentState.levels, level];
    final excessSamples = sampledLevels.length - _maximumLevelSamples;
    final recentLevels = excessSamples > 0
        ? sampledLevels.sublist(excessSamples)
        : sampledLevels;

    emit(
      SpeechListening(levels: recentLevels, operation: currentState.operation),
    );
  }

  void _handleObservationFailure(
    int operation,
    Object error,
    StackTrace stackTrace,
    Emitter<SpeechState> emit,
  ) {
    if (state.operation != operation || state is SpeechCollapsing) {
      return;
    }

    emit(
      SpeechCollapsing(
        operation: operation,
        failure: _classifyFailure(error, stackTrace),
      ),
    );
  }

  Future<void> _submitCapture(
    SpeechSubmitted event,
    Emitter<SpeechState> emit,
  ) async {
    final operation = state.operation;

    if (!state.canSubmit || operation == null) return;

    emit(SpeechFinalizing(operation: operation));

    try {
      await repository.finish(operation: operation);
    } catch (error, stackTrace) {
      if (!_canCompleteSubmission(operation, emit)) return;

      emit(
        SpeechCollapsing(
          operation: operation,
          failure: _classifyFailure(error, stackTrace),
        ),
      );

      return;
    }

    if (!_canCompleteSubmission(operation, emit)) return;

    emit(SpeechCollapsing(operation: operation, confirmed: true));
  }

  bool _canCompleteSubmission(int operation, Emitter<SpeechState> emit) =>
      !isClosed &&
      !emit.isDone &&
      state is SpeechFinalizing &&
      state.operation == operation;

  Future<void> _cancelCapture(
    SpeechCancelled event,
    Emitter<SpeechState> emit,
  ) async {
    final operation = state.operation;

    if (operation == null || (!event.lifecycle && !state.canCancel)) return;

    emit(
      event.lifecycle
          ? const SpeechIdle()
          : SpeechCollapsing(operation: operation),
    );

    await _discardCapture(operation);
  }

  Future<void> _confirmCollapse(
    SpeechCollapsed event,
    Emitter<SpeechState> emit,
  ) async {
    final currentState = state;

    if (currentState is! SpeechCollapsing ||
        currentState.operation != event.operation) {
      return;
    }

    emit(const SpeechIdle());

    if (currentState.confirmed) {
      repository.confirmDiagnostic(operation: event.operation);
    }

    await _discardCapture(event.operation);
  }

  Future<void> _discardCapture(int operation) async {
    try {
      await repository.discard(operation: operation);
    } catch (_, stackTrace) {
      addError(StateError('Speech capture cleanup failed'), stackTrace);
    }
  }

  SpeechFailureEnum _classifyFailure(Object error, StackTrace stackTrace) {
    if (error is SpeechException) return error.failure;

    addError(StateError('Unexpected speech capture failure'), stackTrace);

    return .unexpected;
  }
}
