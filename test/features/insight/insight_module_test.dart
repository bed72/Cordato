import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/insight/application/repositories/interface_insight_repository.dart';
import 'package:cordato/features/insight/insight_module.dart';
import 'package:cordato/features/insight/presentation/bloc/insights_bloc.dart';
import 'package:cordato/features/insight/presentation/bloc/insights_event.dart';
import 'package:cordato/features/insight/presentation/bloc/insights_state.dart';

import '../../support/core/mocks/http_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));

  test(
    'binds one HTTP-backed repository by contract without a data source',
    () async {
      final http = HttpClientMock();
      when(() => http.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(status: 200, body: {'data': []}),
      );
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context.addInstance<IHttpClient>(http);
            context.module(insightModule);
          },
        ),
      );
      addTearDown(boot.injector.dispose);
      final repository = inject<IInsightRepository>();
      expect(inject<IInsightRepository>(), same(repository));
      final bloc = inject<InsightsBloc>();
      final other = inject<InsightsBloc>();
      addTearDown(bloc.close);
      addTearDown(other.close);
      expect(bloc, isNot(same(other)));
      final ready = bloc.stream.firstWhere((state) => state is InsightsSuccess);
      bloc.add(const InsightsRequestedEvent(year: 2026, month: 10));
      expect((await ready).insights, isEmpty);
      expect(other.state, isA<InsightsInitial>());
      final request =
          verify(() => http.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'insights');
      expect(request.query, {'filter[year]': 2026, 'filter[month]': 10});
      verifyNoMoreInteractions(http);
    },
  );
}
