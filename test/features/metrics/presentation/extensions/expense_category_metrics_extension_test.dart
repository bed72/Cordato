import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

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
      expect(category.icon, lucide.file_text);
      expect(category.asset, AssetEnum.categoryOthers);
    });

    const icons = {
      'pets': lucide.rabbit,
      'housing': lucide.home,
      'leisure': lucide.play,
      'travel': lucide.airplane,
      'health': lucide.heart,
      'food': lucide.cooking_pot,
      'insurance': lucide.shield_check,
      'education': lucide.book_text,
      'personal_care': lucide.sparkles,
      'services': lucide.wrench,
      'financing': lucide.hand_coins,
      'taxes': lucide.file_check,
      'shopping': lucide.cart,
      'subscriptions': lucide.refresh_cw,
      'investments': lucide.trending_up,
      'transport': lucide.truck,
      'gifts_and_donations': lucide.hand_heart,
      'other': lucide.file_text,
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
