import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/session/application/repositories/interface_session_repository.dart';

final class SessionRepository({required final IStorageClient storage})
    implements ISessionRepository {
  @override
  Future<bool> loadSession() async {
    final token = await storage.read(key: StorageKeyEnum.opaqueToken.key);
    return token != null && token.isNotEmpty;
  }

  @override
  Stream<bool> get sessionChanges => storage
      .watch(key: StorageKeyEnum.opaqueToken.key)
      .map((token) => token != null && token.isNotEmpty);
}
