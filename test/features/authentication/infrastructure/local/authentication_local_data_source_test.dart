import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/authentication/infrastructure/local/authentication_local_data_source.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  test('clears secure storage on logout', () async {
    final storage = StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(() => storage.clear()).thenAnswer((_) async {});

    await dataSource.clear();

    verify(() => storage.clear()).called(1);
    verifyNoMoreInteractions(storage);
  });

  test('propagates storage clearing failures to the repository', () async {
    final storage = StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(() => storage.clear())
        .thenAnswer((_) async => throw StateError('storage unavailable'));

    await expectLater(dataSource.clear(), throwsA(isA<StateError>()));
  });

  test('saves the sign-in token in secure storage', () async {
    final storage = StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(
      () => storage.write(
        key: StorageKeyEnum.opaqueToken.key,
        value: 'opaque-token',
      ),
    ).thenAnswer((_) async {});

    await dataSource.saveToken('opaque-token');

    verify(
      () => storage.write(
        key: StorageKeyEnum.opaqueToken.key,
        value: 'opaque-token',
      ),
    ).called(1);
  });

  test('saves the sign-in user id separately from the token', () async {
    final storage = StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(() => storage.write(key: StorageKeyEnum.userId.key, value: 'user-1'))
        .thenAnswer((_) async {});

    await dataSource.saveUserId('user-1');

    verify(() => storage.write(key: StorageKeyEnum.userId.key, value: 'user-1'))
        .called(1);
    verifyNoMoreInteractions(storage);
  });

  test('propagates user id persistence failures to the repository', () async {
    final storage = StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(() => storage.write(key: StorageKeyEnum.userId.key, value: 'user-1'))
        .thenAnswer((_) async => throw StateError('storage unavailable'));

    await expectLater(
      dataSource.saveUserId('user-1'),
      throwsA(isA<StateError>()),
    );
  });

  test('propagates token persistence failures to the repository', () async {
    final storage = StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(
      () => storage.write(
        key: StorageKeyEnum.opaqueToken.key,
        value: 'opaque-token',
      ),
    ).thenAnswer((_) async => throw StateError('storage unavailable'));

    await expectLater(
      dataSource.saveToken('opaque-token'),
      throwsA(isA<StateError>()),
    );
  });
}
