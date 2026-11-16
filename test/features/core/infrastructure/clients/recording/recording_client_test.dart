import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import 'package:cordato/features/core/application/events/recording_event.dart';
import 'package:cordato/features/core/application/enums/recording_failure_enum.dart';
import 'package:cordato/features/core/application/exceptions/recording_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/recording/recording_client.dart';

import '../../../../../support/core/mocks/audio_recorder_mock.dart';

void main() {
  late AudioRecorderMock recorder;
  late RecordingClient client;
  late Directory temporaryRoot;
  late StreamController<Amplitude> amplitudes;
  late StreamController<RecordState> states;
  late String recordingPath;

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp(
      'cordato_recording_test_',
    );
    recorder = AudioRecorderMock();
    amplitudes = StreamController<Amplitude>();
    states = StreamController<RecordState>();
    when(() => recorder.hasPermission()).thenAnswer((_) async => true);
    when(() => recorder.start(any(), path: any(named: 'path')))
        .thenAnswer((invocation) async {
          recordingPath = invocation.namedArguments[#path] as String;
          await File(recordingPath).writeAsBytes([1, 2, 3]);
        });
    when(() => recorder.onAmplitudeChanged(any()))
        .thenAnswer((_) => amplitudes.stream);
    when(() => recorder.onStateChanged()).thenAnswer((_) => states.stream);
    when(() => recorder.stop()).thenAnswer((_) async => recordingPath);
    when(() => recorder.cancel()).thenAnswer((_) async {});
    when(() => recorder.dispose()).thenAnswer((_) async {});
    client = RecordingClient(
      recorder: () => recorder,
      directory: () async => temporaryRoot,
    );
  });

  tearDown(() async {
    await client.discard(operation: 1);
    unawaited(amplitudes.close());
    unawaited(states.close());
    await temporaryRoot.delete(recursive: true);
  });

  Future<StreamSubscription<RecordingEvent>> listenUntilRecording({
    void Function(RecordingEvent)? onEvent,
  }) async {
    final listening = Completer<void>();
    final observation = client.start(operation: 1).listen((event) {
      onEvent?.call(event);
      if (event is RecordingListening) {
        listening.complete();
      }
    });
    addTearDown(observation.cancel);
    await listening.future;
    return observation;
  }

  group('Audio capture', () {
    test(
      'cancelling observation releases the native recorder and temporary audio',
      () async {
        final observation = await listenUntilRecording();

        await observation.cancel();

        expect(await File(recordingPath).exists(), isFalse);
        verifyNever(() => recorder.stop());
        verify(() => recorder.cancel()).called(1);
        verify(() => recorder.dispose()).called(1);
      },
    );

    test(
      'records mono AAC into a temporary m4a file and disposes after discard',
      () async {
        await listenUntilRecording();

        final audio = await client.finish(operation: 1);

        expect(audio, [1, 2, 3]);
        expect(recordingPath, endsWith('/capture.m4a'));
        expect(await File(recordingPath).exists(), isTrue);
        final config =
            verify(() => recorder.start(captureAny(), path: any(named: 'path')))
                    .captured
                    .single
                as RecordConfig;
        expect(config.encoder, AudioEncoder.aacLc);
        expect(config.numChannels, 1);

        await client.discard(operation: 1);

        expect(await File(recordingPath).exists(), isFalse);
        verify(() => recorder.stop()).called(1);
        verify(() => recorder.cancel()).called(1);
        verify(() => recorder.dispose()).called(1);
      },
    );

    test(
      'normalizes finite and nonfinite dBFS into existing waveform levels',
      () async {
        final levels = <double>[];
        final received = Completer<void>();
        await listenUntilRecording(
          onEvent: (event) {
            if (event case RecordingLevel(:final level)) {
              levels.add(level);
              if (levels.length == 5) {
                received.complete();
              }
            }
          },
        );

        for (final decibels in [
          -80.0,
          -30.0,
          0.0,
          10.0,
          double.negativeInfinity,
        ]) {
          amplitudes.add(Amplitude(current: decibels, max: 0));
        }
        await received.future;

        expect(levels, [0, 0.5, 1, 1, 0]);
      },
    );

    test(
      'shares finalization without stopping the native recorder twice',
      () async {
        await listenUntilRecording();
        final stopped = Completer<String?>();
        final stopping = Completer<void>();
        when(() => recorder.stop()).thenAnswer((_) {
          stopping.complete();
          return stopped.future;
        });

        final first = client.finish(operation: 1);
        final second = client.finish(operation: 1);
        await stopping.future;
        stopped.complete(recordingPath);

        expect(await first, [1, 2, 3]);
        expect(await second, [1, 2, 3]);
        verify(() => recorder.stop()).called(1);
      },
    );

    test(
      'cancellation during permission preparation never starts recording',
      () async {
        final permission = Completer<bool>();
        final requested = Completer<void>();
        when(() => recorder.hasPermission()).thenAnswer((_) {
          requested.complete();
          return permission.future;
        });
        final observation = client.start(operation: 1).listen((_) {});
        await requested.future;

        final discarded = client.discard(operation: 1);
        permission.complete(true);
        await discarded;
        await observation.cancel();

        verifyNever(() => recorder.start(any(), path: any(named: 'path')));
        verify(() => recorder.dispose()).called(1);
        expect(await temporaryRoot.list().toList(), isEmpty);
      },
    );
  });

  group('Failures', () {
    test(
      'native interruption releases the microphone and temporary file',
      () async {
        final listening = Completer<void>();
        final interrupted = Completer<Object>();
        final observation = client.start(operation: 1).listen((event) {
          if (event is RecordingListening) {
            listening.complete();
          }
        }, onError: (Object error) => interrupted.complete(error));
        await listening.future;

        states.add(RecordState.pause);

        expect(
          await interrupted.future,
          isA<RecordingException>().having(
            (error) => error.failure,
            'failure',
            RecordingFailureEnum.interrupted,
          ),
        );
        await observation.cancel();
        expect(await File(recordingPath).exists(), isFalse);
        verify(() => recorder.dispose()).called(1);
      },
    );

    test(
      'discard during pending stop rejects late audio and waits for release',
      () async {
        await listenUntilRecording();
        final stopping = Completer<void>();
        final stopped = Completer<String?>();
        when(() => recorder.stop()).thenAnswer((_) {
          stopping.complete();
          return stopped.future;
        });
        final finalized = expectLater(
          client.finish(operation: 1),
          throwsA(isA<RecordingException>()),
        );
        await stopping.future;

        final discarded = client.discard(operation: 1);
        verifyNever(() => recorder.dispose());
        stopped.complete(recordingPath);
        await finalized;
        await discarded;

        expect(await File(recordingPath).exists(), isFalse);
        verify(() => recorder.dispose()).called(1);
      },
    );

    test('reports permission denial without creating a recording', () async {
      when(() => recorder.hasPermission()).thenAnswer((_) async => false);
      final failure = Completer<Object>();
      final observation = client
          .start(operation: 1)
          .listen((_) {}, onError: (Object error) => failure.complete(error));

      expect(
        await failure.future,
        isA<RecordingException>().having(
          (error) => error.failure,
          'failure',
          RecordingFailureEnum.permission,
        ),
      );
      await observation.cancel();
      verifyNever(() => recorder.start(any(), path: any(named: 'path')));
    });

    test('maps native startup failure without exposing its message', () async {
      when(() => recorder.start(any(), path: any(named: 'path')))
          .thenThrow(PlatformException(code: 'native', message: 'sensitive'));
      final failure = Completer<Object>();
      final observation = client
          .start(operation: 1)
          .listen((_) {}, onError: (Object error) => failure.complete(error));

      expect(
        await failure.future,
        isA<RecordingException>().having(
          (error) => error.failure,
          'failure',
          RecordingFailureEnum.unavailable,
        ),
      );
      await observation.cancel();
    });

    test('rejects empty recordings', () async {
      await listenUntilRecording();
      await File(recordingPath).writeAsBytes([]);

      await expectLater(
        client.finish(operation: 1),
        throwsA(
          isA<RecordingException>().having(
            (error) => error.failure,
            'failure',
            RecordingFailureEnum.empty,
          ),
        ),
      );
    });

    test('old operation cannot stop or discard a new recording', () async {
      await listenUntilRecording();

      await client.discard(operation: 99);
      await expectLater(
        client.finish(operation: 99),
        throwsA(isA<RecordingException>()),
      );

      verifyNever(() => recorder.stop());
      verifyNever(() => recorder.cancel());
      expect(await client.finish(operation: 1), [1, 2, 3]);
    });

    test(
      'propagates malformed native output as an unexpected file failure',
      () async {
        await listenUntilRecording();
        when(() => recorder.stop())
            .thenAnswer((_) async => '${temporaryRoot.path}/missing.m4a');

        await expectLater(
          client.finish(operation: 1),
          throwsA(isA<FileSystemException>()),
        );
      },
    );
  });
}
