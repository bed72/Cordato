import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/http/enums/http_exception_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/http/exceptions/http_client_exception.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/authentication/application/exceptions/authentication_exception.dart';
import 'package:cordato/features/authentication/infrastructure/repositories/authentication_repository.dart';

import '../../../../support/core/mocks/http_client_mock.dart';
import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  late HttpClientMock client;
  late StorageClientMock storage;
  late AuthenticationRepository repository;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    storage = StorageClientMock();
    repository = AuthenticationRepository(
      httpClient: client,
      storageClient: storage,
    );
    when(() => storage.read(key: StorageKeyEnum.userId.key))
        .thenAnswer((_) async => 'user/1');
    when(() => client.patch(parameter: any(named: 'parameter')))
        .thenAnswer((_) async => const Responses(status: 200, body: {}));
  });

  Future<void> change() => repository.changePassword(
    oldPassword: ' old ',
    password: ' NewPass1 ',
    passwordConfirm: ' NewPass1 ',
  );

  void verifyIdOnly() {
    verify(() => storage.read(key: StorageKeyEnum.userId.key)).called(1);
    verifyNoMoreInteractions(storage);
  }

  test(
    'sends exact native payload and encoded ID without session changes',
    () async {
      await change();
      final request =
          verify(() => client.patch(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'collections/users/records/user%2F1');
      expect(request.body, {
        'oldPassword': ' old ',
        'password': ' NewPass1 ',
        'passwordConfirm': ' NewPass1 ',
      });
      expect(request.headers, isNull);
      expect(request.query, isNull);
      verifyIdOnly();
      verifyNoMoreInteractions(client);
    },
  );

  group('Identity', () {
    for (final id in [null, '', '   ']) {
      test('rejects missing identity $id before HTTP', () async {
        when(() => storage.read(key: StorageKeyEnum.userId.key))
            .thenAnswer((_) async => id);
        await expectLater(change(), throwsA(isA<AuthenticationException>()));
        verifyIdOnly();
        verifyZeroInteractions(client);
      });
    }

    test('waits for identity before HTTP', () async {
      final read = Completer<String?>();
      final started = Completer<void>();
      when(() => storage.read(key: StorageKeyEnum.userId.key)).thenAnswer((_) {
        started.complete();
        return read.future;
      });
      final pending = change();
      await started.future;
      verifyZeroInteractions(client);
      read.complete('user-1');
      await pending;
    });

    test('propagates storage failures without HTTP', () async {
      final failure = StateError('fixture');
      when(() => storage.read(key: StorageKeyEnum.userId.key))
          .thenThrow(failure);
      await expectLater(change(), throwsA(same(failure)));
      verifyZeroInteractions(client);
    });
  });

  group('Remote completion and failures', () {
    test('awaits PATCH completion', () async {
      final patched = Completer<Responses>();
      final started = Completer<void>();
      when(() => client.patch(parameter: any(named: 'parameter')))
          .thenAnswer((_) {
            started.complete();
            return patched.future;
          });
      var completed = false;
      final pending = change()..then((_) => completed = true);
      await started.future;
      expect(completed, isFalse);
      patched.complete(const Responses(status: 200, body: {}));
      await pending;
      expect(completed, isTrue);
    });

    for (final status in [201, 204]) {
      test('rejects unexpected success status $status', () async {
        when(() => client.patch(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => Responses(status: status, body: {}));
        await expectLater(change(), throwsA(isA<AuthenticationException>()));
        verifyIdOnly();
      });
    }

    test(
      'preserves HTTP metadata and ordering without clearing storage',
      () async {
        when(() => client.patch(parameter: any(named: 'parameter'))).thenThrow(
          HttpResponseException.fromResponse(
            const Responses(
              status: 400,
              body: {
                'message': 'remote',
                'data': {
                  'oldPassword': {
                    'code': 'validation_invalid_old_password',
                    'message': 'remote',
                  },
                  'passwordConfirm': {
                    'code': 'validation_values_mismatch',
                    'message': 'remote',
                  },
                },
              },
            ),
          ),
        );
        await expectLater(
          change(),
          throwsA(
            isA<AuthenticationException>()
                .having(
                  (e) => e.errors.errors.map((e) => e.pointer),
                  'pointers',
                  ['/oldPassword', '/passwordConfirm'],
                )
                .having(
                  (e) => e.errors.errors.first.code,
                  'code',
                  'validation_invalid_old_password',
                )
                .having(
                  (e) => e.errors.errors.first.parameter,
                  'parameter',
                  'oldPassword',
                )
                .having((e) => e.errors.errors.first.status, 'status', '400'),
          ),
        );
        verifyIdOnly();
        verify(() => client.patch(parameter: any(named: 'parameter')))
            .called(1);
        verifyNoMoreInteractions(client);
      },
    );

    test('maps client failure to application fallback', () async {
      when(() => client.patch(parameter: any(named: 'parameter'))).thenThrow(
        HttpTransportException(failure: HttpExceptionEnum.connection),
      );
      await expectLater(change(), throwsA(isA<AuthenticationException>()));
      verifyIdOnly();
    });

    test('does not mask unexpected programming errors', () async {
      final failure = FormatException('fixture');
      when(() => client.patch(parameter: any(named: 'parameter')))
          .thenThrow(failure);
      await expectLater(change(), throwsA(same(failure)));
      verifyIdOnly();
    });
  });
}
