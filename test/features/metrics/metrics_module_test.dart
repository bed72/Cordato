import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/metrics_module.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_bloc.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_event.dart';
import 'package:cordato/features/metrics/presentation/bloc/expense_metrics_state.dart';

import '../../support/core/mocks/http_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));

  test(
    'binds the contract to one HTTP-backed repository without a data source',
    () async {
      final http = HttpClientMock();
      when(() => http.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'data': {
              'id': 'metrics',
              'attributes': {
                'total_amount': '123',
                'start_date': '2026-10-01',
                'end_date': '2026-10-31',
                'categories': [],
              },
            },
          },
        ),
      );
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context.addInstance<IHttpClient>(http);
            context.module(metricsModule);
          },
        ),
      );
      addTearDown(boot.injector.dispose);
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
      final data = (await ready).metrics!;
      expect(data.totalAmount, 123);
      expect(data.categories, isEmpty);
      final request =
          verify(() => http.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'metrics/expenses');
      expect(request.query, {
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'group_by': 'category',
      });
      verifyNoMoreInteractions(http);
    },
  );
}
