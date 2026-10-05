import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/infrastructure/local/authentication_local_data_source.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

class _StorageClientMock extends Mock implements IStorageClient {}

void main() {
  test('removes only the session token from secure storage', () async {
    final storage = _StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(() => storage.delete(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async {});

    await dataSource.remove();

    verify(() => storage.delete(key: StorageKeyEnum.opaqueToken.key)).called(1);
    verifyNoMoreInteractions(storage);
  });

  test('propagates token removal failures to the repository', () async {
    final storage = _StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(() => storage.delete(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) async => throw StateError('storage unavailable'));

    await expectLater(dataSource.remove(), throwsA(isA<StateError>()));
  });

  test('saves the sign-in token in secure storage', () async {
    final storage = _StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(
      () => storage.write(
        key: StorageKeyEnum.opaqueToken.key,
        value: 'opaque-token',
      ),
    ).thenAnswer((_) async {});

    await dataSource.save('opaque-token');

    verify(
      () => storage.write(
        key: StorageKeyEnum.opaqueToken.key,
        value: 'opaque-token',
      ),
    ).called(1);
  });

  test('propagates storage failures to the repository', () async {
    final storage = _StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(
      () => storage.write(
        key: StorageKeyEnum.opaqueToken.key,
        value: 'opaque-token',
      ),
    ).thenAnswer((_) async => throw StateError('storage unavailable'));

    await expectLater(
      dataSource.save('opaque-token'),
      throwsA(isA<StateError>()),
    );
  });
}
