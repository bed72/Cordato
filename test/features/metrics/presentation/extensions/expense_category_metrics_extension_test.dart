import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
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
      'financing': 'Crédito',
      'investments': 'Investimentos',
      'subscriptions': 'Assinaturas',
      'pets': 'Pets',
      'personal_care': 'Cuidados',
      'gifts_and_donations': 'Presentes',
      'other': 'Outros',
    };

    for (final entry in labels.entries) {
      test('displays ${entry.key} in Brazilian Portuguese', () {
        final category = ExpenseCategoryMetricsEntity(
          percentage: 100,
          total: 300,
          category: entry.key,
        );

        expect(category.label, entry.value);
        expect(
          category.asset.source,
          'assets/images/categories/${switch (entry.key) {
            'other' || 'gifts_and_donations' => 'others',
            _ => entry.key,
          }}.webp',
        );
        expect(category.asset.alt, switch (entry.key) {
          'financing' => 'Financiamentos',
          'pets' => 'Animais de estimação',
          'personal_care' => 'Cuidados pessoais',
          'gifts_and_donations' => 'Outros',
          _ => entry.value,
        });
      });
    }

    test('preserves the name of an unknown category', () {
      const category = ExpenseCategoryMetricsEntity(
        category: 'future_category',
        percentage: 100,
        total: 300,
      );

      expect(category.label, 'future_category');
      expect(category.icon, Icons.receipt_long_outlined);
      expect(category.asset, AssetEnum.categoryOthers);
    });

    const icons = {
      'pets': Icons.pets_outlined,
      'housing': Icons.home_outlined,
      'leisure': Icons.play_circle_outline,
      'travel': Icons.flight_outlined,
      'health': Icons.favorite_border,
      'food': Icons.restaurant_outlined,
      'insurance': Icons.verified_user_outlined,
      'education': Icons.menu_book_outlined,
      'personal_care': Icons.auto_awesome_outlined,
      'services': Icons.build_outlined,
      'financing': Icons.payments_outlined,
      'taxes': Icons.task_outlined,
      'shopping': Icons.shopping_cart_outlined,
      'subscriptions': Icons.refresh,
      'investments': Icons.trending_up,
      'transport': Icons.local_shipping_outlined,
      'gifts_and_donations': Icons.volunteer_activism_outlined,
      'other': Icons.receipt_long_outlined,
    };
    for (final entry in icons.entries) {
      test('uses the expense icon for ${entry.key}', () {
        final category = ExpenseCategoryMetricsEntity(
          category: entry.key,
          total: 1,
          percentage: 1,
        );

        expect(category.icon, entry.value);
      });
    }
  });
}
