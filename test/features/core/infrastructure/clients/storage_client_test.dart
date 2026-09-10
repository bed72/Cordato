import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';

class _FlutterSecureStorageMock extends Mock implements FlutterSecureStorage {}

void main() {
  late FlutterSecureStorage storage;
  late IStorageClient client;

  setUp(() {
    storage = _FlutterSecureStorageMock();
    client = StorageClient(storage: storage);
  });

  test('clears all secure values', () async {
    when(() => storage.deleteAll()).thenAnswer((_) async {});

    await client.clear();

    verify(() => storage.deleteAll()).called(1);
  });

  test('writes a value with its key', () async {
    when(() => storage.write(key: 'key', value: 'value'))
        .thenAnswer((_) async {});

    await client.write(key: 'key', value: 'value');

    verify(() => storage.write(key: 'key', value: 'value')).called(1);
  });

  test('reads a value with its key', () async {
    when(() => storage.read(key: 'key')).thenAnswer((_) async => 'value');

    expect(await client.read(key: 'key'), 'value');

    verify(() => storage.read(key: 'key')).called(1);
  });

  test('deletes a value with its key', () async {
    when(() => storage.delete(key: 'key')).thenAnswer((_) async {});

    await client.delete(key: 'key');

    verify(() => storage.delete(key: 'key')).called(1);
  });
}
