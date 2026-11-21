import 'package:tostore/tostore.dart';

abstract final class ToStoreFactory {
  static Future<ToStore> create({
    required String directory,
    required List<TableSchema> schemas,
  }) {
    ToStore.setLogConfig(enableLog: false);

    return ToStore.open(
      schemas: schemas,
      dbName: 'cordato',
      dbPath: directory,
      config: DataStoreConfig(defaultRecoveryDurability: .durable),
    );
  }
}
