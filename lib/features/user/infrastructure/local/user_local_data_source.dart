import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';

abstract interface class IUserLocalDataSource {
  Future<void> clear();
}

final class UserLocalDataSource({required final IStorageClient storage})
    implements IUserLocalDataSource {
  @override
  Future<void> clear() => storage.clear();
}
