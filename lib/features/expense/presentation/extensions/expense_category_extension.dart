import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

extension ExpenseCategoryExtension on ExpenseCategoryEnum {
  LucideAnimatedIconData get icon => switch (this) {
    .pets => rabbit,
    .housing => home,
    .leisure => play,
    .travel => airplane,
    .health => heart,
    .food => cooking_pot,
    .insurance => shield_check,
    .personalCare => sparkles,
    .education => book_text,
    .services => wrench,
    .financing => hand_coins,
    .taxes => file_check,
    .shopping => cart,
    .subscriptions => refresh_cw,
    .investments => trending_up,
    .transport => truck,
    .giftsAndDonations => hand_heart,
    .other => file_text,
  };

  Color color(BuildContext context) => switch (this) {
    .health => context.colors.error,
    .pets => context.colors.tertiary,
    .taxes => context.colors.secondary,
    .travel => context.colors.primary,
    .transport => context.colors.primary,
    .insurance => context.colors.primary,
    .financing => context.colors.secondary,
    .investments => context.colors.tertiary,
    .personalCare => context.colors.secondary,
    .giftsAndDonations => context.colors.tertiary,
    .housing => context.isDark ? Colors.blue.shade300 : Colors.blue.shade700,
    .shopping => context.isDark ? Colors.pink.shade300 : Colors.pink.shade700,
    .food => context.isDark ? Colors.orange.shade300 : Colors.orange.shade800,
    .services => context.isDark ? Colors.teal.shade300 : Colors.teal.shade700,
    .subscriptions =>
      context.isDark ? Colors.cyan.shade300 : Colors.cyan.shade800,
    .education =>
      context.isDark ? Colors.indigo.shade300 : Colors.indigo.shade700,
    .leisure =>
      context.isDark ? Colors.purple.shade300 : Colors.purple.shade700,
    .other => context.colors.outline,
  };

  String get label => switch (this) {
    .health => 'Saúde',
    .leisure => 'Lazer',
    .taxes => 'Impostos',
    .travel => 'Viagens',
    .housing => 'Moradia',
    .food => 'Alimentação',
    .shopping => 'Compras',
    .services => 'Serviços',
    .insurance => 'Seguros',
    .education => 'Educação',
    .transport => 'Transporte',
    .financing => 'Financiamentos',
    .subscriptions => 'Assinaturas',
    .pets => 'Animais de estimação',
    .investments => 'Investimentos',
    .personalCare => 'Cuidados pessoais',
    .giftsAndDonations => 'Presentes e doações',
    .other => 'Outros',
  };
}
