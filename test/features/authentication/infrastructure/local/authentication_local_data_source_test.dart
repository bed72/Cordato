import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/infrastructure/local/authentication_local_data_source.dart';
import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/enums/storage_key_enum.dart';

class _StorageClientMock extends Mock implements IStorageClient {}

void main() {
  test('saves the sign-in token in secure storage', () async {
    final storage = _StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(
      () => storage.write(
        key: StorageKeyEnum.accessToken.key,
        value: 'opaque-token',
      ),
    ).thenAnswer((_) async {});

    await dataSource.saveToken('opaque-token');

    verify(
      () => storage.write(
        key: StorageKeyEnum.accessToken.key,
        value: 'opaque-token',
      ),
    ).called(1);
  });

  test('propagates storage failures to the repository', () async {
    final storage = _StorageClientMock();
    final dataSource = AuthenticationLocalDataSource(storage: storage);
    when(
      () => storage.write(
        key: StorageKeyEnum.accessToken.key,
        value: 'opaque-token',
      ),
    ).thenAnswer((_) async => throw StateError('storage unavailable'));

    await expectLater(
      dataSource.saveToken('opaque-token'),
      throwsA(isA<StateError>()),
    );
  });
}
