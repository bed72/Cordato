import 'package:supabase_flutter/supabase_flutter.dart' show LocalStorage;

import 'package:cordato/features/authentication/domain/enums/storage_key.dart';
import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';

final class SupabaseStorageClient extends LocalStorage {
  final IStorageClient _client;

  const SupabaseStorageClient({required this._client});

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() =>
      _client.read(key: StorageKey.supabaseSession.value);

  @override
  Future<void> removePersistedSession() =>
      _client.delete(key: StorageKey.supabaseSession.value);

  @override
  Future<bool> hasAccessToken() async =>
      await _client.read(key: StorageKey.supabaseSession.value) != null;

  @override
  Future<void> persistSession(String persistSessionString) => _client.write(
    key: StorageKey.supabaseSession.value,
    value: persistSessionString,
  );
}
