import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

abstract interface class IAuthenticationLocalDataSource {
  Stream<bool> hasSession();

  Future<void> saveToken(String token);
}

final class AuthenticationLocalDataSource({
  required final IStorageClient storage,
}) implements IAuthenticationLocalDataSource {
  @override
  Stream<bool> hasSession() => storage
      .watch(key: StorageKeyEnum.accessToken.key)
      .map((token) => token != null);

  @override
  Future<void> saveToken(String token) =>
      storage.write(key: StorageKeyEnum.accessToken.key, value: token);
}
