import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

import '../../../../../support/core/mocks/flutter_secure_storage_mock.dart';

void main() {
  test('uses distinct secure-storage keys for the token and user id', () {
    expect(StorageKeyEnum.userId.key, '@trocado.user_id');
    expect(StorageKeyEnum.opaqueToken.key, '@trocado.opaque_token');
  });

  late IStorageClient client;
  late FlutterSecureStorage storage;

  setUp(() {
    storage = FlutterSecureStorageMock();
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

  test(
    'observes plugin changes by key and unregisters on cancellation',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const plugin = FlutterSecureStorage();
      final observed = StorageClient(storage: plugin);
      final events = <String?>[];
      final otherEvents = <String?>[];
      final subscription = observed.watch(key: 'key').listen(events.add);
      final secondSubscription = observed
          .watch(key: 'key')
          .listen(otherEvents.add);

      await observed.write(key: 'other', value: 'ignored');
      await plugin.write(key: 'key', value: 'first');
      await observed.write(key: 'key', value: 'second');
      await observed.delete(key: 'key');
      await observed.clear();
      await Future<void>.delayed(Duration.zero);

      expect(otherEvents, events);
      expect(events, ['first', 'second', null, null]);
      expect(plugin.getListeners['key'], hasLength(2));

      await subscription.cancel();
      expect(plugin.getListeners['key'], hasLength(1));

      await plugin.write(key: 'key', value: 'third');
      await Future<void>.delayed(Duration.zero);
      expect(otherEvents.last, 'third');
      expect(events, ['first', 'second', null, null]);

      await secondSubscription.cancel();
      expect(plugin.getListeners['key'], isEmpty);
    },
  );
}
