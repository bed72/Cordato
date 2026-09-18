import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class IStorageClient {
  Future<void> clear();

  Future<void> delete({required String key});

  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});
}

final class StorageClient({required final FlutterSecureStorage storage})
    implements IStorageClient {
  @override
  Future<void> clear() => storage.deleteAll();

  @override
  Future<void> delete({required String key}) => storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      storage.write(key: key, value: value);
}
