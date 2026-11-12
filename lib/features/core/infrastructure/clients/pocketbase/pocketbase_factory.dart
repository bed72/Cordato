import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class PocketBaseFactory {
  const PocketBaseFactory._();

  static const _key = '@cordato.pocketbase_auth';

  static Future<PocketBase> create({required String url}) async {
    const storage = FlutterSecureStorage();

    final authStore = AsyncAuthStore(
      clear: () => storage.delete(key: _key),
      initial: await storage.read(key: _key),
      save: (value) => storage.write(key: _key, value: value),
    );

    return PocketBase(url, lang: 'pt-BR', authStore: authStore)
      ..autoClearAuthStore(false);
  }
}
