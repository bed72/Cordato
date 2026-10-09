import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/insight/domain/entities/insight_date_range_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_entity.dart';
import 'package:cordato/features/insight/domain/entities/insight_period_entity.dart';

void main() {
  group('InsightEntity', () {
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
        id: 'amount-increase',
        title: 'Mais valor registrado',
        type: 'registered_amount_increase',
        group: 'comparison',
        description: 'De 1 a 8, você registrou 35% mais valor que nos mesmos dias do mês passado.',
        period: period,
      );

      expect(insight.id, 'amount-increase');
      expect(insight.title, 'Mais valor registrado');
      expect(insight.type, 'registered_amount_increase');
      expect(insight.group, 'comparison');
      expect(
        insight.description,
        'De 1 a 8, você registrou 35% mais valor que nos mesmos dias do mês passado.',
      );
      expect(insight.period, same(period));
      expect(insight.period.from, DateTime(2026, 10, 1));
      expect(insight.period.to, DateTime(2026, 10, 8));
      expect(insight.period.comparison, same(comparison));
      expect(comparison.from, DateTime(2026, 9, 1));
      expect(comparison.to, DateTime(2026, 9, 8));
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
      expect(insight.period.comparison, isNull);
    });
  });
}
