import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';

abstract interface class IUserLocalDataSource {
  Future<void> clear();

  Future<String?> getId();
}

final class UserLocalDataSource({required final IStorageClient storage})
    implements IUserLocalDataSource {
  @override
  Future<void> clear() => storage.clear();

  @override
  Future<String?> getId() => storage.read(key: StorageKeyEnum.userId.key);
}
