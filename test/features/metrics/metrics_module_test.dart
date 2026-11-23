import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';

import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/metrics/infrastructure/daos/metrics_dao.dart';
import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/metrics/metrics_module.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import '../../support/core/mocks/widget_client_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseClient database;
  late ModularBootstrap boot;

  setUp(() async {
    database = DatabaseClient(executor: NativeDatabase.memory());
    final profileId = await database
        .into(database.profilesTable)
        .insert(ProfilesTableCompanion.insert(name: 'Cordato', seed: 'seed'));
    await database
        .into(database.expensesTable)
        .insert(
          ExpensesTableCompanion.insert(
            profileId: profileId,
            amount: 123,
            category: const Value('food'),
            occurredOn: const Value('2026-10-01'),
          ),
        );
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context.addInstance<DatabaseClient>(database);
          context.addInstance<IWidgetClient>(WidgetClientMock());
          context.module(metricsModule);
        },
      ),
    );
  });

  tearDown(() async {
    boot.injector.dispose();
    await database.close();
  });

  test('resolves the shared local repository without routes', () async {
    final repository = inject<IMetricsRepository>();
    expect(inject<IMetricsRepository>(), same(repository));
    final dao = inject<MetricsDao>();
    expect(inject<MetricsDao>(), same(dao));
    expect(dao.attachedDatabase, same(database));

    final metrics = await repository.getExpenses(
      startDate: DateTime(2026, 10),
      endDate: DateTime(2026, 10, 31),
      groupBy: .category,
    );

    expect(metrics.total, 123);
    expect(metrics.categories!.single.category, 'food');
    expect(metrics.categories!.single.percentage, 100);
  });

  test(
    'disposing the module does not close the bootstrap-owned database',
    () async {
      inject<IMetricsRepository>();
      boot.injector.dispose();

      final records = await database.select(database.expensesTable).get();

      expect(records.single.amount, 123);
    },
  );
}
