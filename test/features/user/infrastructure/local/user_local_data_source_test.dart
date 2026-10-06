import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/user/infrastructure/local/user_local_data_source.dart';

import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  late StorageClientMock storage;
  late IUserLocalDataSource dataSource;

  setUp(() {
    storage = StorageClientMock();
    dataSource = UserLocalDataSource(storage: storage);
  });

  test('clears all secure storage', () async {
    when(() => storage.clear()).thenAnswer((_) async {});

    await dataSource.clear();

    verify(() => storage.clear()).called(1);
    verifyNoMoreInteractions(storage);
  });

  for (final userId in ['saved-user-id', null]) {
    test(
      'returns the stored user ID $userId without changing storage',
      () async {
        when(() => storage.read(key: StorageKeyEnum.userId.key))
            .thenAnswer((_) async => userId);

        expect(await dataSource.getId(), userId);

        verify(() => storage.read(key: StorageKeyEnum.userId.key)).called(1);
        verifyNoMoreInteractions(storage);
      },
    );
  }

  test('propagates user ID reading failures to the repository', () async {
    final error = StateError('storage unavailable');
    when(() => storage.read(key: StorageKeyEnum.userId.key))
        .thenAnswer((_) async => throw error);

    await expectLater(dataSource.getId(), throwsA(same(error)));

    verify(() => storage.read(key: StorageKeyEnum.userId.key)).called(1);
    verifyNoMoreInteractions(storage);
  });

  test('propagates storage clearing failures to the repository', () async {
    final error = StateError('storage unavailable');
    when(() => storage.clear()).thenAnswer((_) async => throw error);

    await expectLater(dataSource.clear(), throwsA(same(error)));

    verify(() => storage.clear()).called(1);
    verifyNoMoreInteractions(storage);
  });
}
