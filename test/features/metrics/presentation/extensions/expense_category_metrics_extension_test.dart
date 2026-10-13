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
        expect(
          category.asset.source,
          'assets/images/categories/${entry.key == 'other' ? 'others' : entry.key}.webp',
        );
        expect(category.asset.alt, entry.value);
      });
    }

    test('preserves the name of an unknown category', () {
      const category = ExpenseCategoryMetricsEntity(
        category: 'future_category',
        percentage: 100,
        totalAmount: 300,
      );

      expect(category.label, 'future_category');
      expect(category.icon, Icons.receipt_long_outlined);
      expect(category.asset, AssetEnum.categoryOthers);
    });

    const icons = {
      'pets': Icons.pets_outlined,
      'housing': Icons.home_outlined,
      'leisure': Icons.movie_outlined,
      'travel': Icons.flight_outlined,
      'health': Icons.favorite_outline,
      'food': Icons.restaurant_outlined,
      'insurance': Icons.shield_outlined,
      'education': Icons.school_outlined,
      'personal_care': Icons.spa_outlined,
      'services': Icons.handyman_outlined,
      'financing': Icons.payments_outlined,
      'taxes': Icons.account_balance_outlined,
      'shopping': Icons.shopping_bag_outlined,
      'subscriptions': Icons.autorenew_outlined,
      'investments': Icons.trending_up_outlined,
      'transport': Icons.directions_car_outlined,
      'gifts_and_donations': Icons.card_giftcard_outlined,
      'other': Icons.receipt_long_outlined,
    };
    for (final entry in icons.entries) {
      test('uses the expense icon for ${entry.key}', () {
        final category = ExpenseCategoryMetricsEntity(
          category: entry.key,
          totalAmount: 1,
          percentage: 1,
        );

        expect(category.icon, entry.value);
      });
    }
  });
}
