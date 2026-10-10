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
    _ => context.colors.onSurfaceVariant,
  };

  String get label => switch (category) {
    'housing' => 'Moradia',
    'food' => 'Alimentação',
    'health' => 'Saúde',
    'transport' => 'Transporte',
    'subscriptions' => 'Assinaturas',
    'education' => 'Educação',
    'leisure' => 'Lazer',
    'shopping' => 'Compras',
    'services' => 'Serviços',
    'other' => 'Outros',
    _ => category,
  };
}
