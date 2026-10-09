import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/insight/infrastructure/responses/insight_response.dart';

void main() {
  const attributes = {
    'group': 'comparison',
    'title': 'Mais valor registrado',
    'type': 'registered_amount_increase',
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
    expect(entity.group, 'comparison');
    expect(entity.title, attributes['title']);
    expect(entity.period!.from.isUtc, isFalse);
    expect(entity.period!.to, DateTime(2026, 10, 8));
    expect(entity.type, 'registered_amount_increase');
    expect(entity.period!.from, DateTime(2026, 10, 1));
    expect(entity.description, attributes['description']);
    expect(entity.period!.comparison?.to, DateTime(2026, 9, 8));
    expect(entity.period!.comparison?.from, DateTime(2026, 9, 1));
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
      expect(response.toEntity().period!.comparison, isNull);
    });
  }

  test('preserves onboarding content with a null period', () {
    final response = InsightResponse.fromJson({
      'id': '2fc73afb4eaeadb33c40d6c5df66e6333739cc91fa87f0fd1bc72335c06a0ce0',
      'type': 'insights',
      'attributes': {
        'title': 'Cada registro traz contexto',
        'type': 'insufficient_history',
        'group': 'onboarding',
        'description': 'Continue registrando suas despesas. Por enquanto, os registros não sustentam uma observação financeira.',
        'period': null,
      },
    });
    final entity = response.toEntity();

    expect(response.period, isNull);
    expect(entity.period, isNull);
    expect(entity.id, response.id);
    expect(entity.title, 'Cada registro traz contexto');
    expect(entity.type, 'insufficient_history');
    expect(entity.group, 'onboarding');
    expect(
      entity.description,
      'Continue registrando suas despesas. Por enquanto, os registros não sustentam uma observação financeira.',
    );
  });

  test('rejects malformed fields and periods instead of defaulting them', () {
    for (final invalid in [
      {...attributes, 'title': null},
      {...attributes, 'type': 1},
      {...attributes, 'group': null},
      {...attributes, 'description': false},
      {...attributes, 'period': 'invalid'},
      {...attributes, 'period': {}},
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
