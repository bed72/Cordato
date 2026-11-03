import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

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

  lucide.LucideAnimatedIconData get icon => switch (category) {
    'pets' => lucide.rabbit,
    'housing' => lucide.home,
    'leisure' => lucide.play,
    'travel' => lucide.airplane,
    'health' => lucide.heart,
    'food' => lucide.cooking_pot,
    'insurance' => lucide.shield_check,
    'education' => lucide.book_text,
    'services' => lucide.wrench,
    'personal_care' => lucide.sparkles,
    'financing' => lucide.hand_coins,
    'taxes' => lucide.file_check,
    'shopping' => lucide.cart,
    'subscriptions' => lucide.refresh_cw,
    'investments' => lucide.trending_up,
    'transport' => lucide.truck,
    'gifts_and_donations' => lucide.hand_heart,
    _ => lucide.file_text,
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
