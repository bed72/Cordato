import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/metrics/domain/entities/expense_category_metrics_entity.dart';

extension ExpenseCategoryMetricsExtension on ExpenseCategoryMetricsEntity {
  Color color(BuildContext context) => switch (category) {
    'housing' => context.colors.primary,
    'food' => context.colors.tertiary,
    'health' => context.colors.secondary,
    'transport' => Color.lerp(
      context.colors.primary,
      context.colors.tertiary,
      0.5,
    )!,
    'subscriptions' => Color.lerp(
      context.colors.primary,
      context.colors.onSurface,
      0.4,
    )!,
    'education' => Color.lerp(
      context.colors.tertiary,
      context.colors.onSurface,
      0.4,
    )!,
    'leisure' => Color.lerp(
      context.colors.secondary,
      context.colors.primary,
      0.5,
    )!,
    'shopping' => context.colors.primaryContainer,
    'services' => context.colors.tertiaryContainer,
    'pets' => context.colors.tertiary,
    'taxes' => context.colors.secondary,
    'travel' => context.colors.primary,
    'financing' => Color.lerp(
      context.colors.secondary,
      context.colors.onSurface,
      0.4,
    )!,
    'insurance' => context.colors.secondaryContainer,
    'investments' => Color.lerp(
      context.colors.tertiary,
      context.colors.primary,
      0.3,
    )!,
    'personal_care' => Color.lerp(
      context.colors.secondary,
      context.colors.tertiary,
      0.5,
    )!,
    'gifts_and_donations' => Color.lerp(
      context.colors.tertiary,
      context.colors.secondary,
      0.3,
    )!,
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
}
