import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show LocalStorage;

import 'package:cordato/features/authentication/domain/enums/storage_key.dart';
import 'package:cordato/features/authentication/infrastructure/clients/supabase_storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';

class _StorageClientMock extends Mock implements IStorageClient {}

void main() {
  late IStorageClient storage;
  late LocalStorage client;

  setUp(() {
    storage = _StorageClientMock();
    client = SupabaseStorageClient(client: storage);
  });

  group('SupabaseStorageClient', () {
    test('initializes without interacting with the storage client', () async {
      await client.initialize();

      verifyNoMoreInteractions(storage);
    });

    test('returns true when a persisted session exists', () async {
      when(() => storage.read(key: StorageKey.supabaseSession.value))
          .thenAnswer((_) async => 'session');

      final hasAccessToken = await client.hasAccessToken();

      expect(hasAccessToken, isTrue);
      verify(() => storage.read(key: StorageKey.supabaseSession.value))
          .called(1);
    });

    test('returns false when there is no persisted session', () async {
      when(() => storage.read(key: StorageKey.supabaseSession.value))
          .thenAnswer((_) async => null);

      final hasAccessToken = await client.hasAccessToken();

      expect(hasAccessToken, isFalse);
      verify(() => storage.read(key: StorageKey.supabaseSession.value))
          .called(1);
    });

    test('returns the persisted session', () async {
      when(() => storage.read(key: StorageKey.supabaseSession.value))
          .thenAnswer((_) async => 'session');

      final session = await client.accessToken();

      expect(session, 'session');
      verify(() => storage.read(key: StorageKey.supabaseSession.value))
          .called(1);
    });

    test('removes the persisted session', () async {
      when(() => storage.delete(key: StorageKey.supabaseSession.value))
          .thenAnswer((_) async {});

      await client.removePersistedSession();

      verify(() => storage.delete(key: StorageKey.supabaseSession.value))
          .called(1);
    });

    test('persists a session', () async {
      when(
        () => storage.write(
          key: StorageKey.supabaseSession.value,
          value: 'session',
        ),
      ).thenAnswer((_) async {});

      await client.persistSession('session');

      verify(
        () => storage.write(
          key: StorageKey.supabaseSession.value,
          value: 'session',
        ),
      ).called(1);
    });
  });
}
