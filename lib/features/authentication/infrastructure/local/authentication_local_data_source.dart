import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

abstract interface class IAuthenticationLocalDataSource {
  Future<void> saveToken(String token);
}

final class AuthenticationLocalDataSource({
  required final IStorageClient storage,
}) implements IAuthenticationLocalDataSource {
  @override
  Future<void> saveToken(String token) =>
      storage.write(key: StorageKeyEnum.opaqueToken.key, value: token);
}
