import 'package:cordato/features/core/infrastructure/clients/enums/storage_key_enum.dart';
import 'package:cordato/features/core/infrastructure/clients/storage_client.dart';

abstract interface class IAuthenticationLocalDataSource {
  Future<void> saveToken(String token);
}

final class AuthenticationLocalDataSource({
  required final IStorageClient storage,
}) implements IAuthenticationLocalDataSource {
  @override
  Future<void> saveToken(String token) =>
      storage.write(key: StorageKeyEnum.accessToken.key, value: token);
}
