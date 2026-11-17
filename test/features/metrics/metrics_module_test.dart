import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';

import 'package:cordato/features/metrics/metrics_module.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_bloc.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_event.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_state.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import '../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  late MetricsRepositoryMock repository;
  late ModularBootstrap boot;
  late DateTime first;
  late DateTime last;

  setUp(() {
    final now = DateTime.now();
    first = DateTime(now.year, now.month - 1);
    last = DateTime(first.year, first.month + 1, 0);
    repository = MetricsRepositoryMock();
    when(
      () => repository.getExpenses(
        startDate: first,
        endDate: last,
        groupBy: .category,
      ),
    ).thenAnswer(
      (_) async => ExpenseMetricsEntity(
        id: 'metrics',
        categories: [],
        totalAmount: 123,
        startDate: first,
        endDate: last,
      ),
    );
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context.addInstance<IMetricsRepository>(repository);
          context.module(metricsModule);
        },
      ),
    );
    addTearDown(boot.injector.dispose);
  });

  test('resolves the supplied repository and independent Bloc factories without visiting routes', () async {
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
        startDate: first,
        endDate: last,
        groupBy: .category,
      ),
    );
    final data = (await ready).metrics!;

    expect(data.totalAmount, 123);
    expect(data.categories, isEmpty);

    verify(
      () => repository.getExpenses(
        startDate: first,
        endDate: last,
        groupBy: .category,
      ),
    ).called(1);
  });
}
