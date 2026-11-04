import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

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
    'financing' => 'Financiamentos',
    'pets' => 'Animais de estimação',
    'investments' => 'Investimentos',
    'subscriptions' => 'Assinaturas',
    'personal_care' => 'Cuidados pessoais',
    'gifts_and_donations' => 'Presentes e doações',
    'other' => 'Outros',
    _ => category,
  };

  LucideAnimatedIconData get icon => switch (category) {
    'pets' => rabbit,
    'housing' => home,
    'leisure' => play,
    'travel' => airplane,
    'health' => heart,
    'food' => cooking_pot,
    'insurance' => shield_check,
    'education' => book_text,
    'services' => wrench,
    'personal_care' => sparkles,
    'financing' => hand_coins,
    'taxes' => file_check,
    'shopping' => cart,
    'subscriptions' => refresh_cw,
    'investments' => trending_up,
    'transport' => truck,
    'gifts_and_donations' => hand_heart,
    _ => file_text,
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
