import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/root/root_module.dart';
import 'package:cordato/features/root/application/repositories/interface_widget_launch_repository.dart';
import 'package:cordato/features/root/application/repositories/interface_widget_sync_repository.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_event.dart';
import 'package:cordato/features/root/presentation/bloc/widget_launch_state.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_bloc.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_event.dart';
import 'package:cordato/features/root/presentation/bloc/widget_sync_state.dart';

import '../../support/core/mocks/widget_client_mock.dart';
import '../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  late WidgetClientMock client;
  late MetricsRepositoryMock metrics;
  late ModularBootstrap boot;

  setUp(() {
    client = WidgetClientMock();
    metrics = MetricsRepositoryMock();
    when(() => client.launches).thenAnswer((_) => const Stream.empty());
    when(client.initialLaunch).thenAnswer(
      (_) async => Uri.parse('cordato://widget/add-expense?homeWidget=true'),
    );
    when(() => client.refresh).thenAnswer((_) => const Stream.empty());
    when(() => client.setMonthly(active: true)).thenAnswer((_) async {});
    when(() => metrics.getExpenses()).thenAnswer(
      (_) async => ExpenseMetricsEntity(
        id: 'month',
        total: 100,
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
    final launches = boot.injector.get<IWidgetLaunchRepository>();
    final synchronization = boot.injector.get<IWidgetSyncRepository>();

    expect(boot.injector.get<IWidgetLaunchRepository>(), same(launches));
    expect(boot.injector.get<IWidgetSyncRepository>(), same(synchronization));
  });

  test(
    'launch Blocs are independent factories and resolve the native intent',
    () async {
      final first = boot.injector.get<WidgetLaunchBloc>();
      final second = boot.injector.get<WidgetLaunchBloc>();
      addTearDown(first.close);
      addTearDown(second.close);
      final requested = first.stream.firstWhere(
        (state) => state is WidgetLaunchRequested,
      );

      first.add(const WidgetLaunchStartedEvent());
      await requested;

      expect(first, isNot(same(second)));
      expect(second.state, isA<WidgetLaunchInitial>());
      verify(client.initialLaunch).called(1);
    },
  );

  test(
    'sync Blocs are independent factories and refresh without authentication',
    () async {
      final first = boot.injector.get<WidgetSyncBloc>();
      final second = boot.injector.get<WidgetSyncBloc>();
      addTearDown(first.close);
      addTearDown(second.close);
      final ready = first.stream.firstWhere(
        (state) => state is WidgetSyncReady,
      );

      first.add(const WidgetSyncStartedEvent());
      await ready;

      expect(first, isNot(same(second)));
      expect(second.state, isA<WidgetSyncInitial>());
      verify(() => client.setMonthly(active: true)).called(1);
      verify(() => metrics.getExpenses()).called(1);
    },
  );
}
