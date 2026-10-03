import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

abstract interface class IAuthenticationLocalDataSource {
  Future<void> saveToken(String token);

  Future<void> removeToken();
}

final class AuthenticationLocalDataSource({
  required final IStorageClient storage,
}) implements IAuthenticationLocalDataSource {
  @override
  Future<void> removeToken() =>
      storage.delete(key: StorageKeyEnum.opaqueToken.key);

  @override
  Future<void> saveToken(String token) =>
      storage.write(key: StorageKeyEnum.opaqueToken.key, value: token);
}
