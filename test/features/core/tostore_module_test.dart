import 'dart:io';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tostore/tostore.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:cordato/features/core/infrastructure/clients/home_widget/home_widget_client.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  late Directory directory;
  late ToStore database;
  late ModularBootstrap boot;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-di-');
    database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: const [],
    );
    boot = bootstrapModule(createCoreModule(database: database));
  });

  tearDown(() async {
    boot.injector.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('core shares the ready database without taking its ownership', () async {
    expect(boot.injector.get<ToStore>(), same(database));
    expect(boot.injector.get<ToStore>(), same(database));

    boot.injector.dispose();
    final savedSetting = await database.setValue('after-dispose', true);
    expect(savedSetting.hasErrors, isFalse);
    expect(await database.getValue('after-dispose'), isTrue);
  });

  test('formatters resolve as shared capabilities without feature routes', () {
    final money = boot.injector.get<IMoneyFormatter>();
    final date = boot.injector.get<IDateFormatter>();

    expect(boot.injector.get<IMoneyFormatter>(), same(money));
    expect(boot.injector.get<IDateFormatter>(), same(date));
    expect(boot.routes.routes, isEmpty);
  });

  test('native widget client resolves before any feature route', () {
    final client = boot.injector.get<IHomeWidgetClient>();

    expect(client, isA<HomeWidgetClient>());
    expect(boot.injector.get<IHomeWidgetClient>(), same(client));
  });
}
