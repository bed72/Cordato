import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

extension ExpenseCategoryMetricsExtension on ExpenseCategoryMetricsEntity {
  Color color(BuildContext context) => switch (category) {
    'health' => context.colors.error,
    'pets' => context.colors.tertiary,
    'travel' => context.colors.primary,
    'taxes' => context.colors.secondary,
    'insurance' => context.colors.primary,
    'transport' => context.colors.primary,
    'financing' => context.colors.secondary,
    'investments' => context.colors.tertiary,
    'personal_care' => context.colors.secondary,
    'gifts_and_donations' => context.colors.tertiary,
    'housing' => context.isDark ? Colors.blue.shade300 : Colors.blue.shade700,
    'shopping' => context.isDark ? Colors.pink.shade300 : Colors.pink.shade700,
    'services' => context.isDark ? Colors.teal.shade300 : Colors.teal.shade700,
    'food' => context.isDark ? Colors.orange.shade300 : Colors.orange.shade800,
    'subscriptions' =>
      context.isDark ? Colors.cyan.shade300 : Colors.cyan.shade800,
    'education' =>
      context.isDark ? Colors.indigo.shade300 : Colors.indigo.shade700,
    'leisure' =>
      context.isDark ? Colors.purple.shade300 : Colors.purple.shade700,
    'other' => context.colors.outline,
    _ => context.colors.onSurfaceVariant,
  };

  String get label => switch (category) {
    'health' => 'Saúde',
    'leisure' => 'Lazer',
    'taxes' => 'Impostos',
    'travel' => 'Viagens',
    'housing' => 'Moradia',
    'food' => 'Alimentação',
    'shopping' => 'Compras',
    'insurance' => 'Seguros',
    'services' => 'Serviços',
    'education' => 'Educação',
    'transport' => 'Transporte',
    'financing' => 'Financiamentos',
    'pets' => 'Animais de estimação',
    'investments' => 'Investimentos',
    'subscriptions' => 'Assinaturas',
    'personal_care' => 'Cuidados pessoais',
    'gifts_and_donations' => 'Presentes e doações',
    'other' => 'Outros',
    _ => category,
  };

  IconData get icon => switch (category) {
    'pets' => Icons.pets_outlined,
    'housing' => Icons.home_outlined,
    'leisure' => Icons.movie_outlined,
    'travel' => Icons.flight_outlined,
    'health' => Icons.favorite_outline,
    'food' => Icons.restaurant_outlined,
    'insurance' => Icons.shield_outlined,
    'education' => Icons.school_outlined,
    'services' => Icons.handyman_outlined,
    'personal_care' => Icons.spa_outlined,
    'financing' => Icons.payments_outlined,
    'taxes' => Icons.account_balance_outlined,
    'shopping' => Icons.shopping_bag_outlined,
    'subscriptions' => Icons.autorenew_outlined,
    'investments' => Icons.trending_up_outlined,
    'transport' => Icons.directions_car_outlined,
    'gifts_and_donations' => Icons.card_giftcard_outlined,
    _ => Icons.receipt_long_outlined,
  };

  String get asset =>
      'assets/images/categories/${switch (category) {
        'health' || 'leisure' || 'taxes' || 'travel' || 'housing' || 'food' || 'shopping' || 'insurance' || 'services' || 'education' || 'transport' || 'financing' || 'pets' || 'investments' || 'subscriptions' || 'personal_care' || 'gifts_and_donations' => category,
        _ => 'others',
      }}.webp';
}
