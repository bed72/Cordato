import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'infrastructure/clients/storage_client.dart';

final coreModule = createModule(
  register: (context) {
    context
      ..addSingleton<IStorageClient>(StorageClient.new)
      ..addInstance<FlutterSecureStorage>(const FlutterSecureStorage());
  },
);
