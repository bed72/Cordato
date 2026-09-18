import 'package:supabase_flutter/supabase_flutter.dart' show LocalStorage;

import 'package:cordato/features/authentication/domain/enums/storage_key.dart';
import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';

final class const SupabaseStorageClient({required final IStorageClient client})
    extends LocalStorage {
  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() =>
      client.read(key: StorageKey.supabaseSession.value);

  @override
  Future<void> removePersistedSession() =>
      client.delete(key: StorageKey.supabaseSession.value);

  @override
  Future<bool> hasAccessToken() async =>
      await client.read(key: StorageKey.supabaseSession.value) != null;

  @override
  Future<void> persistSession(String persistSessionString) => client.write(
    key: StorageKey.supabaseSession.value,
    value: persistSessionString,
  );
}
