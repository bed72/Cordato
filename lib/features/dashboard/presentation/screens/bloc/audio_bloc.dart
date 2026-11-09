import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/core/application/events/recording_event.dart';

import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/audio_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/audio_state.dart';
import 'package:cordato/features/dashboard/application/exceptions/audio_exception.dart';
import 'package:cordato/features/dashboard/application/repositories/interface_audio_repository.dart';

final class AudioBloc({required final IAudioRepository repository})
    extends Bloc<AudioEvent, AudioState> {
  static const _maximumLevelSamples = 32;

  int _operationSequence = 0;

  this : super(const AudioIdle()) {
    on<AudioStarted>(_startCapture, transformer: droppable());
    on<AudioSubmitted>(_submitCapture, transformer: droppable());
    on<AudioObserved>(_observeCapture, transformer: restartable());
    on<AudioCancelled>(_cancelCapture, transformer: restartable());
    on<AudioCollapsed>(_confirmCollapse, transformer: droppable());
  }

  void _startCapture(AudioStarted event, Emitter<AudioState> emit) {
    if (state is! AudioIdle) return;

    final operation = ++_operationSequence;

    emit(AudioPreparing(operation: operation));
    add(AudioObserved(operation));
  }

  Future<void> _observeCapture(
    AudioObserved event,
    Emitter<AudioState> emit,
  ) async {
    if (state.operation != event.operation) return;

    await emit.onEach<RecordingEvent>(
      repository.start(operation: event.operation),
      onData: (update) => _applyUpdate(event.operation, update, emit),
      onError: (error, stackTrace) =>
          _handleObservationFailure(event.operation, error, stackTrace, emit),
    );
  }

  void _applyUpdate(
    int operation,
    RecordingEvent update,
    Emitter<AudioState> emit,
  ) {
    if (state.operation != operation || !state.canCancel) return;

    switch (update) {
      case RecordingListening():
        if (state is AudioPreparing) {
          emit(AudioListening(operation: operation));
        }
      case RecordingLevel(:final level):
        _appendSoundLevel(level, emit);
      case RecordingEnded():
        emit(AudioReady(operation: operation));
    }
  }

  void _appendSoundLevel(double level, Emitter<AudioState> emit) {
    final currentState = state;

    if (currentState is! AudioListening) return;

    final sampledLevels = [...currentState.levels, level];
    final excessSamples = sampledLevels.length - _maximumLevelSamples;
    final recentLevels = excessSamples > 0
        ? sampledLevels.sublist(excessSamples)
        : sampledLevels;

    emit(
      AudioListening(levels: recentLevels, operation: currentState.operation),
    );
  }

  void _handleObservationFailure(
    int operation,
    Object error,
    StackTrace stackTrace,
    Emitter<AudioState> emit,
  ) {
    if (state.operation != operation || state is AudioCollapsing) return;

    emit(
      AudioCollapsing(
        operation: operation,
        failure: _classifyFailure(error, stackTrace),
      ),
    );
  }

  Future<void> _submitCapture(
    AudioSubmitted event,
    Emitter<AudioState> emit,
  ) async {
    final operation = state.operation;

    if (!state.canSubmit || operation == null) return;

    emit(AudioFinalizing(operation: operation));

    try {
      await repository.finish(operation: operation);
    } catch (error, stackTrace) {
      if (!_canCompleteSubmission(operation, emit)) return;

      emit(
        AudioCollapsing(
          operation: operation,
          failure: _classifyFailure(error, stackTrace),
        ),
      );

      return;
    }

    if (!_canCompleteSubmission(operation, emit)) return;

    emit(AudioCollapsing(operation: operation));
  }

  bool _canCompleteSubmission(int operation, Emitter<AudioState> emit) =>
      !isClosed &&
      !emit.isDone &&
      state is AudioFinalizing &&
      state.operation == operation;

  Future<void> _cancelCapture(
    AudioCancelled event,
    Emitter<AudioState> emit,
  ) async {
    final operation = state.operation;

    if (operation == null || (!event.lifecycle && !state.canCancel)) return;

    emit(
      event.lifecycle
          ? const AudioIdle()
          : AudioCollapsing(operation: operation),
    );

    await _discardCapture(operation);
  }

  Future<void> _confirmCollapse(
    AudioCollapsed event,
    Emitter<AudioState> emit,
  ) async {
    final currentState = state;

    if (currentState is! AudioCollapsing ||
        currentState.operation != event.operation) {
      return;
    }

    emit(const AudioIdle());

    await _discardCapture(event.operation);
  }

  Future<void> _discardCapture(int operation) async {
    try {
      await repository.discard(operation: operation);
    } catch (_, stackTrace) {
      addError(StateError('Audio capture cleanup failed'), stackTrace);
    }
  }

  AudioFailureEnum _classifyFailure(Object error, StackTrace stackTrace) {
    if (error is AudioException) return error.failure;

    addError(StateError('Unexpected audio capture failure'), stackTrace);

    return .unexpected;
  }
}
