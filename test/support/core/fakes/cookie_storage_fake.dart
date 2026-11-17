import 'package:cookie_jar/cookie_jar.dart';

final class CookieStorageFake({required final Storage storage})
    implements Storage {
  Future<void> Function(String key)? beforeRead;
  Future<void> Function(String key, String value)? beforeWrite;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) =>
      storage.init(persistSession, ignoreExpires);

  @override
  Future<String?> read(String key) async {
    await beforeRead?.call(key);
    return storage.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    await beforeWrite?.call(key, value);
    await storage.write(key, value);
  }

  @override
  Future<void> delete(String key) => storage.delete(key);

  @override
  Future<void> deleteAll(List<String> keys) => storage.deleteAll(keys);
}
