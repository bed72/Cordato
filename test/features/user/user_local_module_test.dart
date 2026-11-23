import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

void main() {
  test('preserves the same profile across module compositions', () async {
    final database = DatabaseClient(executor: NativeDatabase.memory());
    addTearDown(database.close);

    final first = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<DatabaseClient>(database)
          ..module(userModule),
      ),
    );

    try {
      final repository = first.injector.get<IUserRepository>();
      final original = await repository.get();

      await repository.update(name: 'Gabriel', seed: 'chosen-seed');

      expect(first.injector.get<DatabaseClient>(), same(database));

      final second = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<DatabaseClient>(database)
            ..module(userModule),
        ),
      );

      try {
        final reloaded = await second.injector.get<IUserRepository>().get();

        expect(reloaded.id, original.id);
        expect(reloaded.name, 'Gabriel');
        expect(reloaded.seed, 'chosen-seed');
      } finally {
        second.injector.dispose();
      }
    } finally {
      first.injector.dispose();
    }
  });
}
