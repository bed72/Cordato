import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  late ModularBootstrap boot;

  setUp(() {
    boot = bootstrapModule(coreModule);
  });

  tearDown(() {
    boot.injector.dispose();
  });

  test('formatters resolve as shared capabilities without feature routes', () {
    final money = boot.injector.get<IMoneyFormatter>();
    final date = boot.injector.get<IDateFormatter>();

    expect(boot.injector.get<IMoneyFormatter>(), same(money));
    expect(boot.injector.get<IDateFormatter>(), same(date));
    expect(boot.routes.routes, isEmpty);
  });

  test('native widget client resolves before any feature route', () {
    final client = boot.injector.get<IWidgetClient>();

    expect(client, isA<WidgetClient>());
    expect(boot.injector.get<IWidgetClient>(), same(client));
  });
}
