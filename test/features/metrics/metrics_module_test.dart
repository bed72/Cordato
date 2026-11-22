import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:localstore/localstore.dart';

import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/metrics/metrics_module.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import '../../support/core/mocks/widget_client_mock.dart';
import '../../support/core/storage/localstore_test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = LocalstoreTestStorage();
  late ModularBootstrap boot;

  setUpAll(storage.open);
  tearDownAll(storage.close);

  setUp(() async {
    await storage.expense(() async {
      await storage.database.collection('expenses').doc('first').set({
        'id': 'first',
        'amount': 123,
        'category': 'food',
        'occurred_on': '2026-10-01T00:00:00.000Z',
      });
    });
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context.addInstance<Localstore>(storage.database);
          context.addInstance<IWidgetClient>(WidgetClientMock());
          context.module(metricsModule);
        },
      ),
    );
  });

  tearDown(() async {
    boot.injector.dispose();
    await storage.clear();
  });

  test('resolves the shared local repository without routes', () async {
    final repository = inject<IMetricsRepository>();
    expect(inject<IMetricsRepository>(), same(repository));

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

      final records = await storage.database.collection('expenses').get();

      expect((records!.values.single as Map<String, dynamic>)['amount'], 123);
    },
  );
}
