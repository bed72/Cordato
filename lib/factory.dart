import 'package:path_provider/path_provider.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/features/expense/infrastructure/schemas/expense_schema.dart';
import 'package:cordato/features/user/infrastructure/storage/profile_initializer.dart';
import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';

Future<Module> createDependencies() async {
  final directory = await getApplicationSupportDirectory();

  final database = await ToStoreFactory.create(
    schemas: [expenseSchema],
    directory: directory.path,
  );

  try {
    await initializeProfile(database: database);

    return createAppModule(database: database);
  } catch (error, stackTrace) {
    try {
      await database.close();
    } finally {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
