import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/insight/domain/entities/insight_date_range_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';

void main() {
  group('InsightEntity', () {
    test('represents onboarding without a financial period', () {
      const insight = InsightEntity(
        period: null,
        id: 'onboarding',
        group: 'onboarding',
        type: 'insufficient_history',
        title: 'Cada registro traz contexto',
        description: 'Continue registrando suas despesas.',
      );

      expect(insight.period, isNull);
      expect(insight.group, 'onboarding');
      expect(insight.type, 'insufficient_history');
      expect(insight.title, 'Cada registro traz contexto');
      expect(insight.description, 'Continue registrando suas despesas.');
    });

    test('preserves insight content and comparison civil dates', () {
      final comparison = InsightDateRangeEntity(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 8),
      );
      final period = InsightPeriodEntity(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 8),
        comparison: comparison,
      );
      final insight = InsightEntity(
        period: period,
        group: 'comparison',
        id: 'amount-increase',
        title: 'Mais valor registrado',
        type: 'registered_amount_increase',
        description: 'De 1 a 8, você registrou 35% mais valor que nos mesmos dias do mês passado.',
      );

      expect(insight.group, 'comparison');
      expect(insight.id, 'amount-increase');
      expect(insight.title, 'Mais valor registrado');
      expect(insight.type, 'registered_amount_increase');
      expect(
        insight.description,
        'De 1 a 8, você registrou 35% mais valor que nos mesmos dias do mês passado.',
      );
      expect(insight.period, same(period));
      expect(comparison.to, DateTime(2026, 9, 8));
      expect(comparison.from, DateTime(2026, 9, 1));
      expect(insight.period!.to, DateTime(2026, 10, 8));
      expect(insight.period!.from, DateTime(2026, 10, 1));
      expect(insight.period!.comparison, same(comparison));
    });

    test('supports new types and groups without a comparison period', () {
      final insight = InsightEntity(
        id: 'new-insight',
        title: 'Novo insight',
        type: 'future_type',
        group: 'future_group',
        description: 'Uma nova análise derivada.',
        period: InsightPeriodEntity(
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 9),
        ),
      );

      expect(insight.type, 'future_type');
      expect(insight.group, 'future_group');
      expect(insight.period!.comparison, isNull);
    });
  });
}
