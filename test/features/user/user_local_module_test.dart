import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';
import 'package:cordato/features/user/infrastructure/storage/profile_initializer.dart';

void main() {
  test(
    'profile changes survive a new database and module composition',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cordato-user-local-',
      );
      addTearDown(() => directory.delete(recursive: true));
      ToStore database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: const [],
      );
      addTearDown(() => database.close());
      await initializeProfile(database: database);
      final first = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<ToStore>(database)
            ..module(userModule),
        ),
      );
      final repository = first.injector.get<IUserRepository>();

      await repository.update(name: 'Gabriel', avatar: 'chosen-seed');
      first.injector.dispose();
      await database.close();
      database = await ToStoreFactory.create(
        directory: directory.path,
        schemas: const [],
      );
      await initializeProfile(database: database);
      final second = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<ToStore>(database)
            ..module(userModule),
        ),
      );
      addTearDown(second.injector.dispose);
      final reopened = await second.injector.get<IUserRepository>().get();

      expect(reopened.name, 'Gabriel');
      expect(reopened.avatar, 'chosen-seed');
    },
  );
}
