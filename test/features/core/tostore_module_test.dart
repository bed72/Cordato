import 'dart:io';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

void main() {
  test('core shares the ready database without taking its ownership', () async {
    final directory = await Directory.systemTemp.createTemp('cordato-di-');
    addTearDown(() => directory.delete(recursive: true));
    final database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: const [],
    );
    addTearDown(database.close);
    final boot = bootstrapModule(createCoreModule(database: database));

    expect(boot.injector.get<ToStore>(), same(database));
    expect(boot.injector.get<ToStore>(), same(database));
    final formatter = boot.injector.get<IMoneyFormatter>();
    expect(boot.injector.get<IMoneyFormatter>(), same(formatter));

    boot.injector.dispose();
    final savedSetting = await database.setValue('after-dispose', true);
    expect(savedSetting.hasErrors, isFalse);
  });
}
