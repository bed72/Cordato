import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import 'package:cordato/features/session/infrastructure/local/session_local_data_source.dart';

class _StorageClientMock extends Mock implements IStorageClient {}

void main() {
  late _StorageClientMock storage;
  late SessionLocalDataSource dataSource;

  setUp(() {
    storage = _StorageClientMock();
    dataSource = SessionLocalDataSource(storage: storage);
  });

  test('reads the existing token before navigation', () async {
    for (final (token, expected) in [
      ('opaque-token', true),
      (null, false),
      ('', false),
    ]) {
      when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
          .thenAnswer((_) async => token);
      expect(await dataSource.loadSession(), expected);
    }
    verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key)).called(3);
  });

  test(
    'reports token creation and removal without exposing its value',
    () async {
      when(() => storage.watch(key: StorageKeyEnum.opaqueToken.key)).thenAnswer(
        (_) => Stream<String?>.fromIterable(['opaque-token', null, '']),
      );

      await expectLater(
        dataSource.sessionChanges,
        emitsInOrder([true, false, false]),
      );
      verify(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
          .called(1);
    },
  );

  test('propagates storage failures', () async {
    final failure = StateError('storage unavailable');
    when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
        .thenThrow(failure);
    when(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
        .thenAnswer((_) => Stream<String?>.error(failure));

    await expectLater(dataSource.loadSession(), throwsA(same(failure)));
    await expectLater(dataSource.sessionChanges, emitsError(same(failure)));
  });
}
