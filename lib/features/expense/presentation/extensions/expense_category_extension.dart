import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

extension ExpenseCategoryExtension on ExpenseCategoryEnum {
  static const orderedValues = <ExpenseCategoryEnum>[
    .food,
    .pets,
    .subscriptions,
    .shopping,
    .personalCare,
    .education,
    .financing,
    .taxes,
    .investments,
    .leisure,
    .housing,
    .giftsAndDonations,
    .health,
    .insurance,
    .services,
    .transport,
    .travel,
    .other,
  ];

  String get description => switch (this) {
    .food => 'Mercado, restaurantes e refeições do dia',
    .pets => 'Ração, veterinário e cuidados com animais',
    .subscriptions => 'Streaming, aplicativos e serviços recorrentes',
    .shopping => 'Roupas, eletrônicos e produtos em geral',
    .personalCare => 'Beleza, higiene e cuidados com você',
    .education => 'Cursos, livros e materiais de estudo',
    .financing => 'Parcelas de imóveis, veículos e empréstimos',
    .taxes => 'Tributos, taxas e outras obrigações fiscais',
    .investments => 'Aportes, aplicações e reservas financeiras',
    .leisure => 'Cinema, passeios e momentos de diversão',
    .housing => 'Aluguel, condomínio e contas da casa',
    .giftsAndDonations => 'Presentes, contribuições e apoio a causas',
    .health => 'Consultas, exames e cuidados com saúde',
    .insurance => 'Proteção de vida, bens e veículos',
    .services => 'Reparos, manutenção e contratação profissional',
    .transport => 'Combustível, passagens e deslocamentos diários',
    .travel => 'Passagens, hospedagens e despesas de viagens',
    .other => 'Gastos que não se encaixam aqui',
  };

  IconData get icon => switch (this) {
    .pets => Icons.pets_outlined,
    .housing => Icons.home_outlined,
    .leisure => Icons.play_circle_outline,
    .travel => Icons.flight_outlined,
    .health => Icons.favorite_border,
    .food => Icons.restaurant_outlined,
    .insurance => Icons.verified_user_outlined,
    .personalCare => Icons.auto_awesome_outlined,
    .education => Icons.menu_book_outlined,
    .services => Icons.build_outlined,
    .financing => Icons.payments_outlined,
    .taxes => Icons.task_outlined,
    .shopping => Icons.shopping_cart_outlined,
    .subscriptions => Icons.refresh,
    .investments => Icons.trending_up,
    .transport => Icons.local_shipping_outlined,
    .giftsAndDonations => Icons.volunteer_activism_outlined,
    .other => Icons.receipt_long_outlined,
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
