import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
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
    'financing' => 'Crédito',
    'pets' => 'Pets',
    'investments' => 'Investimentos',
    'subscriptions' => 'Assinaturas',
    'personal_care' => 'Cuidados',
    'gifts_and_donations' => 'Presentes',
    'other' => 'Outros',
    _ => category,
  };

  IconData get icon => switch (category) {
    'pets' => Icons.pets_outlined,
    'housing' => Icons.home_outlined,
    'leisure' => Icons.play_circle_outline,
    'travel' => Icons.flight_outlined,
    'health' => Icons.favorite_border,
    'food' => Icons.restaurant_outlined,
    'insurance' => Icons.verified_user_outlined,
    'education' => Icons.menu_book_outlined,
    'services' => Icons.build_outlined,
    'personal_care' => Icons.auto_awesome_outlined,
    'financing' => Icons.payments_outlined,
    'taxes' => Icons.task_outlined,
    'shopping' => Icons.shopping_cart_outlined,
    'subscriptions' => Icons.refresh,
    'investments' => Icons.trending_up,
    'transport' => Icons.local_shipping_outlined,
    'gifts_and_donations' => Icons.volunteer_activism_outlined,
    _ => Icons.receipt_long_outlined,
  };

  AssetEnum get asset => switch (category) {
    'food' => AssetEnum.categoryFood,
    'pets' => AssetEnum.categoryPets,
    'taxes' => AssetEnum.categoryTaxes,
    'health' => AssetEnum.categoryHealth,
    'travel' => AssetEnum.categoryTravel,
    'leisure' => AssetEnum.categoryLeisure,
    'housing' => AssetEnum.categoryHousing,
    'shopping' => AssetEnum.categoryShopping,
    'services' => AssetEnum.categoryServices,
    'insurance' => AssetEnum.categoryInsurance,
    'education' => AssetEnum.categoryEducation,
    'transport' => AssetEnum.categoryTransport,
    'financing' => AssetEnum.categoryFinancing,
    'investments' => AssetEnum.categoryInvestments,
    'personal_care' => AssetEnum.categoryPersonalCare,
    'subscriptions' => AssetEnum.categorySubscriptions,
    'gifts_and_donations' => AssetEnum.categoryGiftsAndDonations,
    _ => AssetEnum.categoryOthers,
  };
}
