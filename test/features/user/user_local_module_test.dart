import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:localstore/localstore.dart';

import 'package:cordato/features/user/user_module.dart';
import 'package:cordato/features/user/application/repositories/interface_user_repository.dart';

import '../../support/core/storage/localstore_test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads existing JSON and preserves changes across module compositions',
    () async {
      final storage = LocalstoreTestStorage();
      await storage.open();
      addTearDown(storage.close);
      final directory = Directory('${storage.directory.path}/user');
      await directory.create();
      await File('${directory.path}/profile').writeAsString(
        jsonEncode({'name': 'Existing name', 'avatar': 'existing-seed'}),
      );

      final first = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<Localstore>(storage.database)
            ..module(userModule),
        ),
      );
      final repository = first.injector.get<IUserRepository>();
      final original = await repository.get();

      expect(original.name, 'Existing name');
      expect(original.avatar, 'existing-seed');
      expect(first.injector.get<Localstore>(), same(storage.database));

      await storage.writing({
        'Gabriel',
        'chosen-seed',
      }, () => repository.update(name: 'Gabriel', avatar: 'chosen-seed'));
      first.injector.dispose();
      final second = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<Localstore>(storage.database)
            ..module(userModule),
        ),
      );
      addTearDown(second.injector.dispose);
      final reopened = await second.injector.get<IUserRepository>().get();

      expect(reopened.name, 'Gabriel');
      expect(reopened.avatar, 'chosen-seed');
      expect(
        jsonDecode(await File('${directory.path}/profile').readAsString()),
        {'name': 'Gabriel', 'avatar': 'chosen-seed'},
      );
    },
  );
}
