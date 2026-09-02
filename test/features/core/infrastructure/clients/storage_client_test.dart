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

  group('StorageClient', () {
    test('clears all stored values', () async {
      when(storage.deleteAll).thenAnswer((_) async {});

      await client.clear();

      verify(storage.deleteAll).called(1);
    });

    test('writes a value with its key', () async {
      when(() => storage.write(key: 'access_token', value: 'token'))
          .thenAnswer((_) async {});

      await client.write(key: 'access_token', value: 'token');

      verify(() => storage.write(key: 'access_token', value: 'token'))
          .called(1);
    });

    test('reads a value with its key', () async {
      when(() => storage.read(key: 'access_token'))
          .thenAnswer((_) async => 'token');

      final value = await client.read(key: 'access_token');

      expect(value, 'token');
      verify(() => storage.read(key: 'access_token')).called(1);
    });

    test('returns null when a key does not exist', () async {
      when(() => storage.read(key: 'missing')).thenAnswer((_) async => null);

      final value = await client.read(key: 'missing');

      expect(value, isNull);
      verify(() => storage.read(key: 'missing')).called(1);
    });

    test('deletes a value with its key', () async {
      when(() => storage.delete(key: 'access_token')).thenAnswer((_) async {});

      await client.delete(key: 'access_token');

      verify(() => storage.delete(key: 'access_token')).called(1);
    });
  });
}
