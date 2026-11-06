import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final class SecureStorageChannelFake({
  required final FlutterSecureStorage storage,
}) {
  static const MethodChannel _channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handle);
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }

  Future<Object?> _handle(MethodCall call) async {
    final arguments = call.arguments as Map<Object?, Object?>;
    final key = arguments['key'] as String;

    switch (call.method) {
      case 'read':
        return storage.read(key: key);
      case 'write':
        await storage.write(key: key, value: arguments['value'] as String);
        return null;
      case 'delete':
        await storage.delete(key: key);
        return null;
      default:
        throw MissingPluginException('Unexpected secure storage operation');
    }
  }
}
