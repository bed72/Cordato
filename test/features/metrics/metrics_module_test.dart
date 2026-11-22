import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:tostore/tostore.dart';

import 'package:cordato/features/core/application/clients/interface_widget_client.dart';
import 'package:cordato/features/core/infrastructure/clients/tostore/tostore_factory.dart';
import 'package:cordato/features/expense/infrastructure/schemas/expense_schema.dart';
import 'package:cordato/features/metrics/metrics_module.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_bloc.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_event.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_state.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import '../../support/core/mocks/home_widget_client_mock.dart';

void main() {
  late Directory directory;
  late ToStore database;
  late ModularBootstrap boot;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cordato-metrics-di-');
    database = await ToStoreFactory.create(
      directory: directory.path,
      schemas: [expenseSchema],
    );
    final savedExpense = await database.insert('expenses', {
      'amount': 123,
      'category': 'food',
      'occurred_on': '2026-10-01T00:00:00.000Z',
    });
    expect(savedExpense.hasErrors, isFalse);
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context.addInstance<ToStore>(database);
          context.addInstance<IWidgetClient>(HomeWidgetClientMock());
          context.module(metricsModule);
        },
      ),
    );
  });

  tearDown(() async {
    boot.injector.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  test('resolves the shared local repository and independent Bloc factories without routes', () async {
    final repository = inject<IMetricsRepository>();
    expect(inject<IMetricsRepository>(), same(repository));

    final bloc = inject<ExpenseMetricsBloc>();
    final other = inject<ExpenseMetricsBloc>();
    addTearDown(bloc.close);
    addTearDown(other.close);
    expect(bloc, isNot(same(other)));
    expect(other.state, isA<ExpenseMetricsInitial>());

    final ready = bloc.stream.firstWhere(
      (state) => state is ExpenseMetricsSuccess,
    );
    bloc.add(
      ExpenseMetricsRequestedEvent(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
        groupBy: .category,
      ),
    );
    final metrics = (await ready).metrics!;

    expect(metrics.totalAmount, 123);
    expect(metrics.categories!.single.category, 'food');
    expect(metrics.categories!.single.percentage, 100);
  });

  test(
    'disposing the module does not close the bootstrap-owned database',
    () async {
      inject<IMetricsRepository>();
      boot.injector.dispose();

      final records = await database.query('expenses').future;

      expect(records.hasErrors, isFalse);
      expect(records.data.single['amount'], 123);
    },
  );
}
