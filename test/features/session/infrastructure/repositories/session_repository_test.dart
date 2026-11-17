import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/session/application/exceptions/session_exception.dart';
import 'package:cordato/features/session/infrastructure/repositories/session_repository.dart';

import '../../../../support/core/mocks/session_client_mock.dart';

void main() {
  late SessionClientMock client;
  late SessionRepository repository;

  setUp(() {
    client = SessionClientMock();
    repository = SessionRepository(sessionClient: client);
  });

  group('loadSession', () {
    for (final authenticated in [true, false]) {
      test('delegates and returns $authenticated without caching', () async {
        when(client.loadSession).thenAnswer((_) async => authenticated);

        expect(await repository.loadSession(), authenticated);
        expect(await repository.loadSession(), authenticated);

        verify(client.loadSession).called(2);
        verifyNoMoreInteractions(client);
      });
    }

    for (final status in [403, 429, 500]) {
      test(
        'maps HTTP $status preserving status/type without remote content',
        () async {
          when(client.loadSession).thenThrow(
            HttpResponseException(
              response: Responses(
                status: status,
                body: {'type': 'account_failure', 'message': 'remote-secret'},
              ),
            ),
          );

          await expectLater(
            repository.loadSession(),
            throwsA(
              isA<SessionException>().having(
                (exception) => exception.errors.errors.single,
                'safe service error',
                isA<ErrorEntity>()
                    .having((error) => error.status, 'status', '$status')
                    .having((error) => error.code, 'type', 'account_failure')
                    .having((error) => error.detail, 'detail', isNull)
                    .having((error) => error.title, 'title', isNull),
              ),
            ),
          );
          verify(client.loadSession).called(1);
        },
      );
    }

    for (final failure in HttpExceptionEnum.values) {
      test(
        'transport ${failure.name} is a failure, not an absent session',
        () async {
          when(client.loadSession)
              .thenThrow(HttpTransportException(failure: failure));

          await expectLater(
            repository.loadSession(),
            throwsA(isA<SessionException>()),
          );
          verify(client.loadSession).called(1);
        },
      );
    }

    test('cookie/storage failure is not an absent session', () async {
      when(client.loadSession).thenThrow(HttpUnexpectedException());

      await expectLater(
        repository.loadSession(),
        throwsA(isA<SessionException>()),
      );
      verify(client.loadSession).called(1);
    });

    test('invalid HTTP envelope remains a visible format failure', () async {
      when(client.loadSession)
          .thenThrow(HttpInvalidResponseException(status: 200));

      await expectLater(
        repository.loadSession(),
        throwsA(isA<FormatException>()),
      );
    });

    for (final unexpected in <Object>[
      StateError('unexpected'),
      const FormatException('invalid'),
    ]) {
      test('propagates ${unexpected.runtimeType} unchanged', () async {
        when(client.loadSession).thenThrow(unexpected);

        await expectLater(repository.loadSession(), throwsA(same(unexpected)));
      });
    }
  });

  group('sessionChanges', () {
    test(
      'exposes the exact shared stream without owning its lifecycle',
      () async {
        final changes = StreamController<bool>.broadcast();
        addTearDown(changes.close);
        final stream = changes.stream;
        when(() => client.session).thenAnswer((_) => stream);

        expect(repository.session, same(stream));
        final first = repository.session.listen((_) {});
        final observed = expectLater(
          repository.session,
          emitsInOrder([true, false]),
        );
        await first.cancel();
        changes.add(true);
        changes.add(false);
        await observed;

        verifyNever(client.close);
        verifyNever(client.loadSession);
      },
    );
  });
}
