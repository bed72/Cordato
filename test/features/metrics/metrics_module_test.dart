import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/metrics/metrics_module.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_bloc.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_event.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_state.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';
import '../../support/core/mocks/home_widget_client_mock.dart';

void main() {
  late PocketBaseFixture fixture;
  late ModularBootstrap boot;
  late DateTime first;
  late DateTime last;

  setUp(() {
    final now = DateTime.now();
    first = DateTime(now.year, now.month - 1);
    last = DateTime(first.year, first.month + 1, 0);
    fixture = PocketBaseFixture();
    addTearDown(fixture.client.close);
    fixture.respond = (_) => PocketBaseFixture.jsonResponse({
      'items': [
        {
          'id': 'metrics',
          'categories': [],
          'total_amount': '123',
          'end_date': last.toIso8601String().split('T').first,
          'start_date': first.toIso8601String().split('T').first,
        },
      ],
    });
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context.addInstance<PocketBase>(fixture.client);
          context.addInstance<IHomeWidgetClient>(HomeWidgetClientMock());
          context.module(metricsModule);
        },
      ),
    );
    addTearDown(boot.injector.dispose);
  });

  test('resolves the shared SDK repository and independent Bloc factories without visiting routes', () async {
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
        startDate: first,
        endDate: last,
        groupBy: .category,
      ),
    );
    final data = (await ready).metrics!;

    expect(data.totalAmount, 123);
    expect(data.categories, isEmpty);

    expect(
      fixture.requests.single.url.path,
      '/api/collections/metrics/records',
    );
  });
}
