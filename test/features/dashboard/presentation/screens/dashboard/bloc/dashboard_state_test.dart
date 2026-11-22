import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';

import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';

import 'package:cordato/features/dashboard/presentation/enums/dashboard_phase_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_state.dart';

void main() {
  final month = DateTime(2026, 11);
  final emptyPage = ExpensePageEntity(items: [], nextPage: null);
  final populatedPage = ExpensePageEntity(
    items: [
      ExpenseEntity(
        id: 'expense',
        description: 'Mercado',
        category: .food,
        occurredOn: month,
        cents: .create(cents: 100),
      ),
    ],
    nextPage: null,
  );
  ExpenseMetricsEntity metrics(int cents) => ExpenseMetricsEntity(
    id: 'metrics',
    startDate: month,
    endDate: DateTime(2026, 11, 30),
    total: cents,
    categories: const [],
  );

  group('Confirmed empty dashboard', () {
    test('requires both successful empty sections', () {
      final state = DashboardState(
        phase: .ready,
        expenses: emptyPage,
        metrics: metrics(0),
      );

      expect(state.isEmpty, isTrue);
      expect(state.hasNoExpenseHistory, isFalse);
    });

    for (final phase in [
      DashboardPhaseEnum.loading,
      DashboardPhaseEnum.failure,
    ]) {
      test('$phase never presents an empty dashboard', () {
        final state = DashboardState(
          phase: phase,
          expenses: emptyPage,
          metrics: metrics(0),
        );

        expect(state.isEmpty, isFalse);
      });
    }

    test('missing metrics is not confirmed zero', () {
      final state = DashboardState(phase: .ready, expenses: emptyPage);

      expect(state.isEmpty, isFalse);
    });

    test('missing expenses is not a confirmed empty list', () {
      final state = DashboardState(phase: .ready, metrics: metrics(0));

      expect(state.isEmpty, isFalse);
    });

    test('a positive monthly total preserves financial sections', () {
      final state = DashboardState(
        phase: .ready,
        expenses: emptyPage,
        metrics: metrics(100),
      );

      expect(state.isEmpty, isFalse);
    });

    test('existing monthly expenses preserve financial sections', () {
      final state = DashboardState(
        phase: .ready,
        expenses: populatedPage,
        metrics: metrics(0),
      );

      expect(state.isEmpty, isFalse);
    });
  });
}
