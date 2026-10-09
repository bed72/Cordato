import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/insight/infrastructure/responses/insight_response.dart';

void main() {
  const attributes = {
    'title': 'Mais valor registrado',
    'type': 'registered_amount_increase',
    'group': 'comparison',
    'description': 'Você registrou 35% mais valor.',
    'period': {
      'from': '2026-10-01',
      'to': '2026-10-08',
      'comparison': {'from': '2026-09-01', 'to': '2026-09-08'},
    },
  };

  test('parses the resource and comparison as civil dates', () {
    final response = InsightResponse.fromJson({
      'id': 'insight-1',
      'type': 'insights',
      'attributes': attributes,
    });
    final entity = response.toEntity();

    expect(entity.id, 'insight-1');
    expect(entity.title, attributes['title']);
    expect(entity.description, attributes['description']);
    expect(entity.type, 'registered_amount_increase');
    expect(entity.group, 'comparison');
    expect(entity.period.from, DateTime(2026, 10, 1));
    expect(entity.period.to, DateTime(2026, 10, 8));
    expect(entity.period.comparison?.from, DateTime(2026, 9, 1));
    expect(entity.period.comparison?.to, DateTime(2026, 9, 8));
    expect(entity.period.from.isUtc, isFalse);
  });

  for (final period in [
    {'from': '2026-10-01', 'to': '2026-10-09', 'comparison': null},
    {'from': '2026-10-01', 'to': '2026-10-09'},
  ]) {
    test('accepts absent or null comparison in $period', () {
      final response = InsightResponse.fromJson({
        'id': 'future',
        'attributes': {
          ...attributes,
          'type': 'future_type',
          'group': 'future_group',
          'period': period,
        },
      });

      expect(response.type, 'future_type');
      expect(response.group, 'future_group');
      expect(response.toEntity().period.comparison, isNull);
    });
  }

  test('rejects malformed fields and periods instead of defaulting them', () {
    for (final invalid in [
      {...attributes, 'title': null},
      {...attributes, 'type': 1},
      {...attributes, 'group': null},
      {...attributes, 'description': false},
      {...attributes, 'period': null},
      {
        ...attributes,
        'period': {'from': 'invalid', 'to': '2026-10-09'},
      },
      {
        ...attributes,
        'period': {
          'from': '2026-10-01',
          'to': '2026-10-09',
          'comparison': {'from': '2026-09-01'},
        },
      },
    ]) {
      expect(
        () => InsightResponse.fromJson({'id': '1', 'attributes': invalid}),
        throwsA(anything),
      );
    }
  });
}
