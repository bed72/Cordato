import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

abstract interface class ISessionLocalDataSource {
  Future<bool> loadSession();
  Stream<bool> get sessionChanges;
}

final class SessionLocalDataSource({required final IStorageClient storage})
    implements ISessionLocalDataSource {
  @override
  Stream<bool> get sessionChanges => storage
      .watch(key: StorageKeyEnum.opaqueToken.key)
      .map((token) => token != null && token.isNotEmpty);

  @override
  Future<bool> loadSession() async {
    final token = await storage.read(key: StorageKeyEnum.opaqueToken.key);

    return token != null && token.isNotEmpty;
  }
}
