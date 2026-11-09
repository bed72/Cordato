import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/application/events/recording_event.dart';

import 'package:cordato/features/dashboard/presentation/screens/bloc/audio_bloc.dart';
import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/audio_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/audio_state.dart';
import 'package:cordato/features/dashboard/application/exceptions/audio_exception.dart';

import '../../../../../support/dashboard/mocks/audio_repository_mock.dart';

void main() {
  late AudioRepositoryMock repository;
  late StreamController<RecordingEvent> updates;

  setUp(() {
    repository = AudioRepositoryMock();
    updates = StreamController<RecordingEvent>();
    when(() => repository.start(operation: any(named: 'operation')))
        .thenAnswer((_) => updates.stream);
    when(() => repository.discard(operation: any(named: 'operation')))
        .thenAnswer((_) async {});
    when(() => repository.finish(operation: any(named: 'operation')))
        .thenAnswer((_) async {});
  });

  tearDown(() {
    unawaited(updates.close());
  });

  Future<void> startListening(AudioBloc bloc) async {
    final preparing = bloc.stream.firstWhere(
      (state) => state is AudioPreparing,
    );
    bloc.add(const AudioStarted());
    await preparing;
    final listening = bloc.stream.firstWhere(
      (state) => state is AudioListening,
    );
    updates.add(const RecordingListening());
    await listening;
  }

  test('starts idle', () async {
    final bloc = AudioBloc(repository: repository);
    expect(bloc.state, isA<AudioIdle>());
    await bloc.close();
  });

  blocTest<AudioBloc, AudioState>(
    'preserves capture states and keeps the latest 32 waveform samples',
    build: () => AudioBloc(repository: repository),
    act: (bloc) async {
      await startListening(bloc);
      final ready = bloc.stream.firstWhere((state) => state is AudioReady);
      for (int sample = 0; sample < 35; sample++) {
        updates.add(RecordingLevel(sample / 35));
      }
      updates.add(const RecordingEnded());
      await ready;
    },
    expect: () => [
      isA<AudioPreparing>(),
      isA<AudioListening>(),
      for (int sample = 0; sample < 35; sample++)
        isA<AudioListening>().having(
          (state) => state.levels.length,
          'sample count',
          sample < 32 ? sample + 1 : 32,
        ),
      isA<AudioReady>(),
    ],
    verify: (_) => verify(() => repository.start(operation: 1)).called(1),
  );

  blocTest<AudioBloc, AudioState>(
    'submits once while pending and collapses only after repository completion',
    build: () => AudioBloc(repository: repository),
    act: (bloc) async {
      await startListening(bloc);
      final finished = Completer<void>();
      final started = Completer<void>();
      when(() => repository.finish(operation: 1)).thenAnswer((_) {
        started.complete();
        return finished.future;
      });
      final collapsing = bloc.stream.firstWhere(
        (state) => state is AudioCollapsing,
      );

      bloc
        ..add(const AudioSubmitted())
        ..add(const AudioSubmitted());
      await started.future;
      expect(bloc.state, isA<AudioFinalizing>());
      finished.complete();
      await collapsing;
    },
    expect: () => [
      isA<AudioPreparing>(),
      isA<AudioListening>(),
      isA<AudioFinalizing>(),
      isA<AudioCollapsing>().having(
        (state) => state.failure,
        'failure',
        isNull,
      ),
    ],
    verify: (_) => verify(() => repository.finish(operation: 1)).called(1),
  );

  blocTest<AudioBloc, AudioState>(
    'pending upload infrastructure produces expected feedback rather than success',
    build: () {
      when(() => repository.finish(operation: 1))
          .thenThrow(const AudioException(.sendingUnavailable));
      return AudioBloc(repository: repository);
    },
    act: (bloc) async {
      await startListening(bloc);
      final collapsing = bloc.stream.firstWhere(
        (state) => state is AudioCollapsing,
      );
      bloc.add(const AudioSubmitted());
      await collapsing;
      final idle = bloc.stream.firstWhere((state) => state is AudioIdle);
      bloc.add(const AudioCollapsed(1));
      await idle;
    },
    expect: () => [
      isA<AudioPreparing>(),
      isA<AudioListening>(),
      isA<AudioFinalizing>(),
      isA<AudioCollapsing>().having(
        (state) => state.failure,
        'failure',
        AudioFailureEnum.sendingUnavailable,
      ),
      isA<AudioIdle>(),
    ],
    verify: (_) => verify(() => repository.discard(operation: 1)).called(1),
  );

  blocTest<AudioBloc, AudioState>(
    'cancel discards without finalization',
    build: () => AudioBloc(repository: repository),
    act: (bloc) async {
      await startListening(bloc);
      final discarded = Completer<void>();
      when(() => repository.discard(operation: 1)).thenAnswer((_) async {
        discarded.complete();
      });
      bloc.add(const AudioCancelled());
      await discarded.future;
    },
    expect: () => [
      isA<AudioPreparing>(),
      isA<AudioListening>(),
      isA<AudioCollapsing>(),
    ],
    verify: (_) => verifyNever(
      () => repository.finish(operation: any(named: 'operation')),
    ),
  );

  blocTest<AudioBloc, AudioState>(
    'unexpected finalization failure reports only a safe error to the observer',
    build: () {
      when(() => repository.finish(operation: 1))
          .thenThrow(StateError('sensitive native payload'));
      return AudioBloc(repository: repository);
    },
    act: (bloc) async {
      await startListening(bloc);
      final collapsed = bloc.stream.firstWhere(
        (state) => state is AudioCollapsing,
      );
      bloc.add(const AudioSubmitted());
      await collapsed;
    },
    expect: () => [
      isA<AudioPreparing>(),
      isA<AudioListening>(),
      isA<AudioFinalizing>(),
      isA<AudioCollapsing>().having(
        (state) => state.failure,
        'failure',
        AudioFailureEnum.unexpected,
      ),
    ],
    errors: () => [
      isA<StateError>().having(
        (error) => error.message,
        'message',
        'Unexpected audio capture failure',
      ),
    ],
  );

  test(
    'closing during finalization cancels observation and prevents publication',
    () async {
      final bloc = AudioBloc(repository: repository);
      final cancelled = Completer<void>();
      updates.onCancel = cancelled.complete;
      await startListening(bloc);
      final finish = Completer<void>();
      final finalizing = Completer<void>();
      when(() => repository.finish(operation: 1)).thenAnswer((_) {
        finalizing.complete();
        return finish.future;
      });
      bloc.add(const AudioSubmitted());
      await finalizing.future;

      final closed = bloc.close();
      await cancelled.future;
      finish.complete();
      await closed;

      expect(bloc.state, isA<AudioFinalizing>());
    },
  );
}
