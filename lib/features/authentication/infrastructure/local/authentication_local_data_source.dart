import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

abstract interface class IAuthenticationLocalDataSource {
  Future<void> remove();

  Future<void> save(String token);
}

final class AuthenticationLocalDataSource({
  required final IStorageClient storage,
}) implements IAuthenticationLocalDataSource {
  @override
  Future<void> remove() => storage.delete(key: StorageKeyEnum.opaqueToken.key);

  @override
  Future<void> save(String token) =>
      storage.write(key: StorageKeyEnum.opaqueToken.key, value: token);
}
