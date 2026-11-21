import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/application/events/recording_event.dart';
import 'package:cordato/features/core/application/enums/recording_failure_enum.dart';
import 'package:cordato/features/dashboard/application/enums/audio_failure_enum.dart';
import 'package:cordato/features/core/application/exceptions/recording_exception.dart';
import 'package:cordato/features/dashboard/application/exceptions/audio_exception.dart';
import 'package:cordato/features/dashboard/infrastructure/repositories/audio_repository.dart';

import '../../../../support/core/mocks/recording_client_mock.dart';
import '../../../../support/dashboard/fakes/audio_upload_client_fake.dart';

void main() {
  late RecordingClientMock client;
  late AudioRepository repository;
  late PocketBase pocketBase;
  late StreamController<RecordingEvent> events;

  setUp(() {
    client = RecordingClientMock();
    events = StreamController<RecordingEvent>();
    when(() => client.start(operation: 1)).thenAnswer((_) => events.stream);
    when(() => client.discard(operation: any(named: 'operation')))
        .thenAnswer((_) async {});
    pocketBase = PocketBase('https://pocketbase.example.test');
    pocketBase.authStore.save('fixture-token', null);
    addTearDown(pocketBase.close);
    repository = AudioRepository(
      client: client,
      pocketBase: pocketBase,
      workerUrl: 'https://worker.example.test',
    );
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

  test(
    'sends multipart with MIME, civil date and current JWT; accepts only 202',
    () async {
      observe();
      final audio = Uint8List.fromList([
        0,
        0,
        0,
        24,
        ...utf8.encode('ftypM4A fixture'),
      ]);
      when(() => client.finish(operation: 1)).thenAnswer((_) async => audio);
      pocketBase.authStore.save('current-fixture-token', null);
      final today = DateTime.now();
      final expectedDate =
          '${today.year}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      int uploads = 0;

      await http.runWithClient(
        () => repository.finish(operation: 1),
        () => MockClient((request) async {
          uploads++;
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://worker.example.test/api/collections/audio/process',
          );
          expect(
            request.headers['Authorization'],
            'Bearer current-fixture-token',
          );
          expect(request.followRedirects, isFalse);
          expect(request.contentLength, request.bodyBytes.length);
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          expect(request.body, contains('name="file"; filename="audio.m4a"'));
          expect(request.body, contains('content-type: audio/mp4'));
          expect(
            request.body,
            contains('name="reference_date"\r\n\r\n$expectedDate'),
          );
          expect(request.bodyBytes, containsAllInOrder(audio));
          expect(request.body, isNot(contains('owner')));
          return http.Response(
            jsonEncode({
              'request_id': 'fixture-request',
              'status': 'processing',
            }),
            202,
          );
        }),
      );

      expect(uploads, 1);
      expect(pocketBase.authStore.token, 'current-fixture-token');
      verify(() => client.finish(operation: 1)).called(1);
      verify(() => client.discard(operation: 1)).called(1);
    },
  );

  group('upload lifecycle and failures', () {
    test('cleanup failure prevents starting upload rather than masking remote acceptance', () async {
      final cleanupFailure = StateError('capture cleanup failed');
      when(() => client.finish(operation: 1))
          .thenAnswer((_) async => Uint8List.fromList([1]));
      when(() => client.discard(operation: 1)).thenThrow(cleanupFailure);
      bool transportCreated = false;

      await http.runWithClient(
        () => expectLater(
          repository.finish(operation: 1),
          throwsA(same(cleanupFailure)),
        ),
        () {
          transportCreated = true;
          return MockClient((_) async => http.Response('{}', 202));
        },
      );

      expect(transportCreated, isFalse);
    });

    test(
      'timeout closes transport, releases capture and ignores late acceptance',
      () {
        fakeAsync((clock) {
          final transport = AudioUploadClientFake();
          when(() => client.finish(operation: 1))
              .thenAnswer((_) async => Uint8List.fromList([1]));
          Object? observedFailure;
          bool completed = false;
          http.runWithClient(() async {
            try {
              await repository.finish(operation: 1);
            } catch (error) {
              observedFailure = error;
            }
            completed = true;
          }, () => transport);
          clock.flushMicrotasks();

          expect(transport.requests, hasLength(1));
          expect(transport.requests.single.contentLength, greaterThan(0));
          expect(completed, isFalse);
          expect(transport.closed, isFalse);
          verify(() => client.discard(operation: 1)).called(1);

          clock.elapse(const Duration(seconds: 30));
          clock.flushMicrotasks();

          expect(completed, isTrue);
          expect(
            observedFailure,
            isA<AudioException>().having(
              (error) => error.failure,
              'failure',
              AudioFailureEnum.submissionUnknown,
            ),
          );
          expect(transport.closed, isTrue);
          verifyNever(() => client.discard(operation: 1));

          transport.response.complete(
            http.StreamedResponse(
              Stream.value(
                utf8.encode('{"request_id":"late","status":"processing"}'),
              ),
              202,
            ),
          );
          clock.flushMicrotasks();

          expect(transport.requests, hasLength(1));
          expect(observedFailure, isA<AudioException>());
          expect(clock.pendingTimers, isEmpty);
        });
      },
    );

    test(
      'keeps upload pending until acceptance and closes transport on success',
      () async {
        final transport = AudioUploadClientFake();
        when(() => client.finish(operation: 1))
            .thenAnswer((_) async => Uint8List.fromList([1]));
        bool completed = false;

        final upload = http.runWithClient(
          () => repository.finish(operation: 1).then((_) {
            completed = true;
          }),
          () => transport,
        );
        await transport.started.future;

        expect(completed, isFalse);
        expect(transport.closed, isFalse);
        verify(() => client.discard(operation: 1)).called(1);

        transport.response.complete(
          http.StreamedResponse(
            Stream.value(
              utf8.encode('{"request_id":"accepted","status":"processing"}'),
            ),
            202,
          ),
        );
        await upload;

        expect(completed, isTrue);
        expect(transport.closed, isTrue);
        expect(transport.requests, hasLength(1));
        verifyNever(() => client.discard(operation: 1));
      },
    );

    for (final (status, failure) in [
      (400, AudioFailureEnum.rejected),
      (401, AudioFailureEnum.unauthorized),
      (403, AudioFailureEnum.forbidden),
      (411, AudioFailureEnum.sendingUnavailable),
      (413, AudioFailureEnum.tooLarge),
      (415, AudioFailureEnum.unsupportedFormat),
      (429, AudioFailureEnum.busy),
      (503, AudioFailureEnum.sendingUnavailable),
      (500, AudioFailureEnum.submissionUnknown),
      (502, AudioFailureEnum.submissionUnknown),
      (201, AudioFailureEnum.submissionUnknown),
      (302, AudioFailureEnum.submissionUnknown),
    ]) {
      test(
        'maps $status locally without clearing session or retrying',
        () async {
          when(() => client.finish(operation: 1))
              .thenAnswer((_) async => Uint8List.fromList([1]));
          int uploads = 0;

          await http.runWithClient(
            () => expectLater(
              repository.finish(operation: 1),
              throwsA(
                isA<AudioException>().having(
                  (error) => error.failure,
                  'failure',
                  failure,
                ),
              ),
            ),
            () => MockClient((_) async {
              uploads++;
              return http.Response('remote-sensitive-error', status);
            }),
          );

          expect(uploads, 1);
          expect(pocketBase.authStore.token, 'fixture-token');
          verify(() => client.discard(operation: 1)).called(1);
        },
      );
    }

    for (final body in [
      'invalid-json',
      '{}',
      'null',
      '{"request_id":1,"status":"processing"}',
      '{"request_id":"id","status":"completed"}',
      '{"request_id":" ","status":"processing"}',
    ]) {
      test('does not claim acceptance for malformed 202: $body', () async {
        when(() => client.finish(operation: 1))
            .thenAnswer((_) async => Uint8List.fromList([1]));

        await http.runWithClient(
          () => expectLater(
            repository.finish(operation: 1),
            throwsA(
              isA<AudioException>().having(
                (error) => error.failure,
                'failure',
                AudioFailureEnum.submissionUnknown,
              ),
            ),
          ),
          () => MockClient((_) async => http.Response(body, 202)),
        );

        verify(() => client.discard(operation: 1)).called(1);
      });
    }

    test(
      'transport failure cannot prove rejection and never retries',
      () async {
        when(() => client.finish(operation: 1))
            .thenAnswer((_) async => Uint8List.fromList([1]));
        int uploads = 0;

        await http.runWithClient(
          () => expectLater(
            repository.finish(operation: 1),
            throwsA(
              isA<AudioException>().having(
                (error) => error.failure,
                'failure',
                AudioFailureEnum.submissionUnknown,
              ),
            ),
          ),
          () => MockClient((_) async {
            uploads++;
            throw http.ClientException('sensitive transport error');
          }),
        );

        expect(uploads, 1);
        verify(() => client.discard(operation: 1)).called(1);
      },
    );

    test('rejects audio over 2 MiB before opening transport', () async {
      when(() => client.finish(operation: 1))
          .thenAnswer((_) async => Uint8List(2 * 1024 * 1024 + 1));

      await expectLater(
        repository.finish(operation: 1),
        throwsA(
          isA<AudioException>().having(
            (error) => error.failure,
            'failure',
            AudioFailureEnum.tooLarge,
          ),
        ),
      );

      verify(() => client.discard(operation: 1)).called(1);
    });

    test(
      'requires current token without sending or mutating auth store',
      () async {
        pocketBase.authStore.clear();
        when(() => client.finish(operation: 1))
            .thenAnswer((_) async => Uint8List.fromList([1]));

        await expectLater(
          repository.finish(operation: 1),
          throwsA(
            isA<AudioException>().having(
              (error) => error.failure,
              'failure',
              AudioFailureEnum.unauthorized,
            ),
          ),
        );

        expect(pocketBase.authStore.token, isEmpty);
        verify(() => client.discard(operation: 1)).called(1);
      },
    );

    for (final address in [
      'http://worker.example.test',
      'https://user:pass@worker.example.test',
      'https://worker.example.test?token=fixture',
      'https://worker.example.test/admin',
      'https://worker.example.test#fragment',
    ]) {
      test('refuses unsafe worker origin: $address', () {
        expect(
          () => AudioRepository(
            client: client,
            pocketBase: pocketBase,
            workerUrl: address,
          ),
          throwsArgumentError,
        );
      });
    }
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
