import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/application/clients/interface_widget_client.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/root/root_module.dart';
import 'package:cordato/features/root/application/repositories/interface_home_widget_launch_repository.dart';
import 'package:cordato/features/root/application/repositories/interface_home_widget_sync_repository.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_launch_state.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/home_widget_sync_state.dart';

import '../../support/core/mocks/home_widget_client_mock.dart';
import '../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  late HomeWidgetClientMock client;
  late MetricsRepositoryMock metrics;
  late ModularBootstrap boot;

  setUp(() {
    client = HomeWidgetClientMock();
    metrics = MetricsRepositoryMock();
    when(() => client.launches).thenAnswer((_) => const Stream.empty());
    when(client.initialLaunch).thenAnswer(
      (_) async => Uri.parse('cordato://widget/add-expense?homeWidget=true'),
    );
    when(() => client.monthlyRefreshRequests)
        .thenAnswer((_) => const Stream.empty());
    when(() => client.setMonthlySessionActive(active: true))
        .thenAnswer((_) async {});
    when(() => metrics.getExpenses()).thenAnswer(
      (_) async => ExpenseMetricsEntity(
        id: 'month',
        totalAmount: 100,
        startDate: DateTime(2026, 11),
        endDate: DateTime(2026, 11, 30),
      ),
    );
    boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<IWidgetClient>(client)
          ..addInstance<IMetricsRepository>(metrics)
          ..module(rootModule),
      ),
    );
    addTearDown(boot.injector.dispose);
  });

  test('shares repositories without visiting any feature route', () {
    final launches = boot.injector.get<IHomeWidgetLaunchRepository>();
    final synchronization = boot.injector.get<IHomeWidgetSyncRepository>();

    expect(boot.injector.get<IHomeWidgetLaunchRepository>(), same(launches));
    expect(
      boot.injector.get<IHomeWidgetSyncRepository>(),
      same(synchronization),
    );
  });

  test(
    'launch Blocs are independent factories and resolve the native intent',
    () async {
      final first = boot.injector.get<HomeWidgetLaunchBloc>();
      final second = boot.injector.get<HomeWidgetLaunchBloc>();
      addTearDown(first.close);
      addTearDown(second.close);
      final requested = first.stream.firstWhere(
        (state) => state is HomeWidgetLaunchRequested,
      );

      first.add(const HomeWidgetLaunchStartedEvent());
      await requested;

      expect(first, isNot(same(second)));
      expect(second.state, isA<HomeWidgetLaunchInitial>());
      verify(client.initialLaunch).called(1);
    },
  );

  test(
    'sync Blocs are independent factories and refresh without authentication',
    () async {
      final first = boot.injector.get<HomeWidgetSyncBloc>();
      final second = boot.injector.get<HomeWidgetSyncBloc>();
      addTearDown(first.close);
      addTearDown(second.close);
      final ready = first.stream.firstWhere(
        (state) => state is HomeWidgetSyncReady,
      );

      first.add(const HomeWidgetSyncStartedEvent());
      await ready;

      expect(first, isNot(same(second)));
      expect(second.state, isA<HomeWidgetSyncInitial>());
      verify(() => client.setMonthlySessionActive(active: true)).called(1);
      verify(() => metrics.getExpenses()).called(1);
    },
  );
}
