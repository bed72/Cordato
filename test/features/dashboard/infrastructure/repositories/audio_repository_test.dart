import 'dart:async';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/application/events/recording_event.dart';
import 'package:cordato/features/core/application/enums/recording_failure_enum.dart';
import 'package:cordato/features/core/application/exceptions/recording_exception.dart';
import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';
import 'package:cordato/features/dashboard/application/exceptions/audio_exception.dart';
import 'package:cordato/features/dashboard/infrastructure/repositories/audio_repository.dart';

import '../../../../support/core/mocks/recording_client_mock.dart';

void main() {
  late RecordingClientMock client;
  late AudioRepository repository;
  late StreamController<RecordingEvent> events;

  setUp(() {
    client = RecordingClientMock();
    events = StreamController<RecordingEvent>();
    when(() => client.start(operation: 1)).thenAnswer((_) => events.stream);
    when(() => client.discard(operation: any(named: 'operation')))
        .thenAnswer((_) async {});
    repository = AudioRepository(client: client);
  });

  tearDown(() {
    unawaited(events.close());
  });

  StreamSubscription<RecordingEvent> observe({
    void Function(RecordingEvent)? onData,
    void Function(Object)? onError,
  }) {
    final observation = repository
        .start(operation: 1)
        .listen(onData ?? (_) {}, onError: onError);
    addTearDown(observation.cancel);
    return observation;
  }

  test(
    'forwards the same capture events without an intermediate mapping',
    () async {
      final updates = <RecordingEvent>[];
      final ready = Completer<void>();
      observe(
        onData: (event) {
          updates.add(event);
          if (event is RecordingEnded) {
            ready.complete();
          }
        },
      );

      const listening = RecordingListening();
      const level = RecordingLevel(0.5);
      const ended = RecordingEnded();
      events
        ..add(listening)
        ..add(level)
        ..add(ended);
      await ready.future;

      expect(updates, [same(listening), same(level), same(ended)]);
    },
  );

  test('does not report successful submission while upload infrastructure is pending', () async {
    observe();
    when(() => client.finish(operation: 1))
        .thenAnswer((_) async => Uint8List.fromList([1, 2]));

    await expectLater(
      repository.finish(operation: 1),
      throwsA(
        isA<AudioException>().having(
          (error) => error.failure,
          'failure',
          AudioFailureEnum.sendingUnavailable,
        ),
      ),
    );

    verify(() => client.finish(operation: 1)).called(1);
    verify(() => client.discard(operation: 1)).called(1);
  });

  test('maps empty audio and releases the capture', () async {
    observe();
    when(() => client.finish(operation: 1))
        .thenAnswer((_) async => Uint8List(0));

    await expectLater(
      repository.finish(operation: 1),
      throwsA(
        isA<AudioException>().having(
          (error) => error.failure,
          'failure',
          AudioFailureEnum.empty,
        ),
      ),
    );

    verify(() => client.discard(operation: 1)).called(1);
  });

  test(
    'maps expected recording failures and still releases resources',
    () async {
      observe();
      when(() => client.finish(operation: 1))
          .thenThrow(const RecordingException(.interrupted));

      await expectLater(
        repository.finish(operation: 1),
        throwsA(
          isA<AudioException>().having(
            (error) => error.failure,
            'failure',
            AudioFailureEnum.interrupted,
          ),
        ),
      );

      verify(() => client.discard(operation: 1)).called(1);
    },
  );

  test(
    'preserves unexpected exceptions rather than treating them as success',
    () async {
      observe();
      final failure = StateError('native capture failed');
      when(() => client.finish(operation: 1)).thenThrow(failure);

      await expectLater(
        repository.finish(operation: 1),
        throwsA(same(failure)),
      );

      verify(() => client.discard(operation: 1)).called(1);
    },
  );

  for (final (nativeFailure, audioFailure) in [
    (RecordingFailureEnum.permission, AudioFailureEnum.permission),
    (RecordingFailureEnum.unavailable, AudioFailureEnum.unavailable),
    (RecordingFailureEnum.empty, AudioFailureEnum.empty),
  ]) {
    test('maps ${nativeFailure.name} without a separate mapper', () async {
      when(() => client.finish(operation: 1))
          .thenThrow(RecordingException(nativeFailure));

      await expectLater(
        repository.finish(operation: 1),
        throwsA(
          isA<AudioException>().having(
            (exception) => exception.failure,
            'failure',
            audioFailure,
          ),
        ),
      );

      verify(() => client.discard(operation: 1)).called(1);
    });
  }

  test(
    'stream preserves unexpected failure identity and stack trace',
    () async {
      final failure = StateError('capture failed');
      final stackTrace = StackTrace.current;
      final observed = Completer<void>();
      final observation = repository
          .start(operation: 1)
          .listen(
            (_) {},
            onError: (Object error, StackTrace trace) {
              expect(error, same(failure));
              expect(trace, same(stackTrace));
              observed.complete();
            },
          );
      addTearDown(observation.cancel);

      events.addError(failure, stackTrace);
      await observed.future;
    },
  );

  test(
    'observation maps errors without exposing the plugin to the Bloc',
    () async {
      final failure = Completer<Object>();
      observe(onError: failure.complete);

      events.addError(const RecordingException(.permission));

      expect(
        await failure.future,
        isA<AudioException>().having(
          (error) => error.failure,
          'failure',
          AudioFailureEnum.permission,
        ),
      );
    },
  );

  test(
    'cancelling observation cancels the client stream without finalizing',
    () async {
      final cancelled = Completer<void>();
      events.onCancel = cancelled.complete;
      final observation = observe();

      await observation.cancel();
      await cancelled.future;

      verifyNever(() => client.finish(operation: any(named: 'operation')));
      verifyNever(() => client.discard(operation: any(named: 'operation')));
    },
  );
}
