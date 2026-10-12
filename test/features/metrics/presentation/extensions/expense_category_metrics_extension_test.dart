import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';
import 'package:cordato/features/metrics/presentation/extensions/expense_category_metrics_extension.dart';

void main() {
  group('ExpenseCategoryMetricsExtension', () {
    const labels = <String, String>{
      'health': 'Saúde',
      'leisure': 'Lazer',
      'taxes': 'Impostos',
      'travel': 'Viagens',
      'housing': 'Moradia',
      'food': 'Alimentação',
      'shopping': 'Compras',
      'services': 'Serviços',
      'insurance': 'Seguros',
      'transport': 'Transporte',
      'education': 'Educação',
      'financing': 'Financiamentos',
      'investments': 'Investimentos',
      'subscriptions': 'Assinaturas',
      'pets': 'Animais de estimação',
      'personal_care': 'Cuidados pessoais',
      'gifts_and_donations': 'Presentes e doações',
      'other': 'Outros',
    };

    for (final entry in labels.entries) {
      test('displays ${entry.key} in Brazilian Portuguese', () {
        final category = ExpenseCategoryMetricsEntity(
          percentage: 100,
          totalAmount: 300,
          category: entry.key,
        );

        expect(category.label, entry.value);
      });
    }

    test('preserves the name of an unknown category', () {
      const category = ExpenseCategoryMetricsEntity(
        category: 'future_category',
        percentage: 100,
        totalAmount: 300,
      );

      expect(category.label, 'future_category');
    });
  });
}
