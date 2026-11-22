import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/root/infrastructure/repositories/widget_sync_repository.dart';

import '../../../../support/core/mocks/widget_client_mock.dart';
import '../../../../support/metrics/mocks/metrics_repository_mock.dart';

void main() {
  test(
    'exposes refresh signals without exposing the client to presentation',
    () async {
      final source = StreamController<void>();
      final client = WidgetClientMock();
      when(() => client.refresh).thenAnswer((_) => source.stream);
      final repository = WidgetSyncRepository(
        client: client,
        repository: MetricsRepositoryMock(),
      );

      final forwarded = repository.refreshRequests.first;
      source.add(null);
      await forwarded;
      verify(() => client.refresh).called(1);

      await source.close();
    },
  );
  test(
    'refresh requests the current month independently from Dashboard filters',
    () async {
      final metrics = MetricsRepositoryMock();
      final widgetClient = WidgetClientMock();
      when(() => metrics.getExpenses()).thenAnswer(
        (_) async => ExpenseMetricsEntity(
          id: 'month',
          total: 125000,
          startDate: DateTime(2026, 11),
          endDate: DateTime(2026, 11, 30),
        ),
      );
      final repository = WidgetSyncRepository(
        client: widgetClient,
        repository: metrics,
      );

      await repository.refresh();

      verify(() => metrics.getExpenses()).called(1);
      verifyNoMoreInteractions(metrics);
    },
  );

  test(
    'local publication awaits enabling the existing widget client',
    () async {
      final client = WidgetClientMock();
      when(() => client.setMonthly(active: true)).thenAnswer((_) async {});
      final repository = WidgetSyncRepository(
        client: client,
        repository: MetricsRepositoryMock(),
      );

      await repository.enable();

      verify(() => client.setMonthly(active: true)).called(1);
    },
  );
}
