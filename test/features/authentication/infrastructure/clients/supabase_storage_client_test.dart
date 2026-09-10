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

  test('initializes without changing the secure storage', () async {
    await client.initialize();

    verifyNever(() => storage.clear());
    verifyNever(() => storage.delete(key: any(named: 'key')));
    verifyNever(() => storage.read(key: any(named: 'key')));
    verifyNever(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });

  test('reports whether a persisted session exists', () async {
    when(() => storage.read(key: StorageKey.supabaseSession.value))
        .thenAnswer((_) async => 'session');

    expect(await client.hasAccessToken(), isTrue);
    verify(() => storage.read(key: StorageKey.supabaseSession.value)).called(1);
  });

  test('reports when no persisted session exists', () async {
    when(() => storage.read(key: StorageKey.supabaseSession.value))
        .thenAnswer((_) async => null);

    expect(await client.hasAccessToken(), isFalse);
    verify(() => storage.read(key: StorageKey.supabaseSession.value)).called(1);
  });

  test('returns the persisted session', () async {
    when(() => storage.read(key: StorageKey.supabaseSession.value))
        .thenAnswer((_) async => 'session');

    expect(await client.accessToken(), 'session');
    verify(() => storage.read(key: StorageKey.supabaseSession.value)).called(1);
  });

  test('removes the persisted session', () async {
    when(() => storage.delete(key: StorageKey.supabaseSession.value))
        .thenAnswer((_) async {});

    await client.removePersistedSession();

    verify(() => storage.delete(key: StorageKey.supabaseSession.value))
        .called(1);
  });

  test('persists a Supabase session securely', () async {
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
}
