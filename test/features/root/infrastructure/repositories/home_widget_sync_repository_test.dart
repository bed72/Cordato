import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/root/infrastructure/repositories/home_widget_sync_repository.dart';

import '../../../../support/core/mocks/home_widget_client_mock.dart';
import '../../../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  test(
    'exposes refresh signals without exposing the client to presentation',
    () async {
      final source = StreamController<void>();
      final client = HomeWidgetClientMock();
      when(() => client.monthlyRefreshRequests)
          .thenAnswer((_) => source.stream);
      final repository = HomeWidgetSyncRepository(
        homeWidgetClient: client,
        metricsRepository: MetricsRepositoryMock(),
      );

      final forwarded = repository.refreshRequests.first;
      source.add(null);
      await forwarded;
      verify(() => client.monthlyRefreshRequests).called(1);

      await source.close();
    },
  );
  test(
    'refresh requests the current month independently from Dashboard filters',
    () async {
      final metrics = MetricsRepositoryMock();
      final widgetClient = HomeWidgetClientMock();
      when(() => metrics.getExpenses()).thenAnswer(
        (_) async => ExpenseMetricsEntity(
          id: 'month',
          totalAmount: 125000,
          startDate: DateTime(2026, 11),
          endDate: DateTime(2026, 11, 30),
        ),
      );
      final repository = HomeWidgetSyncRepository(
        homeWidgetClient: widgetClient,
        metricsRepository: metrics,
      );

      await repository.refresh();

      verify(() => metrics.getExpenses()).called(1);
      verifyNoMoreInteractions(metrics);
    },
  );

  test(
    'local publication awaits enabling the existing widget client',
    () async {
      final client = HomeWidgetClientMock();
      when(() => client.setMonthlySessionActive(active: true))
          .thenAnswer((_) async {});
      final repository = HomeWidgetSyncRepository(
        homeWidgetClient: client,
        metricsRepository: MetricsRepositoryMock(),
      );

      await repository.enable();

      verify(() => client.setMonthlySessionActive(active: true)).called(1);
    },
  );
}
