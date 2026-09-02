import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class IStorageClient {
  Future<void> clear();

  Future<void> delete({required String key});

  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});
}

final class StorageClient implements IStorageClient {
  final FlutterSecureStorage _storage;

  StorageClient({required this._storage});

  @override
  Future<void> clear() => _storage.deleteAll();

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
